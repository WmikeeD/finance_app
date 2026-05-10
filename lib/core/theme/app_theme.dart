import 'package:flutter/material.dart';

abstract class AppSpacing {
  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 12.0;
  static const double base = 16.0;
  static const double lg   = 20.0;
  static const double xl   = 24.0;
  static const double xxl  = 32.0;
}

abstract class AppRadius {
  static const double sm  = 4.0;
  static const double md  = 8.0;
  static const double lg  = 12.0;
  static const double xl  = 16.0;
  static const double xxl = 20.0;

  static BorderRadius get smBR  => BorderRadius.circular(sm);
  static BorderRadius get mdBR  => BorderRadius.circular(md);
  static BorderRadius get lgBR  => BorderRadius.circular(lg);
  static BorderRadius get xlBR  => BorderRadius.circular(xl);
  static BorderRadius get xxlBR => BorderRadius.circular(xxl);
}

class AppTheme {
  static Color _primaryColor = const Color(0xFF6C63FF);

  // Colores semánticos financieros
  static const Color incomeColor  = Color(0xFF2E7D32); // verde oscuro WCAG AA
  static const Color expenseColor = Color(0xFFC62828); // rojo oscuro WCAG AA
  static const Color savingsColor = Color(0xFF1565C0); // azul profundo
  static const Color creditColor  = Color(0xFF6A1B9A); // púrpura

  // Semáforo de alertas
  static const Color alertDanger    = Color(0xFFB71C1C);
  static const Color alertWarning   = Color(0xFFE65100);
  static const Color alertCaution   = Color(0xFFF9A825);
  static const Color alertOk        = Color(0xFF388E3C);
  static const Color alertCelebrate = Color(0xFFFFB300);

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
    const rojoOscuro = Color(0xFFC62828); // danger
    const naranja    = Color(0xFFFF9800);
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

  static const TextTheme _textTheme = TextTheme(
    titleLarge:   TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    titleMedium:  TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    labelLarge:   TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    labelMedium:  TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    labelSmall:   TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
    displaySmall: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    bodyLarge:    TextStyle(fontSize: 14),
    bodyMedium:   TextStyle(fontSize: 13),
    bodySmall:    TextStyle(fontSize: 12),
  );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _primaryColor,
        brightness: Brightness.light,
        textTheme: _textTheme,
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _primaryColor,
        brightness: Brightness.dark,
        textTheme: _textTheme,
      );
}
