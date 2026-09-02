/// Utilidades para cálculo de fechas hábiles y pagos recurrentes
///
/// Implementa la lógica de días hábiles bancarios (lunes a viernes)
/// y resuelve fechas de pago según frecuencias laborales.
library;

/// Verifica si una fecha cae en fin de semana
///
/// Retorna `true` si la fecha es sábado (6) o domingo (7).
bool esFinDeSemana(DateTime fecha) {
  return fecha.weekday == DateTime.saturday || fecha.weekday == DateTime.sunday;
}

/// Calcula el último día hábil de un mes
///
/// Si el último día del mes cae en fin de semana, retrocede al viernes
/// inmediatamente anterior. No considera feriados.
///
/// Ejemplo:
/// - Mes termina en sábado → retorna viernes anterior
/// - Mes termina en domingo → retorna viernes anterior
/// - Mes termina en lunes-viernes → retorna ese mismo día
DateTime obtenerUltimoDiaHabil(int anio, int mes) {
  // Obtener el último día del mes (día 0 del mes siguiente)
  final ultimoDia = DateTime(anio, mes + 1, 0);

  // Si cae en fin de semana, retroceder al viernes
  if (ultimoDia.weekday == DateTime.saturday) {
    return ultimoDia.subtract(const Duration(days: 1)); // Viernes
  } else if (ultimoDia.weekday == DateTime.sunday) {
    return ultimoDia.subtract(const Duration(days: 2)); // Viernes
  }

  return ultimoDia;
}

/// Calcula el primer día hábil de un mes
///
/// Si el primer día del mes cae en fin de semana, avanza al lunes hábil
/// siguiente. No considera feriados.
///
/// Ejemplo:
/// - Mes inicia en sábado → retorna lunes siguiente
/// - Mes inicia en domingo → retorna lunes siguiente
/// - Mes inicia en lunes-viernes → retorna ese mismo día
DateTime obtenerPrimerDiaHabil(int anio, int mes) {
  final primerDia = DateTime(anio, mes, 1);

  // Si cae en fin de semana, avanzar al lunes
  if (primerDia.weekday == DateTime.saturday) {
    return primerDia.add(const Duration(days: 2)); // Lunes
  } else if (primerDia.weekday == DateTime.sunday) {
    return primerDia.add(const Duration(days: 1)); // Lunes
  }

  return primerDia;
}

/// Calcula el día 15 del mes, o el hábil más cercano
///
/// Si el día 15 cae en fin de semana, avanza al lunes siguiente.
DateTime obtenerQuincenaDiaHabil(int anio, int mes) {
  final quincena = DateTime(anio, mes, 15);

  if (quincena.weekday == DateTime.saturday) {
    return quincena.add(const Duration(days: 2)); // Lunes
  } else if (quincena.weekday == DateTime.sunday) {
    return quincena.add(const Duration(days: 1)); // Lunes
  }

  return quincena;
}

/// Resuelve la fecha exacta de pago según la frecuencia configurada
///
/// Soporta las siguientes frecuencias:
/// - `'ultimo_dia_habil'`: Último día hábil del mes (común para sueldos)
/// - `'primer_dia_habil'`: Primer día hábil del mes
/// - `'dia_fijo'`: Día específico del mes (requiere [diaMes])
/// - `'quincenal'`: Día 15 del mes (hábil más cercano)
///
/// Parámetros:
/// - [frecuencia]: Tipo de frecuencia del pago
/// - [anio]: Año del pago
/// - [mes]: Mes del pago (1-12)
/// - [diaMes]: Día del mes para frecuencia 'dia_fijo' (1-31, opcional)
///
/// Retorna la fecha calculada según la frecuencia, ajustada a día hábil.
///
/// Ejemplo:
/// ```dart
/// // Sueldo último día hábil de marzo 2026
/// calcularFechaPago(
///   frecuencia: 'ultimo_dia_habil',
///   anio: 2026,
///   mes: 3,
/// ); // → 2026-03-31 (si es hábil) o viernes anterior
///
/// // Pago fijo día 25
/// calcularFechaPago(
///   frecuencia: 'dia_fijo',
///   anio: 2026,
///   mes: 3,
///   diaMes: 25,
/// ); // → 2026-03-25 (si es hábil) o lunes siguiente
/// ```
DateTime calcularFechaPago({
  required String frecuencia,
  required int anio,
  required int mes,
  int? diaMes,
}) {
  switch (frecuencia) {
    case 'ultimo_dia_habil':
      return obtenerUltimoDiaHabil(anio, mes);

    case 'primer_dia_habil':
      return obtenerPrimerDiaHabil(anio, mes);

    case 'quincenal':
      return obtenerQuincenaDiaHabil(anio, mes);

    case 'dia_fijo':
      if (diaMes == null || diaMes < 1 || diaMes > 31) {
        throw ArgumentError(
          'Para frecuencia "dia_fijo" se requiere diaMes válido (1-31)',
        );
      }

      // Obtener el día solicitado, limitado al último día del mes
      final ultimoDiaDelMes = DateTime(anio, mes + 1, 0).day;
      final diaReal = diaMes > ultimoDiaDelMes ? ultimoDiaDelMes : diaMes;
      final fechaFija = DateTime(anio, mes, diaReal);

      // Si cae en fin de semana, avanzar al lunes siguiente
      if (fechaFija.weekday == DateTime.saturday) {
        return fechaFija.add(const Duration(days: 2)); // Lunes
      } else if (fechaFija.weekday == DateTime.sunday) {
        return fechaFija.add(const Duration(days: 1)); // Lunes
      }

      return fechaFija;

    default:
      throw ArgumentError(
        'Frecuencia no soportada: $frecuencia. '
        'Use: ultimo_dia_habil, primer_dia_habil, dia_fijo, quincenal',
      );
  }
}

/// Verifica si un ingreso recurrente está vigente en un mes dado
///
/// Un ingreso está vigente si:
/// - Su [fechaInicio] es anterior o igual al mes consultado
/// - Su [fechaFin] es null o posterior/igual al mes consultado
///
/// Parámetros:
/// - [fechaInicio]: Fecha de inicio de vigencia del ingreso
/// - [fechaFin]: Fecha de fin de vigencia (nullable)
/// - [mesConsultado]: Mes a evaluar (se normalizará al día 1)
///
/// Retorna `true` si el ingreso está activo en el mes consultado.
bool ingresoVigenteEnMes({
  required DateTime fechaInicio,
  DateTime? fechaFin,
  required DateTime mesConsultado,
}) {
  // Normalizar todas las fechas al día 1 del mes para comparar solo mes/año
  final mesConsultadoNormalizado = DateTime(
    mesConsultado.year,
    mesConsultado.month,
    1,
  );
  final inicioNormalizado = DateTime(
    fechaInicio.year,
    fechaInicio.month,
    1,
  );

  // El ingreso debe haber iniciado antes o durante el mes consultado
  if (inicioNormalizado.isAfter(mesConsultadoNormalizado)) {
    return false;
  }

  // Si hay fecha fin, verificar que no haya terminado antes del mes consultado
  if (fechaFin != null) {
    final finNormalizado = DateTime(
      fechaFin.year,
      fechaFin.month,
      1,
    );
    if (finNormalizado.isBefore(mesConsultadoNormalizado)) {
      return false;
    }
  }

  return true;
}
