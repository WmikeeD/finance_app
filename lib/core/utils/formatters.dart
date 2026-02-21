import 'package:intl/intl.dart';

/// Utilidades de formateo para toda la aplicación
class Formatters {
  // Instancias reutilizables para mejor performance
  static final _moneda = NumberFormat('#,##0', 'es_CL');
  static final _monedaConSimbolo = NumberFormat('\$#,##0', 'es_CL');
  static final _fecha = DateFormat('dd/MM/yyyy');
  static final _fechaHora = DateFormat('dd/MM/yyyy HH:mm');
  static final _mesAno = DateFormat('MMMM yyyy', 'es_CL');

  /// Formatea número como moneda chilena sin símbolo
  /// Ejemplo: 9000 -> 9.000
  static String moneda(double monto) {
    return _moneda.format(monto);
  }
  
  /// Formatea número como moneda chilena con símbolo $
  /// Ejemplo: 9000 -> $9.000
  static String monedaConSimbolo(double monto) {
    return _monedaConSimbolo.format(monto);
  }
  
  /// Formatea fecha corta
  /// Ejemplo: 20/02/2026
  static String fecha(DateTime fecha) {
    return _fecha.format(fecha);
  }
  
  /// Formatea fecha con hora
  /// Ejemplo: 20/02/2026 14:30
  static String fechaHora(DateTime fecha) {
    return _fechaHora.format(fecha);
  }
  
  /// Formatea mes y año en español
  /// Ejemplo: febrero 2026
  static String mesAno(DateTime fecha) {
    return _mesAno.format(fecha);
  }
}