import 'package:drift/drift.dart';
import '../../../core/database/database.dart';
import '../models/reporte_models.dart';

/// Repositorio de datos para el módulo de Reportes
///
/// Provee streams reactivos y queries SQL optimizadas con agregaciones
/// para minimizar procesamiento en Dart y eliminar problemas N+1.
class ReportesRepository {
  final AppDatabase _db;

  const ReportesRepository(this._db);

  // ────────────────────────────────────────────────────────────────────────────
  // RESUMEN FINANCIERO MENSUAL
  // ────────────────────────────────────────────────────────────────────────────

  /// Stream reactivo del resumen financiero de un período
  ///
  /// Calcula:
  /// - Ingresos totales (solo de cuentas líquidas, excluyendo transferencias)
  /// - Egresos totales (débito/efectivo + cuotas de crédito del período)
  /// - Balance (ingresos - egresos)
  /// - Tasa de ahorro (% del ingreso que no se gastó)
  Stream<ResumenFinanciero> watchResumenMes(
    DateTime inicioMes,
    DateTime finMes,
  ) {
    // Stream de transacciones del mes con JOIN a cuentas
    final txQuery = _db.select(_db.transacciones).join([
      innerJoin(
        _db.cuentas,
        _db.cuentas.id.equalsExp(_db.transacciones.cuentaId),
      ),
    ]);
    txQuery.where(
      _db.transacciones.deletedAt.isNull() &
          _db.transacciones.fecha.isBiggerOrEqualValue(inicioMes) &
          _db.transacciones.fecha.isSmallerOrEqualValue(finMes),
    );

    // Stream de cuotas del mes
    final cuotasStream = (_db.select(_db.cuotas)
          ..where((c) =>
              c.deletedAt.isNull() &
              c.pagada.equals(false) &
              c.fechaVencimiento.isBiggerOrEqualValue(inicioMes) &
              c.fechaVencimiento.isSmallerOrEqualValue(finMes)))
        .watch();

    // Combinar ambos streams
    return txQuery.watch().asyncMap((rows) async {
      final cuotas = await cuotasStream.first;

      // Calcular ingresos solo de cuentas líquidas (NO crédito)
      // y excluyendo transferencias
      final ingresos = rows
          .where((row) {
            final tx = row.readTable(_db.transacciones);
            final cuenta = row.readTable(_db.cuentas);
            return tx.tipo == 'ingreso' &&
                tx.tipo != 'transferencia' &&
                cuenta.tipo != 'credito'; // ← BLINDAJE: Solo cuentas líquidas
          })
          .fold<double>(0, (sum, row) {
            final tx = row.readTable(_db.transacciones);
            return sum + tx.montoTotal;
          });

      // Egresos de débito/efectivo (excluyendo transferencias)
      final egresosDebito = rows
          .where((row) {
            final tx = row.readTable(_db.transacciones);
            return tx.tipo == 'egreso' &&
                tx.formaPago == 'debito' &&
                tx.tipo != 'transferencia';
          })
          .fold<double>(0, (sum, row) {
            final tx = row.readTable(_db.transacciones);
            return sum + tx.montoTotal;
          });

      // Cuotas pendientes del mes
      final totalCuotas = cuotas.fold<double>(0, (sum, c) => sum + c.monto);

      final egresosTotal = egresosDebito + totalCuotas;
      final balance = ingresos - egresosTotal;
      final tasaAhorro = ResumenFinanciero.calcularTasaAhorro(ingresos, egresosTotal);

      return ResumenFinanciero(
        ingresos: ingresos,
        egresos: egresosTotal,
        balance: balance,
        tasaAhorro: tasaAhorro,
      );
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // GASTOS POR CATEGORÍA
  // ────────────────────────────────────────────────────────────────────────────

  /// Stream reactivo de gastos agregados por categoría
  ///
  /// Usa JOIN con categorías y agrega en Dart (Drift no soporta GROUP BY en watch).
  /// Excluye transferencias y transacciones eliminadas.
  ///
  /// [filtroFormaPago]:
  /// - 'debito': Solo egresos directos (efectivo/débito) - Flujo de Caja
  /// - 'credito': Solo compras a crédito - Deuda Generada
  /// - null: Consolidado (ambos tipos de gasto)
  Stream<List<CategoriaGastoReporte>> watchGastosPorCategoria(
    DateTime inicioMes,
    DateTime finMes, {
    String? filtroFormaPago, // 'debito', 'credito', o null
  }) {
    final query = _db.select(_db.transacciones).join([
      leftOuterJoin(
        _db.categorias,
        _db.categorias.id.equalsExp(_db.transacciones.categoriaId),
      ),
    ]);

    // Construir filtros base
    var whereCondition = _db.transacciones.deletedAt.isNull() &
        _db.transacciones.tipo.equals('egreso') &
        _db.transacciones.tipo.isNotValue('transferencia') &
        _db.transacciones.fecha.isBiggerOrEqualValue(inicioMes) &
        _db.transacciones.fecha.isSmallerOrEqualValue(finMes);

    // Añadir filtro de forma de pago si se especifica
    if (filtroFormaPago != null) {
      whereCondition = whereCondition & _db.transacciones.formaPago.equals(filtroFormaPago);
    }

    query.where(whereCondition);

    return query.watch().map((rows) {
      // Agrupar manualmente por categoría (Drift watch no soporta GROUP BY nativo)
      final Map<int, CategoriaGastoReporte> mapa = {};
      double totalEgresos = 0;

      for (final row in rows) {
        final tx = row.readTable(_db.transacciones);
        final cat = row.readTableOrNull(_db.categorias);

        final catId = cat?.id ?? 0;
        final nombre = cat?.nombre ?? 'Sin categoría';
        final color = cat?.color ?? '#808080';
        final icono = cat?.icono;

        totalEgresos += tx.montoTotal;

        if (mapa.containsKey(catId)) {
          final actual = mapa[catId]!;
          mapa[catId] = CategoriaGastoReporte(
            categoriaId: catId,
            nombre: nombre,
            color: color,
            icono: icono,
            totalGasto: actual.totalGasto + tx.montoTotal,
            porcentajeTotal: 0, // Se calcula después
          );
        } else {
          mapa[catId] = CategoriaGastoReporte(
            categoriaId: catId,
            nombre: nombre,
            color: color,
            icono: icono,
            totalGasto: tx.montoTotal,
            porcentajeTotal: 0,
          );
        }
      }

      // Calcular porcentajes y ordenar por total descendente
      final lista = mapa.values.map((cat) {
        final porcentaje = totalEgresos > 0 ? (cat.totalGasto / totalEgresos) * 100 : 0.0;
        return CategoriaGastoReporte(
          categoriaId: cat.categoriaId,
          nombre: cat.nombre,
          color: cat.color,
          icono: cat.icono,
          totalGasto: cat.totalGasto,
          porcentajeTotal: porcentaje.toDouble(),
        );
      }).toList()
        ..sort((a, b) => b.totalGasto.compareTo(a.totalGasto));

      return lista;
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // HISTÓRICO MENSUAL
  // ────────────────────────────────────────────────────────────────────────────

  /// Obtiene histórico de los últimos N meses (query única, NO N+1)
  ///
  /// Usa agregación manual por mes. Idealmente debería usar customSelect con
  /// GROUP BY strftime('%Y-%m', fecha), pero para mantener compatibilidad
  /// con el sistema de tipos de Drift, hacemos agregación en Dart.
  Future<List<MesHistoricoReporte>> getHistoricoUltimosMeses(int cantidadMeses) async {
    final ahora = DateTime.now();
    final inicioRango = DateTime(ahora.year, ahora.month - cantidadMeses + 1, 1);
    final finRango = DateTime(ahora.year, ahora.month + 1, 0, 23, 59, 59);

    // Query única para todo el rango
    final txs = await (_db.select(_db.transacciones)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.tipo.isNotValue('transferencia') &
              t.fecha.isBiggerOrEqualValue(inicioRango) &
              t.fecha.isSmallerOrEqualValue(finRango)))
        .get();

    // Agrupar por mes en Dart
    final Map<String, MesHistoricoReporte> mapa = {};

    // Inicializar todos los meses con 0
    for (int i = cantidadMeses - 1; i >= 0; i--) {
      final mes = DateTime(ahora.year, ahora.month - i, 1);
      final mesKey = '${mes.year}-${mes.month.toString().padLeft(2, '0')}';
      mapa[mesKey] = MesHistoricoReporte(
        mesKey: mesKey,
        nombreMes: _nombreMesCorto(mes),
        ingresos: 0,
        egresos: 0,
        balance: 0,
      );
    }

    // Agregar transacciones a su mes correspondiente
    for (final tx in txs) {
      final mesKey = '${tx.fecha.year}-${tx.fecha.month.toString().padLeft(2, '0')}';
      if (!mapa.containsKey(mesKey)) continue;

      final actual = mapa[mesKey]!;
      final ingresos = tx.tipo == 'ingreso' ? actual.ingresos + tx.montoTotal : actual.ingresos;
      final egresos = tx.tipo == 'egreso' ? actual.egresos + tx.montoTotal : actual.egresos;

      mapa[mesKey] = MesHistoricoReporte(
        mesKey: mesKey,
        nombreMes: actual.nombreMes,
        ingresos: ingresos,
        egresos: egresos,
        balance: ingresos - egresos,
      );
    }

    // Convertir a lista ordenada cronológicamente
    final lista = mapa.values.toList()
      ..sort((a, b) => a.mesKey.compareTo(b.mesKey));

    return lista;
  }

  /// Stream reactivo del histórico (se recalcula cuando cambian transacciones)
  ///
  /// Calcula egresos mensuales como: egresos débito/efectivo + cuotas exigibles del mes.
  /// Excluye transferencias y transacciones eliminadas para ser consistente con el resumen.
  Stream<List<MesHistoricoReporte>> watchHistoricoUltimosMeses(int cantidadMeses) {
    final ahora = DateTime.now();
    final inicioRango = DateTime(ahora.year, ahora.month - cantidadMeses + 1, 1);
    final finRango = DateTime(ahora.year, ahora.month + 1, 0, 23, 59, 59);

    // Watch de transacciones con JOIN a cuentas
    final txQuery = _db.select(_db.transacciones).join([
      innerJoin(
        _db.cuentas,
        _db.cuentas.id.equalsExp(_db.transacciones.cuentaId),
      ),
    ]);
    txQuery.where(
      _db.transacciones.deletedAt.isNull() &
          _db.transacciones.tipo.isNotValue('transferencia') &
          _db.transacciones.fecha.isBiggerOrEqualValue(inicioRango) &
          _db.transacciones.fecha.isSmallerOrEqualValue(finRango),
    );

    // Watch de cuotas en el rango
    final cuotasQuery = _db.select(_db.cuotas)
      ..where((c) =>
          c.deletedAt.isNull() &
          c.pagada.equals(false) &
          c.fechaVencimiento.isBiggerOrEqualValue(inicioRango) &
          c.fechaVencimiento.isSmallerOrEqualValue(finRango));

    return txQuery.watch().asyncMap((rows) async {
      final cuotas = await cuotasQuery.watch().first;

      // Agrupar por mes
      final Map<String, MesHistoricoReporte> mapa = {};

      // Inicializar meses
      for (int i = cantidadMeses - 1; i >= 0; i--) {
        final mes = DateTime(ahora.year, ahora.month - i, 1);
        final mesKey = '${mes.year}-${mes.month.toString().padLeft(2, '0')}';
        mapa[mesKey] = MesHistoricoReporte(
          mesKey: mesKey,
          nombreMes: _nombreMesCorto(mes),
          ingresos: 0,
          egresos: 0,
          balance: 0,
        );
      }

      // Agregar transacciones (solo ingresos y egresos débito)
      for (final row in rows) {
        final tx = row.readTable(_db.transacciones);
        final cuenta = row.readTable(_db.cuentas);
        final mesKey = '${tx.fecha.year}-${tx.fecha.month.toString().padLeft(2, '0')}';
        if (!mapa.containsKey(mesKey)) continue;

        final actual = mapa[mesKey]!;

        // Ingresos solo de cuentas líquidas
        final ingresos = (tx.tipo == 'ingreso' && cuenta.tipo != 'credito')
            ? actual.ingresos + tx.montoTotal
            : actual.ingresos;

        // Egresos solo débito/efectivo (las cuotas se suman después)
        final egresos = (tx.tipo == 'egreso' && tx.formaPago == 'debito')
            ? actual.egresos + tx.montoTotal
            : actual.egresos;

        mapa[mesKey] = MesHistoricoReporte(
          mesKey: mesKey,
          nombreMes: actual.nombreMes,
          ingresos: ingresos,
          egresos: egresos,
          balance: 0, // Se calcula al final
        );
      }

      // Agregar cuotas a su mes correspondiente
      for (final cuota in cuotas) {
        final mesKey = '${cuota.fechaVencimiento.year}-${cuota.fechaVencimiento.month.toString().padLeft(2, '0')}';
        if (!mapa.containsKey(mesKey)) continue;

        final actual = mapa[mesKey]!;
        mapa[mesKey] = MesHistoricoReporte(
          mesKey: mesKey,
          nombreMes: actual.nombreMes,
          ingresos: actual.ingresos,
          egresos: actual.egresos + cuota.monto,
          balance: 0,
        );
      }

      // Calcular balance final
      return mapa.values.map((m) {
        return MesHistoricoReporte(
          mesKey: m.mesKey,
          nombreMes: m.nombreMes,
          ingresos: m.ingresos,
          egresos: m.egresos,
          balance: m.ingresos - m.egresos,
        );
      }).toList()
        ..sort((a, b) => a.mesKey.compareTo(b.mesKey));
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // INFORMACIÓN DE CRÉDITO Y CUOTAS
  // ────────────────────────────────────────────────────────────────────────────

  /// Stream reactivo del total de cuotas exigibles en un mes
  Stream<double> watchCuotasMensuales(DateTime inicioMes, DateTime finMes) {
    return (_db.select(_db.cuotas)
          ..where((c) =>
              c.deletedAt.isNull() &
              c.pagada.equals(false) &
              c.fechaVencimiento.isBiggerOrEqualValue(inicioMes) &
              c.fechaVencimiento.isSmallerOrEqualValue(finMes)))
        .watch()
        .map((cuotas) => cuotas.fold<double>(0, (sum, c) => sum + c.monto));
  }

  /// Stream reactivo de la deuda total en cuotas pendientes (todas las cuotas futuras)
  Stream<double> watchDeudaTotalCuotasPendientes() {
    return (_db.select(_db.cuotas)
          ..where((c) => c.deletedAt.isNull() & c.pagada.equals(false)))
        .watch()
        .map((cuotas) => cuotas.fold<double>(0, (sum, c) => sum + c.monto));
  }

  // ────────────────────────────────────────────────────────────────────────────
  // UTILIDADES
  // ────────────────────────────────────────────────────────────────────────────

  String _nombreMesCorto(DateTime fecha) {
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return meses[fecha.month - 1];
  }
}
