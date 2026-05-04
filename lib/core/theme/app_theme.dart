import 'package:flutter/material.dart';

class AppTheme {
  static Color _primaryColor = const Color(0xFF6C63FF);

  static const Color incomeColor = Color(0xFF4CAF50);
  static const Color expenseColor = Color(0xFFFF5252);

  static void setColorFromHex(String hexColor) {
    _primaryColor = Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
  }

  static void setPrimaryColor(Color color) {
    _primaryColor = color;
  }

  static Color get primaryColor => _primaryColor;

  /// Calcula el color basado en el balance disponible respecto a min/max.
  ///
  /// Zonas:
  ///  balance < 0             → rojo oscuro (peligro)
  ///  0 … minimo              → rojo → naranja (alerta)
  ///  minimo … maximo×0.5     → naranja → verde (moderado)
  ///  maximo×0.5 … maximo     → verde → verde azulado (bueno)
  ///  balance >= maximo        → dorado (meta alcanzada)
  static Color calcularColorDinamico(
    double balance,
    double minimo,
    double maximo,
  ) {
    const rojoOscuro   = Color(0xFFC62828); // danger
    const rojo         = Color(0xFFEF5350);
    const naranja      = Color(0xFFFF9800);
    const verde        = Color(0xFF43A047);
    const teal         = Color(0xFF00897B);
    const dorado       = Color(0xFFFFB300); // celebratorio

    if (balance >= maximo) return dorado;

    if (balance < 0) return rojoOscuro;

    if (balance <= minimo) {
      // 0 … minimo → rojo oscuro → naranja
      final t = balance / minimo; // 0…1
      return Color.lerp(rojoOscuro, naranja, t)!;
    }

    final mitad = maximo * 0.5;

    if (balance <= mitad) {
      // minimo … mitad → naranja → verde
      final t = (balance - minimo) / (mitad - minimo);
      return Color.lerp(naranja, verde, t)!;
    }

    // mitad … maximo → verde → teal
    final t = (balance - mitad) / (maximo - mitad);
    return Color.lerp(verde, teal, t * 0.85)!; // 0.85 para no llegar a dorado aquí
  }

  /// Nombre descriptivo de la zona para mostrarlo en UI.
  static String nombreZonaDinamica(
      double balance, double minimo, double maximo) {
    if (balance < 0) return 'Balance negativo';
    if (balance <= minimo) return 'Precaución';
    if (balance <= maximo * 0.5) return 'Estable';
    if (balance < maximo) return 'Cómodo';
    return '¡Meta alcanzada!';
  }

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _primaryColor,
        brightness: Brightness.light,
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _primaryColor,
        brightness: Brightness.dark,
      );
}
