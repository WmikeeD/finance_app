import 'package:flutter/material.dart';

class AppTheme {
  // Color primario dinámico
  static Color _primaryColor = const Color(0xFF6C63FF);
  
  // Colores fijos
  static const Color secondaryColor = Color(0xFF4CAF50);
  static const Color incomeColor = Color(0xFF4CAF50);
  static const Color expenseColor = Color(0xFFFF5252);

  /// Actualizar el color primario desde un hex string
  static void setColorFromHex(String hexColor) {
    _primaryColor = Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
  }

  /// Obtener el color primario actual
  static Color get primaryColor => _primaryColor;
  
  /// Tema claro
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: _primaryColor,
      brightness: Brightness.light,
    );
  }
  
  /// Tema oscuro
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: _primaryColor,
      brightness: Brightness.dark,
    );
  }
}