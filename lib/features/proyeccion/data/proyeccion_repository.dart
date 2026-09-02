import 'package:drift/drift.dart';
import '../../../core/database/database.dart';
import '../../../core/utils/date_financial_utils.dart';
import '../models/proyeccion_models.dart';
import '../models/simulacion_models.dart';

/// Repositorio para el módulo de Proyección de Cuotas
///
/// Desacopla la lógica de negocio de la UI, proporcionando métodos
/// para consultar ingresos recurrentes y calcular proyecciones de cuotas.
class ProyeccionRepository {
  final AppDatabase _db;

  ProyeccionRepository(this._db);

  // =============================================
  // INGRESOS RECURRENTES
  // =============================================

  /// Stream de ingresos recurrentes activos (no eliminados)
  Stream<List<IngresoRecurrente>> watchIngresosRecurrentes() {
    return (_db.select(_db.ingresosRecurrentes)
          ..where((i) => i.activo.equals(true) & i.deletedAt.isNull())
          ..orderBy([(i) => OrderingTerm.desc(i.fechaInicio)]))
        .watch();
  }

  /// Obtener todos los ingresos recurrentes activos
  Future<List<IngresoRecurrente>> getIngresosRecurrentesActivos() async {
    return await (_db.select(_db.ingresosRecurrentes)
          ..where((i) => i.activo.equals(true) & i.deletedAt.isNull())
          ..orderBy([(i) => OrderingTerm.desc(i.fechaInicio)]))
        .get();
  }

  /// Guardar o actualizar un ingreso recurrente
  Future<int> guardarIngresoRecurrente({
    int? id,
    required String descripcion,
    required double monto,
    required int cuentaId,
    required String frecuencia,
    int? diaMes,
    bool activo = true,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    final companion = IngresosRecurrentesCompanion(
      id: id != null ? Value(id) : const Value.absent(),
      descripcion: Value(descripcion),
      monto: Value(monto),
      cuentaId: Value(cuentaId),
      frecuencia: Value(frecuencia),
      diaMes: Value(diaMes),
      activo: Value(activo),
      fechaInicio: Value(fechaInicio ?? DateTime.now()),
      fechaFin: Value(fechaFin),
      updatedAt: Value(DateTime.now()),
      sincronizado: const Value(false),
      ultimaModificacion: Value(DateTime.now()),
    );

    if (id != null) {
      // Actualizar existente
      await (_db.update(_db.ingresosRecurrentes)
            ..where((i) => i.id.equals(id)))
          .write(companion);
      return id;
    } else {
      // Insertar nuevo
      return await _db.into(_db.ingresosRecurrentes).insert(companion);
    }
  }

  /// Eliminar (soft-delete) un ingreso recurrente
  Future<void> eliminarIngresoRecurrente(int id) async {
    await (_db.update(_db.ingresosRecurrentes)..where((i) => i.id.equals(id)))
        .write(
      IngresosRecurrentesCompanion(
        deletedAt: Value(DateTime.now()),
        sincronizado: const Value(false),
        ultimaModificacion: Value(DateTime.now()),
      ),
    );
  }

  /// Calcular el total de ingresos recurrentes activos para un mes dado
  ///
  /// Utiliza la función [ingresoVigenteEnMes] de date_financial_utils.dart
  /// para validar vigencias con lógica de fechas bancarias.
  Future<double> calcularTotalIngresosRecurrentes(DateTime mes) async {
    final ingresos = await getIngresosRecurrentesActivos();

    double total = 0.0;
    for (final ingreso in ingresos) {
      // ✨ Usar utilidad de días hábiles para validar vigencia
      final esVigente = ingresoVigenteEnMes(
        fechaInicio: ingreso.fechaInicio,
        fechaFin: ingreso.fechaFin,
        mesConsultado: mes,
      );

      if (esVigente) {
        total += ingreso.monto;
      }
    }

    return total;
  }

  // =============================================
  // MOTOR DE ARRASTRE DE LIQUIDEZ
  // =============================================

  /// Calcula el saldo inicial real sumando los balances actuales de todas
  /// las cuentas líquidas activas (excluyendo tarjetas de crédito).
  ///
  /// Fórmula: SUM(saldo) WHERE tipo != 'credito' AND activa = true AND deleted_at IS NULL
  ///
  /// Este saldo representa el dinero disponible en efectivo, cuentas corrientes
  /// y cuentas vista al momento de iniciar la proyección.
  Future<double> _calcularSaldoRealCuentasLiquidas() async {
    final cuentasLiquidas = await (_db.select(_db.cuentas)
          ..where((c) =>
              c.activa.equals(true) &
              c.tipo.isNotValue('credito')))
        .get();

    return cuentasLiquidas.fold<double>(0.0, (sum, cuenta) => sum + cuenta.saldo);
  }

  // =============================================
  // PROYECCIÓN DE CUOTAS
  // =============================================

  /// Stream reactivo de proyección de cuotas
  ///
  /// Calcula la proyección de N meses a partir de [mesInicio],
  /// incluyendo cuotas pendientes, ingresos recurrentes, gastos fijos
  /// y préstamos a cobrar.
  ///
  /// Si [compraSimulada] no es null, inyecta cuotas virtuales en memoria
  /// sin persistir en la base de datos.
  Stream<ProyeccionData> watchProyeccionCuotas({
    required DateTime mesInicio,
    required int mesesAVer,
    int? cuentaId,
    bool incluirGastosFijos = false,
    bool incluirPrestamos = false,
    Set<int> prestamosSeleccionados = const {},
    CompraSimulada? compraSimulada,
  }) {
    // Stream combinado: cuotas + ingresos recurrentes + gastos fijos + préstamos + simulación
    return Stream.periodic(const Duration(milliseconds: 500)).asyncMap((_) async {
      return await _calcularProyeccion(
        mesInicio: mesInicio,
        mesesAVer: mesesAVer,
        cuentaId: cuentaId,
        incluirGastosFijos: incluirGastosFijos,
        incluirPrestamos: incluirPrestamos,
        prestamosSeleccionados: prestamosSeleccionados,
        compraSimulada: compraSimulada,
      );
    }).distinct((prev, next) {
      // Evitar emitir duplicados consecutivos comparando meses
      return prev.meses.length == next.meses.length &&
          prev.meses.every((m) => next.meses.any((n) =>
              n.fecha == m.fecha &&
              n.totalEgresos == m.totalEgresos &&
              n.totalIngresos == m.totalIngresos));
    });
  }

  /// Calcular proyección de cuotas (versión Future para uso directo)
  Future<ProyeccionData> calcularProyeccion({
    required DateTime mesInicio,
    required int mesesAVer,
    int? cuentaId,
    bool incluirGastosFijos = false,
    bool incluirPrestamos = false,
    Set<int> prestamosSeleccionados = const {},
    CompraSimulada? compraSimulada,
  }) async {
    return await _calcularProyeccion(
      mesInicio: mesInicio,
      mesesAVer: mesesAVer,
      cuentaId: cuentaId,
      incluirGastosFijos: incluirGastosFijos,
      incluirPrestamos: incluirPrestamos,
      prestamosSeleccionados: prestamosSeleccionados,
      compraSimulada: compraSimulada,
    );
  }

  /// Lógica interna de cálculo de proyección
  ///
  /// Si [compraSimulada] está presente, inyecta cuotas virtuales en los meses
  /// correspondientes sin modificar la base de datos.
  Future<ProyeccionData> _calcularProyeccion({
    required DateTime mesInicio,
    required int mesesAVer,
    int? cuentaId,
    bool incluirGastosFijos = false,
    bool incluirPrestamos = false,
    Set<int> prestamosSeleccionados = const {},
    CompraSimulada? compraSimulada,
  }) async {
    // ✨ PASO 0: Calcular saldo inicial real de cuentas líquidas (Motor de Arrastre)
    final saldoInicialReal = await _calcularSaldoRealCuentasLiquidas();

    // 1. Total de gastos fijos activos de la DB
    double gastosFijosMensual = 0;
    if (incluirGastosFijos) {
      gastosFijosMensual = await _db.totalGastosFijosActivos();
    }

    // 2. Todas las cuotas sin pagar desde mesInicio en adelante (con join)
    final q = _db.select(_db.cuotas).join([
      innerJoin(
        _db.transacciones,
        _db.transacciones.id.equalsExp(_db.cuotas.transaccionId),
      ),
      leftOuterJoin(
        _db.cuentas,
        _db.cuentas.id.equalsExp(_db.transacciones.cuentaId),
      ),
    ]);
    q.where(
      _db.cuotas.pagada.equals(false) &
          _db.cuotas.fechaVencimiento.isBiggerOrEqualValue(mesInicio) &
          _db.transacciones.deletedAt.isNull() &
          _db.cuotas.deletedAt.isNull(),
    );
    if (cuentaId != null) {
      q.where(_db.transacciones.cuentaId.equals(cuentaId));
    }
    q.orderBy([OrderingTerm.asc(_db.cuotas.fechaVencimiento)]);
    final rows = await q.get();

    // 3. Deudas seleccionadas para cobro
    final deudasACobrar = <(Deuda, Persona)>[];
    if (incluirPrestamos && prestamosSeleccionados.isNotEmpty) {
      final dq = _db.select(_db.deudas).join([
        innerJoin(_db.personas, _db.personas.id.equalsExp(_db.deudas.personaId)),
      ]);
      dq.where(
        _db.deudas.id.isIn(prestamosSeleccionados) &
            _db.deudas.deletedAt.isNull(),
      );
      final dRows = await dq.get();
      for (final r in dRows) {
        deudasACobrar.add((r.readTable(_db.deudas), r.readTable(_db.personas)));
      }
    }

    // ✨ PASO 4: Proyección mes a mes con ARRASTRE DE LIQUIDEZ
    final meses = <MesProyeccion>[];
    double saldoAcumuladoAnterior = saldoInicialReal; // Iniciar con saldo real de bancos

    for (int i = 0; i < mesesAVer; i++) {
      final mes = DateTime(mesInicio.year, mesInicio.month + i, 1);

      // Cuotas reales del mes (de la base de datos)
      final cuotasMes = rows
          .where((r) {
            final c = r.readTable(_db.cuotas);
            return c.fechaVencimiento.year == mes.year &&
                c.fechaVencimiento.month == mes.month;
          })
          .map((r) {
            final cuota = r.readTable(_db.cuotas);
            final tx = r.readTable(_db.transacciones);
            final cuenta = r.readTableOrNull(_db.cuentas);
            return CuotaMes(
              descripcion: tx.descripcion,
              numeroCuota: cuota.numeroCuota,
              totalCuotas: tx.cantidadCuotas ?? 1,
              monto: cuota.monto,
              fechaVencimiento: cuota.fechaVencimiento,
              nombreTarjeta: cuenta?.nombre ?? '—',
              transaccionId: cuota.transaccionId,
              esSimulada: false,
            );
          })
          .toList();

      // ✨ Inyectar cuota simulada si aplica en este mes
      if (compraSimulada != null && compraSimulada.aplicaEnMes(mes)) {
        final numeroCuota = compraSimulada.getNumeroCuotaEnMes(mes)!;
        cuotasMes.add(CuotaMes(
          descripcion: '${compraSimulada.descripcion} (SIMULACIÓN)',
          numeroCuota: numeroCuota,
          totalCuotas: compraSimulada.cantidadCuotas,
          monto: compraSimulada.montoCuota,
          fechaVencimiento: mes,
          nombreTarjeta: 'Simulación',
          transaccionId: -1, // ID virtual para identificación
          esSimulada: true,
        ));
      }

      final totalCuotas = cuotasMes.fold<double>(0, (s, c) => s + c.monto);

      // Préstamos a cobrar este mes
      final prestamosDelMes = deudasACobrar
          .where((t) {
            final fecha = t.$1.fechaAcordadaPago;
            return fecha != null &&
                fecha.year == mes.year &&
                fecha.month == mes.month;
          })
          .map((t) => PrestamoCobro(
                personaId: t.$1.personaId,
                nombrePersona: t.$2.nombre,
                monto: t.$1.montoPendiente,
                fechaEsperada: t.$1.fechaAcordadaPago,
              ))
          .toList();

      final totalPrestamos = prestamosDelMes.fold<double>(0, (s, p) => s + p.monto);

      // ✨ Ingresos recurrentes vigentes en este mes (con validación de fechas)
      final totalIngresosRecurrentes = await calcularTotalIngresosRecurrentes(mes);
      final totalIngresos = totalIngresosRecurrentes + totalPrestamos;
      // Total egresos incluye cuotas reales + simuladas + gastos fijos
      final totalEgresos = totalCuotas + gastosFijosMensual;

      // ✨ MOTOR DE ARRASTRE: Cálculos de liquidez acumulada
      final saldoInicial = saldoAcumuladoAnterior;
      final flujoNetoMes = totalIngresos - totalEgresos;
      final saldoFinalAcumulado = saldoInicial + flujoNetoMes;
      final enDeficitAcumulado = saldoFinalAcumulado < 0;

      meses.add(MesProyeccion(
        fecha: mes,
        totalCuotas: totalCuotas,
        totalGastosFijos: gastosFijosMensual,
        totalIngresos: totalIngresos,
        totalEgresos: totalEgresos,
        // ignore: deprecated_member_use_from_same_package
        sobrante: flujoNetoMes, // Mantener compatibilidad retroactiva
        cuotas: cuotasMes,
        prestamosCobrar: prestamosDelMes,
        // Nuevos campos de arrastre de liquidez
        saldoInicial: saldoInicial,
        flujoNetoMes: flujoNetoMes,
        saldoFinalAcumulado: saldoFinalAcumulado,
        enDeficitAcumulado: enDeficitAcumulado,
      ));

      // ✨ Actualizar saldo acumulado para el siguiente mes
      saldoAcumuladoAnterior = saldoFinalAcumulado;
    }

    // 5. Mes de liberación: primer mes tras la última cuota sin pagar
    MesLiberacion? liberacion;
    if (rows.isNotEmpty) {
      final lastRow = rows.last;
      final lastCuota = lastRow.readTable(_db.cuotas);
      final lastTx = lastRow.readTable(_db.transacciones);
      final lastCuenta = lastRow.readTableOrNull(_db.cuentas);

      final now = DateTime.now();
      final mesLib = DateTime(
        lastCuota.fechaVencimiento.year,
        lastCuota.fechaVencimiento.month + 1,
        1,
      );
      final mesesFaltantes =
          ((mesLib.year - now.year) * 12 + mesLib.month - now.month)
              .clamp(0, 999);

      liberacion = MesLiberacion(
        fecha: mesLib,
        descripcionUltima: lastTx.descripcion,
        montoUltima: lastCuota.monto,
        tarjetaUltima: lastCuenta?.nombre ?? '—',
        mesesFaltantes: mesesFaltantes,
      );
    }

    return ProyeccionData(meses: meses, liberacion: liberacion);
  }

  // =============================================
  // SIMULADOR DE COMPRAS
  // =============================================

  /// Calcula el impacto de una compra simulada sobre la proyección
  ///
  /// Compara el escenario base (sin la compra) vs el escenario con la compra
  /// y retorna un [ImpactoSimulacion] con los meses en déficit y el menor saldo.
  Future<ImpactoSimulacion> calcularImpactoSimulacion({
    required CompraSimulada compra,
    required DateTime mesInicio,
    required int mesesAVer,
    int? cuentaId,
    bool incluirGastosFijos = false,
    bool incluirPrestamos = false,
    Set<int> prestamosSeleccionados = const {},
  }) async {
    // Proyección SIN la compra (escenario base)
    final proyeccionBase = await calcularProyeccion(
      mesInicio: mesInicio,
      mesesAVer: mesesAVer,
      cuentaId: cuentaId,
      incluirGastosFijos: incluirGastosFijos,
      incluirPrestamos: incluirPrestamos,
      prestamosSeleccionados: prestamosSeleccionados,
      compraSimulada: null,
    );

    // Proyección CON la compra (escenario simulado)
    final proyeccionSimulada = await calcularProyeccion(
      mesInicio: mesInicio,
      mesesAVer: mesesAVer,
      cuentaId: cuentaId,
      incluirGastosFijos: incluirGastosFijos,
      incluirPrestamos: incluirPrestamos,
      prestamosSeleccionados: prestamosSeleccionados,
      compraSimulada: compra,
    );

    // Identificar meses con déficit
    final mesesConDeficit = <String>[];
    double menorSaldoProyectado = double.infinity;

    for (final mes in proyeccionSimulada.meses) {
      if (mes.saldoFinalAcumulado < menorSaldoProyectado) {
        menorSaldoProyectado = mes.saldoFinalAcumulado;
      }

      if (mes.enDeficitAcumulado) {
        mesesConDeficit.add(mes.nombreMes);
      }
    }

    // Calcular diferencia de liquidez
    final menorSaldoBase = proyeccionBase.meses
        .map((m) => m.saldoFinalAcumulado)
        .reduce((a, b) => a < b ? a : b);
    final diferencia = menorSaldoProyectado - menorSaldoBase;

    return ImpactoSimulacion(
      mesesConDeficit: mesesConDeficit,
      menorSaldoProyectado: menorSaldoProyectado,
      diferenciaTotalLiquidez: diferencia,
    );
  }
}
