import 'package:flutter/material.dart';

/// Breakpoints según Material Design 3
/// https://m3.material.io/foundations/layout/applying-layout/window-size-classes
class Breakpoints {
  /// Compact: < 600dp (Smartphones en portrait)
  static const double mobile = 600;

  /// Medium: 600-840dp (Tablets pequeñas, phones en landscape)
  static const double tablet = 840;

  /// Expanded: > 840dp (Tablets grandes, desktops)
  // No hay límite superior, se considera desktop
}

/// Tipos de dispositivo basados en ancho de pantalla
enum DeviceType { mobile, tablet, desktop }

/// Helper para diseño responsivo y adaptativo
class ResponsiveHelper {
  /// Obtiene el tipo de dispositivo según el ancho de pantalla actual
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < Breakpoints.mobile) return DeviceType.mobile;
    if (width < Breakpoints.tablet) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  /// Verifica si el dispositivo es móvil (< 600dp)
  static bool isMobile(BuildContext context) =>
      getDeviceType(context) == DeviceType.mobile;

  /// Verifica si el dispositivo es tablet (600-840dp)
  static bool isTablet(BuildContext context) =>
      getDeviceType(context) == DeviceType.tablet;

  /// Verifica si el dispositivo es desktop (> 840dp)
  static bool isDesktop(BuildContext context) =>
      getDeviceType(context) == DeviceType.desktop;

  /// Verifica si el dispositivo es tablet o desktop (>= 600dp)
  static bool isTabletOrDesktop(BuildContext context) =>
      !isMobile(context);

  /// Obtiene el crossAxisCount para GridView según el tipo de dispositivo
  ///
  /// Ejemplo:
  /// ```dart
  /// GridView.count(
  ///   crossAxisCount: ResponsiveHelper.getGridCrossAxisCount(
  ///     context,
  ///     mobile: 2,
  ///     tablet: 3,
  ///     desktop: 4,
  ///   ),
  /// )
  /// ```
  static int getGridCrossAxisCount(
    BuildContext context, {
    int mobile = 2,
    int tablet = 3,
    int desktop = 4,
  }) {
    final type = getDeviceType(context);
    switch (type) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet;
      case DeviceType.desktop:
        return desktop;
    }
  }

  /// Obtiene padding horizontal según dispositivo
  /// Mobile: 16dp, Tablet: 32dp, Desktop: 48dp
  static double getHorizontalPadding(BuildContext context) {
    final type = getDeviceType(context);
    switch (type) {
      case DeviceType.mobile:
        return 16;
      case DeviceType.tablet:
        return 32;
      case DeviceType.desktop:
        return 48;
    }
  }

  /// Obtiene altura para gráficos según dispositivo
  /// Mobile: 200px, Tablet: 300px, Desktop: 400px
  static double getChartHeight(BuildContext context) {
    final type = getDeviceType(context);
    switch (type) {
      case DeviceType.mobile:
        return 200;
      case DeviceType.tablet:
        return 300;
      case DeviceType.desktop:
        return 400;
    }
  }

  /// Obtiene el ancho máximo para contenido centrado (modales, formularios, etc.)
  /// Mobile: sin límite (fullwidth), Tablet/Desktop: 600dp
  ///
  /// Ejemplo:
  /// ```dart
  /// Container(
  ///   constraints: BoxConstraints(
  ///     maxWidth: ResponsiveHelper.getContentMaxWidth(context),
  ///   ),
  ///   child: MyForm(),
  /// )
  /// ```
  static double getContentMaxWidth(BuildContext context) {
    return isMobile(context) ? double.infinity : 600;
  }

  /// Obtiene el ancho máximo para listas en pantallas grandes
  /// Mobile: sin límite, Tablet/Desktop: 800dp
  static double getListMaxWidth(BuildContext context) {
    return isMobile(context) ? double.infinity : 800;
  }

  /// Envuelve un modal/dialog con ancho máximo responsivo
  ///
  /// Uso en showModalBottomSheet:
  /// ```dart
  /// showModalBottomSheet(
  ///   context: context,
  ///   builder: (_) => ResponsiveHelper.wrapModal(
  ///     context: context,
  ///     child: CuentasScreen(database: database),
  ///   ),
  /// )
  /// ```
  static Widget wrapModal({
    required BuildContext context,
    required Widget child,
    double? maxWidth,
  }) {
    if (isMobile(context)) {
      return child;
    }

    // En tablet/desktop, centrar y limitar ancho
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? 600,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: child,
      ),
    );
  }

  /// Obtiene el valor responsivo según el tipo de dispositivo
  ///
  /// Ejemplo:
  /// ```dart
  /// final fontSize = ResponsiveHelper.getValue(
  ///   context,
  ///   mobile: 14.0,
  ///   tablet: 16.0,
  ///   desktop: 18.0,
  /// );
  /// ```
  static T getValue<T>({
    required BuildContext context,
    required T mobile,
    required T tablet,
    required T desktop,
  }) {
    final type = getDeviceType(context);
    switch (type) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet;
      case DeviceType.desktop:
        return desktop;
    }
  }
}

/// Widget helper para construcción responsiva
///
/// Ejemplo:
/// ```dart
/// ResponsiveBuilder(
///   builder: (context, deviceType) {
///     if (deviceType == DeviceType.mobile) {
///       return MobileLayout();
///     } else {
///       return DesktopLayout();
///     }
///   },
/// )
/// ```
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return builder(context, ResponsiveHelper.getDeviceType(context));
  }
}

/// Extension para acceder rápidamente a propiedades responsivas
extension ResponsiveContext on BuildContext {
  DeviceType get deviceType => ResponsiveHelper.getDeviceType(this);
  bool get isMobile => ResponsiveHelper.isMobile(this);
  bool get isTablet => ResponsiveHelper.isTablet(this);
  bool get isDesktop => ResponsiveHelper.isDesktop(this);
  bool get isTabletOrDesktop => ResponsiveHelper.isTabletOrDesktop(this);
}
