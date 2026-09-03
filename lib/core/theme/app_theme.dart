// finance_app — app_theme.dart (Material Design 3)
// Coloca este archivo en: lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
//  TOKENS DE COLOR SEMÁNTICOS
// ─────────────────────────────────────────────
abstract final class AppColors {
  // Brand / Primary
  static const primary = Color(0xFF00C896);
  static const primaryDark = Color(0xFF009672);
  static const onPrimary = Color(0xFF003828);
  static const primaryContainer = Color(0xFF003D30);
  static const onPrimaryContainer = Color(0xFF6FFFD8);

  // Financieros (semánticos)
  static const income = Color(0xFF4CAF82);
  static const expense = Color(0xFFFF6B6B);
  static const credit = Color(0xFF9D7EFF);
  static const savings = Color(0xFF64B5F6);
  static const warning = Color(0xFFFFB547);

  // Alertas
  static const alertDanger = Color(0xFFFF6B6B);
  static const alertWarning = Color(0xFFFFB547);
  static const alertCaution = Color(0xFFFFD54F);
  static const alertOk = Color(0xFF4CAF82);
  static const alertCelebrate = Color(0xFF00C896);

  // ──── Dark Scheme (Fondo Negro Puro) ────
  static const darkSurface = Color(0xFF000000); // Negro puro
  static const darkSurfaceContainer = Color(0xFF0D0D0D); // Gris muy oscuro para cards
  static const darkSurfaceContainerHigh = Color(0xFF1A1A1A); // Gris oscuro para elevación
  static const darkSurfaceContainerHighest = Color(0xFF262626);
  static const darkOnSurface = Color(0xFFFFFFFF); // Blanco puro para texto
  static const darkOnSurfaceVariant = Color(0xFF9CA3AF); // Gris claro para texto secundario
  static const darkOutline = Color(0xFF404040);
  static const darkOutlineVariant = Color(0xFF1F1F1F);

  // ──── Light Scheme ────
  static const lightSurface = Color(0xFFF5FAF8);
  static const lightSurfaceContainer = Color(0xFFFFFFFF);
  static const lightSurfaceContainerHigh = Color(0xFFEDF4F1);
  static const lightOnSurface = Color(0xFF0D1F1A);
  static const lightOnSurfaceVariant = Color(0xFF3F5F58);
  static const lightOutline = Color(0xFF6F9089);
  static const lightOutlineVariant = Color(0xFFBDD8D1);
}

// ─────────────────────────────────────────────
//  TOKENS DE ESPACIADO
// ─────────────────────────────────────────────
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

// ─────────────────────────────────────────────
//  TOKENS DE RADIO
// ─────────────────────────────────────────────
abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28; // M3 large component shape

  // Helpers BorderRadius
  static const smBR = BorderRadius.all(Radius.circular(sm));
  static const mdBR = BorderRadius.all(Radius.circular(md));
  static const lgBR = BorderRadius.all(Radius.circular(lg));
  static const xlBR = BorderRadius.all(Radius.circular(xl));
  static const xxlBR = BorderRadius.all(Radius.circular(xxl));
}

// ─────────────────────────────────────────────
//  THEME DATA
// ─────────────────────────────────────────────
abstract final class AppTheme {
  // ── Fuente recomendada: DM Sans ──
  // pubspec.yaml → google_fonts: ^6.x
  // import 'package:google_fonts/google_fonts.dart';
  // Reemplaza TextTheme con: GoogleFonts.dmSansTextTheme(...)

  static ThemeData dark({Color? primarySeedColor}) {
    final seedColor = primarySeedColor ?? AppColors.primary;

    // Generar scheme base desde el seedColor
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    // Customizar con nuestros colores semánticos y superficies
    final scheme = baseScheme.copyWith(
      // Conservar colores semánticos financieros
      secondary: AppColors.credit,
      tertiary: AppColors.income,
      error: AppColors.expense,
      // Superficies personalizadas (negro puro)
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkOnSurface,
      onSurfaceVariant: AppColors.darkOnSurfaceVariant,
      surfaceContainerLowest: const Color(0xFF000000),
      surfaceContainerLow: const Color(0xFF0A0A0A),
      surfaceContainer: AppColors.darkSurfaceContainer,
      surfaceContainerHigh: AppColors.darkSurfaceContainerHigh,
      surfaceContainerHighest: AppColors.darkSurfaceContainerHighest,
      outline: AppColors.darkOutline,
      outlineVariant: AppColors.darkOutlineVariant,
      shadow: Colors.black,
      scrim: Colors.black54,
    );

    return _buildTheme(scheme);
  }

  static ThemeData light({Color? primarySeedColor}) {
    final seedColor = primarySeedColor ?? AppColors.primaryDark;

    // Generar scheme base desde el seedColor
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    // Customizar con nuestros colores semánticos y superficies
    final scheme = baseScheme.copyWith(
      // Conservar colores semánticos financieros
      secondary: const Color(0xFF6B4ECC),
      tertiary: const Color(0xFF2E7D5A),
      error: const Color(0xFFD32F2F),
      // Superficies personalizadas
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightOnSurface,
      onSurfaceVariant: AppColors.lightOnSurfaceVariant,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF0F8F5),
      surfaceContainer: AppColors.lightSurfaceContainer,
      surfaceContainerHigh: AppColors.lightSurfaceContainerHigh,
      surfaceContainerHighest: const Color(0xFFE5F0EC),
      outline: AppColors.lightOutline,
      outlineVariant: AppColors.lightOutlineVariant,
      shadow: Colors.black12,
      scrim: Colors.black26,
    );

    return _buildTheme(scheme);
  }

  // ─────────────────────────────────────────
  //  Constructor compartido
  // ─────────────────────────────────────────
  static ThemeData _buildTheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;

    // Escala tipográfica M3 con Inter (Google Fonts)
    final baseTextTheme = GoogleFonts.interTextTheme();
    final textTheme = baseTextTheme.copyWith(
      // Display — pantallas vacías, splash
      displayLarge: GoogleFonts.inter(
          fontSize: 57, fontWeight: FontWeight.w300, letterSpacing: -0.25),
      displayMedium: GoogleFonts.inter(fontSize: 45, fontWeight: FontWeight.w300),
      displaySmall: GoogleFonts.inter(
          fontSize: 36, fontWeight: FontWeight.w300, letterSpacing: -1),
      // Headline — balances principales
      headlineLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w400),
      headlineMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w400),
      headlineSmall: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600),
      // Title — cabeceras de sección, tarjetas
      titleLarge: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      titleSmall: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      // Body — texto descriptivo
      bodyLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.15),
      bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
      bodySmall: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4),
      // Label — metadatos, badges, chips
      labelLarge: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
      labelMedium: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      labelSmall: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      scaffoldBackgroundColor: scheme.surface,

      // ── AppBar ──────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainer,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: scheme.primary,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
        actionsIconTheme: IconThemeData(color: scheme.onSurface),
        centerTitle: false,
        shape: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),

      // ── NavigationBar ───────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.2 : 0.15),
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.primary, size: 22);
          }
          return IconThemeData(color: scheme.onSurfaceVariant, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          const base = TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
          );
          if (states.contains(WidgetState.selected)) {
            return base.copyWith(color: scheme.primary);
          }
          return base.copyWith(color: scheme.onSurfaceVariant);
        }),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        height: 68,
      ),

      // ── Cards ────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          side: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm / 2,
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // ── Botones ──────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),

      // ── Chips ────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primary.withValues(alpha: 0.15),
        labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        side: BorderSide(color: scheme.outline, width: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        showCheckmark: true,
        checkmarkColor: scheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),

      // ── Inputs ───────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: scheme.primary),
      ),

      // ── Divider ──────────────────────────────
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.5,
        space: 0,
      ),

      // ── BottomSheet ──────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      // ── Dialog ───────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        titleTextStyle:
            textTheme.headlineSmall?.copyWith(color: scheme.onSurface),
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),

      // ── ListTile ─────────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm,
        ),
        titleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle:
            textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        iconColor: scheme.onSurfaceVariant,
      ),

      // ── Switch ───────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return scheme.outline;
        }),
      ),

      // ── SnackBar ─────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.onSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      // ── Badge ────────────────────────────────
      badgeTheme: BadgeThemeData(
        backgroundColor: AppColors.expense,
        textColor: Colors.white,
        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),

      // ── ProgressIndicator ────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),

      // ── Drawer ───────────────────────────────
      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surfaceContainer,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.horizontal(right: Radius.circular(AppRadius.xxl)),
        ),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  // ─────────────────────────────────────────
  //  Colores semánticos (requieren context para light/dark)
  // ─────────────────────────────────────────
  static Color incomeColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.income
          : const Color(0xFF2E7D5A);

  static Color expenseColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.expense
          : const Color(0xFFC62828);

  static Color creditColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.credit
          : const Color(0xFF6A1B9A);

  static Color savingsColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.savings
          : const Color(0xFF1565C0);

  // ─────────────────────────────────────────
  //  Utilidades de color dinámico
  // ─────────────────────────────────────────
  static Color calcularColorDinamico(
    double balance,
    double minimo,
    double maximo,
  ) {
    const rojoOscuro = Color(0xFFC62828);
    const naranja = Color(0xFFFF9800);
    const verde = Color(0xFF43A047);
    const teal = Color(0xFF00897B);
    const dorado = Color(0xFFFFB300);

    if (balance >= maximo) return dorado;
    if (balance < 0) return rojoOscuro;

    if (balance <= minimo) {
      final t = balance / minimo;
      return Color.lerp(rojoOscuro, naranja, t)!;
    }

    final mitad = maximo * 0.5;

    if (balance <= mitad) {
      final t = (balance - minimo) / (mitad - minimo);
      return Color.lerp(naranja, verde, t)!;
    }

    final t = (balance - mitad) / (maximo - mitad);
    return Color.lerp(verde, teal, t * 0.85)!;
  }

  static String nombreZonaDinamica(
      double balance, double minimo, double maximo) {
    if (balance < 0) return 'Balance negativo';
    if (balance <= minimo) return 'Precaución';
    if (balance <= maximo * 0.5) return 'Estable';
    if (balance < maximo) return 'Cómodo';
    return '¡Meta alcanzada!';
  }
}
