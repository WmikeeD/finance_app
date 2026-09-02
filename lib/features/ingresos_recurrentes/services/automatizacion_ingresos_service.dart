import 'package:drift/drift.dart';
import '../../../core/database/database.dart';
import '../../../core/utils/date_financial_utils.dart';

/// Servicio para automatizar el registro de ingresos recurrentes
///
/// Este servicio evalúa los ingresos recurrentes activos y genera automáticamente
/// las transacciones correspondientes cuando se cumple la fecha de pago.
class AutomatizacionIngresosService {
  final AppDatabase _db;

  AutomatizacionIngresosService(this._db);

  /// Procesa todos los ingresos recurrentes activos para el mes actual
  ///
  /// Este método debe ser llamado al iniciar la app o al entrar a la vista principal.
  /// Evalúa cada ingreso recurrente activo y, si la fecha de pago ya pasó,
  /// verifica si ya existe la transacción correspondiente. Si no existe, la crea.
  Future<int> procesarIngresosRecurrentesMesActual() async {
    final ahora = DateTime.now();
    final mesActual = DateTime(ahora.year, ahora.month, 1);

    // Obtener todos los ingresos recurrentes activos
    final ingresosActivos = await (_db.select(_db.ingresosRecurrentes)
          ..where((i) => i.activo.equals(true))
          ..where((i) => i.deletedAt.isNull()))
        .get();

    int transaccionesCreadas = 0;

    for (final ingreso in ingresosActivos) {
      // Verificar si el ingreso está vigente en este mes
      final esVigente = ingresoVigenteEnMes(
        fechaInicio: ingreso.fechaInicio,
        fechaFin: ingreso.fechaFin,
        mesConsultado: mesActual,
      );

      if (!esVigente) continue;

      // Calcular la fecha de pago según la frecuencia
      final fechaPago = _calcularFechaPago(
        mes: mesActual,
        frecuencia: ingreso.frecuencia,
        diaMes: ingreso.diaMes,
      );

      // Verificar si ya pasó la fecha de pago
      if (ahora.isBefore(fechaPago)) continue;

      // Verificar si ya existe una transacción para este ingreso en este mes
      final yaExiste = await _existeTransaccionIngresoEnMes(
        ingreso: ingreso,
        mes: mesActual,
        fechaPago: fechaPago,
      );

      if (yaExiste) continue;

      // Crear la transacción automáticamente
      await _crearTransaccionIngreso(ingreso, fechaPago);
      transaccionesCreadas++;
    }

    return transaccionesCreadas;
  }

  /// Procesa ingresos recurrentes con frecuencia quincenal (15 y fin de mes)
  ///
  /// Este método es útil para procesar el segundo pago quincenal (fin de mes)
  /// cuando ya pasó el día 15 pero aún no se ha llegado al fin de mes.
  Future<int> procesarIngresosQuincenalesMesActual() async {
    final ahora = DateTime.now();
    final mesActual = DateTime(ahora.year, ahora.month, 1);

    // Obtener ingresos quincenales activos
    final ingresosQuincenales = await (_db.select(_db.ingresosRecurrentes)
          ..where((i) => i.activo.equals(true))
          ..where((i) => i.deletedAt.isNull())
          ..where((i) => i.frecuencia.equals('quincenal')))
        .get();

    int transaccionesCreadas = 0;

    for (final ingreso in ingresosQuincenales) {
      // Verificar vigencia
      final esVigente = ingresoVigenteEnMes(
        fechaInicio: ingreso.fechaInicio,
        fechaFin: ingreso.fechaFin,
        mesConsultado: mesActual,
      );

      if (!esVigente) continue;

      // Procesar pago del día 15
      if (ahora.day >= 15) {
        final fecha15 = DateTime(ahora.year, ahora.month, 15);
        final yaExiste15 = await _existeTransaccionIngresoEnMes(
          ingreso: ingreso,
          mes: mesActual,
          fechaPago: fecha15,
          buscarQuincenal: true,
        );

        if (!yaExiste15) {
          await _crearTransaccionIngreso(ingreso, fecha15);
          transaccionesCreadas++;
        }
      }

      // Procesar pago de fin de mes (solo si ya estamos en el último día hábil)
      final ultimoDiaHabil = obtenerUltimoDiaHabil(ahora.year, ahora.month);
      if (ahora.isAfter(ultimoDiaHabil) ||
          (ahora.year == ultimoDiaHabil.year &&
          ahora.month == ultimoDiaHabil.month &&
          ahora.day == ultimoDiaHabil.day)) {
        final yaExisteFinMes = await _existeTransaccionIngresoEnMes(
          ingreso: ingreso,
          mes: mesActual,
          fechaPago: ultimoDiaHabil,
          buscarQuincenal: true,
        );

        if (!yaExisteFinMes) {
          await _crearTransaccionIngreso(ingreso, ultimoDiaHabil);
          transaccionesCreadas++;
        }
      }
    }

    return transaccionesCreadas;
  }

  /// Calcula la fecha de pago según la frecuencia del ingreso recurrente
  DateTime _calcularFechaPago({
    required DateTime mes,
    required String frecuencia,
    int? diaMes,
  }) {
    switch (frecuencia) {
      case 'ultimo_dia_habil':
        return obtenerUltimoDiaHabil(mes.year, mes.month);

      case 'primer_dia_habil':
        return obtenerPrimerDiaHabil(mes.year, mes.month);

      case 'dia_fijo':
        if (diaMes == null) {
          // Fallback al primer día del mes si no se especificó día
          return DateTime(mes.year, mes.month, 1);
        }
        // Asegurar que el día no exceda el último día del mes
        final ultimoDia = DateTime(mes.year, mes.month + 1, 0).day;
        final diaAjustado = diaMes > ultimoDia ? ultimoDia : diaMes;
        return DateTime(mes.year, mes.month, diaAjustado);

      case 'quincenal':
        // Para quincenales, retornar el día 15 por defecto
        // El procesamiento del fin de mes se maneja por separado
        return DateTime(mes.year, mes.month, 15);

      default:
        // Fallback al primer día del mes
        return DateTime(mes.year, mes.month, 1);
    }
  }

  /// Verifica si ya existe una transacción de ingreso para este ingreso recurrente en este mes
  Future<bool> _existeTransaccionIngresoEnMes({
    required IngresoRecurrente ingreso,
    required DateTime mes,
    required DateTime fechaPago,
    bool buscarQuincenal = false,
  }) async {
    // Buscar transacciones de tipo 'ingreso' con el mismo monto y cuenta
    // en un rango de ±3 días alrededor de la fecha de pago calculada
    final fechaMin = fechaPago.subtract(const Duration(days: 3));
    final fechaMax = fechaPago.add(const Duration(days: 3));

    final query = _db.select(_db.transacciones)
      ..where((t) => t.tipo.equals('ingreso'))
      ..where((t) => t.cuentaId.equals(ingreso.cuentaId))
      ..where((t) => t.montoTotal.equals(ingreso.monto))
      ..where((t) => t.fecha.isBiggerOrEqualValue(fechaMin))
      ..where((t) => t.fecha.isSmallerOrEqualValue(fechaMax))
      ..where((t) => t.deletedAt.isNull());

    // Buscar también por descripción similar (coincidencia parcial)
    // Para ingresos automáticos, la descripción debería contener el nombre del ingreso
    final transacciones = await query.get();

    if (transacciones.isEmpty) return false;

    // Verificar si alguna transacción coincide con la descripción del ingreso
    for (final tx in transacciones) {
      if (tx.descripcion.toLowerCase().contains(ingreso.descripcion.toLowerCase()) ||
          ingreso.descripcion.toLowerCase().contains(tx.descripcion.toLowerCase())) {
        return true;
      }
    }

    // Si no encontramos coincidencia por descripción, considerar que existe
    // si hay una transacción con el mismo monto, cuenta y fecha cercana
    return transacciones.isNotEmpty;
  }

  /// Crea una transacción de ingreso automáticamente
  Future<void> _crearTransaccionIngreso(
    IngresoRecurrente ingreso,
    DateTime fechaPago,
  ) async {
    // Obtener o crear categoría "Sueldo/Ingresos"
    final categoriaId = await _obtenerCategoriaIngreso();

    await _db.transaction(() async {
      // Crear la transacción
      await _db.into(_db.transacciones).insert(
        TransaccionesCompanion.insert(
          tipo: 'ingreso',
          montoTotal: ingreso.monto,
          descripcion: ingreso.descripcion,
          fecha: fechaPago,
          formaPago: 'debito',
          cuentaId: ingreso.cuentaId,
          categoriaId: categoriaId,
          esPrestamo: const Value(false),
          personaId: const Value(null),
          cuentaDestinoId: const Value(null),
          transferenciaId: const Value(null),
          cantidadCuotas: const Value(null),
          valorCuota: const Value(null),
        ),
      );

      // Actualizar el saldo de la cuenta
      final cuenta = await (_db.select(_db.cuentas)
            ..where((c) => c.id.equals(ingreso.cuentaId)))
          .getSingle();

      await (_db.update(_db.cuentas)
            ..where((c) => c.id.equals(ingreso.cuentaId)))
          .write(
        CuentasCompanion(
          saldo: Value(cuenta.saldo + ingreso.monto),
          sincronizado: const Value(false),
          ultimaModificacion: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Obtiene o crea la categoría "Sueldo/Ingresos" para transacciones automáticas
  Future<int> _obtenerCategoriaIngreso() async {
    // Buscar categoría existente "Sueldo" o "Ingresos"
    final categorias = await (_db.select(_db.categorias)
          ..where((c) => c.tipo.equals('ingreso'))
          ..where((c) => c.activa.equals(true)))
        .get();

    for (final cat in categorias) {
      final nombre = cat.nombre.toLowerCase();
      if (nombre.contains('sueldo') || nombre.contains('ingreso')) {
        return cat.id;
      }
    }

    // Si no existe, crear una categoría "Sueldo"
    return await _db.into(_db.categorias).insert(
      CategoriasCompanion.insert(
        nombre: 'Sueldo',
        tipo: 'ingreso',
        icono: const Value('💼'),
      ),
    );
  }

  /// Procesa automáticamente los ingresos recurrentes pendientes
  /// desde el inicio del mes hasta la fecha actual
  ///
  /// Útil para casos donde la app no se abrió en varios días
  /// y hay que "ponerse al día" con los pagos pendientes.
  Future<int> procesarIngresosPendientes() async {
    final ahora = DateTime.now();
    final inicioMes = DateTime(ahora.year, ahora.month, 1);

    final ingresosActivos = await (_db.select(_db.ingresosRecurrentes)
          ..where((i) => i.activo.equals(true))
          ..where((i) => i.deletedAt.isNull()))
        .get();

    int transaccionesCreadas = 0;

    for (final ingreso in ingresosActivos) {
      // Verificar vigencia
      final esVigente = ingresoVigenteEnMes(
        fechaInicio: ingreso.fechaInicio,
        fechaFin: ingreso.fechaFin,
        mesConsultado: inicioMes,
      );

      if (!esVigente) continue;

      // Calcular fechas de pago según frecuencia
      final fechasPago = _calcularTodasFechasPagoDelMes(
        mes: inicioMes,
        frecuencia: ingreso.frecuencia,
        diaMes: ingreso.diaMes,
      );

      for (final fechaPago in fechasPago) {
        // Solo procesar si la fecha ya pasó
        if (ahora.isBefore(fechaPago)) continue;

        final yaExiste = await _existeTransaccionIngresoEnMes(
          ingreso: ingreso,
          mes: inicioMes,
          fechaPago: fechaPago,
          buscarQuincenal: ingreso.frecuencia == 'quincenal',
        );

        if (!yaExiste) {
          await _crearTransaccionIngreso(ingreso, fechaPago);
          transaccionesCreadas++;
        }
      }
    }

    return transaccionesCreadas;
  }

  /// Calcula todas las fechas de pago del mes según la frecuencia
  List<DateTime> _calcularTodasFechasPagoDelMes({
    required DateTime mes,
    required String frecuencia,
    int? diaMes,
  }) {
    if (frecuencia == 'quincenal') {
      return [
        DateTime(mes.year, mes.month, 15),
        obtenerUltimoDiaHabil(mes.year, mes.month),
      ];
    }

    return [_calcularFechaPago(mes: mes, frecuencia: frecuencia, diaMes: diaMes)];
  }
}
