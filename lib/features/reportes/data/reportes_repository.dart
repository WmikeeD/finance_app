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

  /// Stream reactivo del total de cuotas exigibles en un mes (FASE 1-2-3: ARRASTRE DE MORA)
  ///
  /// Calcula la "Sábana de Facturación" por ciclo bancario de cada tarjeta:
  /// - Para cada tarjeta de crédito activa con diaCierre/diaPago configurados
  /// - Determina la ventana del ciclo de facturación del mes consultado
  /// - Suma las cuotas exigibles del ciclo (fechaVencimiento = diaPago del ciclo)
  /// - **ARRASTRE DE MORA**: Suma todas las cuotas vencidas impagas (fechaVencimiento <= now)
  /// - Resta los abonos realizados al ciclo (transferencias a la tarjeta)
  /// - **SOLO suma ciclos cerrados o vencidos** (now > fechaCierre)
  /// - Retorna el saldo pendiente exigible total
  Stream<double> watchCuotasMensuales(DateTime inicioMes, DateTime finMes) {
    // Watch de todas las tarjetas de crédito activas
    final cuentasQuery = _db.select(_db.cuentas)
      ..where((c) => c.tipo.equals('credito') & c.activa.equals(true));

    return cuentasQuery.watch().asyncMap((tarjetas) async {
      double totalExigible = 0.0;
      final now = DateTime.now();

      for (final tarjeta in tarjetas) {
        final diaCierre = tarjeta.diaCierre;
        final diaPago = tarjeta.diaPago;

        // Saltar tarjetas sin configuración de ciclo
        if (diaCierre == null || diaPago == null) continue;

        // 1. ARRASTRE DE MORA: Buscar cuotas vencidas impagas (prioridad)
        final cuotasVencidas = await (_db.select(_db.cuotas).join([
          innerJoin(
            _db.transacciones,
            _db.transacciones.id.equalsExp(_db.cuotas.transaccionId),
          ),
        ])
              ..where(
                _db.transacciones.cuentaId.equals(tarjeta.id) &
                    _db.cuotas.deletedAt.isNull() &
                    _db.transacciones.deletedAt.isNull() &
                    _db.cuotas.pagada.equals(false) &
                    _db.cuotas.fechaVencimiento.isSmallerOrEqualValue(now),
              ))
            .get();

        final totalVencido = cuotasVencidas.fold<double>(
          0,
          (sum, row) => sum + row.readTable(_db.cuotas).monto,
        );

        // Si hay cuotas vencidas, sumar inmediatamente al exigible
        if (totalVencido > 0) {
          totalExigible += totalVencido;
          continue; // No evaluar ciclo actual si ya hay mora
        }

        // 2. Calcular ventana del ciclo para el mes consultado
        final ciclo = _calcularVentanaCiclo(inicioMes, diaCierre, diaPago);

        // BLINDAJE: Solo sumar ciclos CERRADOS (now > fechaCierre)
        // Los ciclos aún abiertos NO son exigibles
        if (!now.isAfter(ciclo.fechaCierre)) continue;

        // Total facturado en el ciclo (cuotas que vencen en este ciclo)
        final cuotasCiclo = await (_db.select(_db.cuotas).join([
          innerJoin(
            _db.transacciones,
            _db.transacciones.id.equalsExp(_db.cuotas.transaccionId),
          ),
        ])
              ..where(
                _db.transacciones.cuentaId.equals(tarjeta.id) &
                    _db.cuotas.deletedAt.isNull() &
                    _db.transacciones.deletedAt.isNull() &
                    _db.cuotas.fechaVencimiento.equals(ciclo.fechaVencimiento),
              ))
            .get();

        final totalFacturado = cuotasCiclo.fold<double>(
          0,
          (sum, row) => sum + row.readTable(_db.cuotas).monto,
        );

        // Abonos realizados al ciclo (transferencias a esta tarjeta en ventana de pago)
        final abonosCiclo = await (_db.select(_db.transacciones)
              ..where((t) =>
                  t.tipo.equals('transferencia') &
                  t.cuentaDestinoId.equals(tarjeta.id) &
                  t.deletedAt.isNull() &
                  t.fecha.isBiggerOrEqualValue(ciclo.inicioCiclo) &
                  t.fecha.isSmallerOrEqualValue(ciclo.fechaVencimiento)))
            .get();

        final totalAbonado = abonosCiclo.fold<double>(
          0,
          (sum, t) => sum + t.montoTotal,
        );

        // Saldo pendiente del ciclo
        final saldoPendiente = (totalFacturado - totalAbonado).clamp(0.0, double.infinity);

        totalExigible += saldoPendiente;
      }

      return totalExigible;
    });
  }

  /// Calcula la ventana del ciclo bancario para un mes dado
  ///
  /// Retorna:
  /// - inicioCiclo: fecha de cierre del ciclo anterior (ciclo en curso)
  /// - fechaVencimiento: fecha de pago del ciclo actual (diaPago del mes consultado o siguiente)
  _VentanaCiclo _calcularVentanaCiclo(
    DateTime mesConsultado,
    int diaCierre,
    int diaPago,
  ) {
    final year = mesConsultado.year;
    final month = mesConsultado.month;

    // Fecha de cierre del mes consultado
    final cierreActual = DateTime(year, month, diaCierre);

    // Fecha de cierre del mes anterior (inicio del ciclo)
    final cierreAnterior = DateTime(year, month - 1, diaCierre);

    // Determinar fecha de vencimiento según si diaPago es antes o después del cierre
    DateTime fechaVencimiento;
    if (diaPago > diaCierre) {
      // Pago en el mismo mes que el cierre (ej: cierre 15, pago 25)
      fechaVencimiento = DateTime(year, month, diaPago);
    } else {
      // Pago en el mes siguiente (ej: cierre 25, pago 5)
      fechaVencimiento = DateTime(year, month + 1, diaPago);
    }

    return _VentanaCiclo(
      inicioCiclo: cierreAnterior,
      fechaCierre: cierreActual,
      fechaVencimiento: fechaVencimiento,
    );
  }

  /// Stream reactivo de la deuda total en cuotas pendientes (todas las cuotas futuras)
  Stream<double> watchDeudaTotalCuotasPendientes() {
    return (_db.select(_db.cuotas)
          ..where((c) => c.deletedAt.isNull() & c.pagada.equals(false)))
        .watch()
        .map((cuotas) => cuotas.fold<double>(0, (sum, c) => sum + c.monto));
  }

  /// Stream reactivo del detalle de facturación por tarjeta (FASE 2-3: UI + ARRASTRE DE MORA)
  ///
  /// Retorna el desglose completo por cada tarjeta de crédito:
  /// - Información del ciclo (fechas de cierre y vencimiento)
  /// - Totales financieros (facturado, abonado, saldo pendiente)
  /// - **ARRASTRE DE MORA**: Lista de cuotas vencidas impagas (prioridad)
  /// - Lista de cuotas asociadas al ciclo actual
  Stream<List<FacturacionTarjetaModel>> watchDetalleFacturacionTarjetas(
    DateTime mesConsultado,
  ) {
    // Watch de todas las tarjetas de crédito activas
    final cuentasQuery = _db.select(_db.cuentas)
      ..where((c) => c.tipo.equals('credito') & c.activa.equals(true));

    return cuentasQuery.watch().asyncMap((tarjetas) async {
      final List<FacturacionTarjetaModel> resultados = [];
      final now = DateTime.now();

      for (final tarjeta in tarjetas) {
        final diaCierre = tarjeta.diaCierre;
        final diaPago = tarjeta.diaPago;

        // Saltar tarjetas sin configuración de ciclo
        if (diaCierre == null || diaPago == null) continue;

        // Calcular ventana del ciclo para el mes consultado
        final ciclo = _calcularVentanaCiclo(mesConsultado, diaCierre, diaPago);

        // 1. ARRASTRE DE MORA: Cuotas vencidas impagas (prioridad absoluta)
        final cuotasVencidasRows = await (_db.select(_db.cuotas).join([
          innerJoin(
            _db.transacciones,
            _db.transacciones.id.equalsExp(_db.cuotas.transaccionId),
          ),
        ])
              ..where(
                _db.transacciones.cuentaId.equals(tarjeta.id) &
                    _db.cuotas.deletedAt.isNull() &
                    _db.transacciones.deletedAt.isNull() &
                    _db.cuotas.pagada.equals(false) &
                    _db.cuotas.fechaVencimiento.isSmallerOrEqualValue(now),
              )
              ..orderBy([
                OrderingTerm.asc(_db.cuotas.fechaVencimiento),
                OrderingTerm.asc(_db.cuotas.numeroCuota),
              ]))
            .get();

        final cuotasVencidas = cuotasVencidasRows.map((row) {
          final cuota = row.readTable(_db.cuotas);
          final tx = row.readTable(_db.transacciones);
          return CuotaDetalleModel(
            id: cuota.id,
            descripcion: tx.descripcion,
            numeroCuota: cuota.numeroCuota,
            totalCuotas: tx.cantidadCuotas ?? 1,
            monto: cuota.monto,
            fechaVencimiento: cuota.fechaVencimiento,
            pagada: cuota.pagada,
            esVencida: true, // ← Marcador de mora
          );
        }).toList();

        // 2. Cuotas del ciclo actual (solo si no hay mora)
        final cuotasCicloRows = await (_db.select(_db.cuotas).join([
          innerJoin(
            _db.transacciones,
            _db.transacciones.id.equalsExp(_db.cuotas.transaccionId),
          ),
        ])
              ..where(
                _db.transacciones.cuentaId.equals(tarjeta.id) &
                    _db.cuotas.deletedAt.isNull() &
                    _db.transacciones.deletedAt.isNull() &
                    _db.cuotas.fechaVencimiento.equals(ciclo.fechaVencimiento),
              )
              ..orderBy([
                OrderingTerm.asc(_db.transacciones.fecha),
                OrderingTerm.asc(_db.cuotas.numeroCuota),
              ]))
            .get();

        final cuotasCiclo = cuotasCicloRows.map((row) {
          final cuota = row.readTable(_db.cuotas);
          final tx = row.readTable(_db.transacciones);
          return CuotaDetalleModel(
            id: cuota.id,
            descripcion: tx.descripcion,
            numeroCuota: cuota.numeroCuota,
            totalCuotas: tx.cantidadCuotas ?? 1,
            monto: cuota.monto,
            fechaVencimiento: cuota.fechaVencimiento,
            pagada: cuota.pagada,
            esVencida: false,
          );
        }).toList();

        // Consolidar: vencidas + ciclo actual
        final todasCuotas = [...cuotasVencidas, ...cuotasCiclo];

        // Total facturado (vencidas + ciclo)
        final totalFacturado = todasCuotas.fold<double>(
          0,
          (sum, c) => sum + c.monto,
        );

        // Abonos realizados (ventana amplia para cubrir mora histórica)
        final abonosCiclo = await (_db.select(_db.transacciones)
              ..where((t) =>
                  t.tipo.equals('transferencia') &
                  t.cuentaDestinoId.equals(tarjeta.id) &
                  t.deletedAt.isNull() &
                  t.fecha.isBiggerOrEqualValue(ciclo.inicioCiclo) &
                  t.fecha.isSmallerOrEqualValue(ciclo.fechaVencimiento)))
            .get();

        final totalAbonado = abonosCiclo.fold<double>(
          0,
          (sum, t) => sum + t.montoTotal,
        );

        // Saldo pendiente
        final saldoPendiente = (totalFacturado - totalAbonado).clamp(0.0, double.infinity);

        // Incluir tarjetas con cuotas (vencidas o del ciclo)
        if (todasCuotas.isNotEmpty) {
          resultados.add(
            FacturacionTarjetaModel(
              cuentaId: tarjeta.id,
              nombreTarjeta: tarjeta.nombre,
              colorHex: tarjeta.color,
              fechaCierre: ciclo.fechaCierre,
              fechaVencimiento: ciclo.fechaVencimiento,
              totalFacturado: totalFacturado,
              totalAbonado: totalAbonado,
              saldoPendiente: saldoPendiente,
              cuotas: todasCuotas,
              cuotasVencidas: cuotasVencidas, // ← Lista separada de vencidas
            ),
          );
        }
      }

      return resultados;
    });
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

/// Ventana de tiempo de un ciclo de facturación de tarjeta de crédito
class _VentanaCiclo {
  final DateTime inicioCiclo;      // Cierre del ciclo anterior
  final DateTime fechaCierre;      // Cierre del ciclo actual
  final DateTime fechaVencimiento; // Fecha de pago (diaPago)

  const _VentanaCiclo({
    required this.inicioCiclo,
    required this.fechaCierre,
    required this.fechaVencimiento,
  });
}

/// DTO: Detalle de facturación de una tarjeta de crédito para un ciclo específico
class FacturacionTarjetaModel {
  final int cuentaId;
  final String nombreTarjeta;
  final String? colorHex;
  final DateTime fechaCierre;
  final DateTime fechaVencimiento;
  final double totalFacturado;
  final double totalAbonado;
  final double saldoPendiente;
  final List<CuotaDetalleModel> cuotas;
  final List<CuotaDetalleModel> cuotasVencidas; // ← FASE 3: Lista separada de mora

  const FacturacionTarjetaModel({
    required this.cuentaId,
    required this.nombreTarjeta,
    required this.colorHex,
    required this.fechaCierre,
    required this.fechaVencimiento,
    required this.totalFacturado,
    required this.totalAbonado,
    required this.saldoPendiente,
    required this.cuotas,
    this.cuotasVencidas = const [], // ← Default vacío
  });

  // ── MÁQUINA DE ESTADOS (FASE 2-3: PRIORIDAD DE MORA) ───────────────────────

  /// Indica si la tarjeta tiene cuotas vencidas impagas (MORA)
  bool get tieneMora => cuotasVencidas.isNotEmpty;

  /// Indica si la tarjeta está al día (sin saldo pendiente)
  bool get alDia => saldoPendiente <= 0;

  /// Indica si el ciclo está en facturación (aún no cierra)
  /// Ciclo abierto acumulando gastos, NO exigible aún
  bool get enFacturacion {
    final now = DateTime.now();
    return saldoPendiente > 0 && !now.isAfter(fechaCierre) && !tieneMora;
  }

  /// Indica si el ciclo está cerrado y dentro del plazo de pago
  /// Estado de cuenta emitido, saldo exigible, dentro del plazo
  bool get porPagar {
    final now = DateTime.now();
    return saldoPendiente > 0 &&
        now.isAfter(fechaCierre) &&
        !now.isAfter(fechaVencimiento) &&
        !tieneMora;
  }

  /// Indica si el ciclo está vencido (fecha de pago pasó y hay saldo pendiente)
  /// Superó la fecha límite sin liquidar el saldo O tiene cuotas en mora
  bool get vencido {
    if (tieneMora) return true; // ← Mora tiene PRIORIDAD ABSOLUTA
    final now = DateTime.now();
    return saldoPendiente > 0 && now.isAfter(fechaVencimiento);
  }

  /// Indica si el ciclo es exigible (cerrado o vencido)
  /// Solo estos ciclos cuentan para "Cuotas este Mes"
  bool get esExigible => porPagar || vencido;
}

/// DTO: Detalle de una cuota individual dentro del ciclo de facturación
class CuotaDetalleModel {
  final int id;
  final String descripcion;
  final int numeroCuota;
  final int totalCuotas;
  final double monto;
  final DateTime fechaVencimiento;
  final bool pagada;
  final bool esVencida; // ← FASE 3: Indicador de mora

  const CuotaDetalleModel({
    required this.id,
    required this.descripcion,
    required this.numeroCuota,
    required this.totalCuotas,
    required this.monto,
    required this.fechaVencimiento,
    required this.pagada,
    this.esVencida = false, // ← Default: no vencida
  });

  /// Etiqueta de cuota (ej: "2/12")
  String get etiquetaCuota => '$numeroCuota/$totalCuotas';
}
