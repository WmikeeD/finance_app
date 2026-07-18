import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/database/database.dart';
import '../../core/navigation/app_tab_controller.dart';
import '../../core/utils/responsive.dart';
import '../../features/home/home_screen.dart';
import '../../features/transacciones/transacciones_screen.dart';
import '../../features/reportes/reportes_screen.dart';
import '../../features/proyeccion/proyeccion_screen.dart';
import '../../features/configuracion/configuracion_screen.dart';

class AppShell extends StatefulWidget {
  final AppDatabase database;

  const AppShell({super.key, required this.database});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final List<Widget> _screens;

  void _onTabChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(database: widget.database),
      TransaccionesScreen(database: widget.database),
      ReportesScreen(database: widget.database),
      ProyeccionScreen(database: widget.database),
      ConfiguracionScreen(database: widget.database),
    ];
    AppTabController.tabIndex.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    AppTabController.tabIndex.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        // Mobile: BottomNavigationBar
        if (deviceType == DeviceType.mobile) {
          return _buildMobileLayout();
        }

        // Tablet/Desktop: NavigationRail
        return _buildTabletDesktopLayout(deviceType);
      },
    );
  }

  /// Layout para dispositivos móviles (< 600dp)
  /// Usa BottomNavigationBar tradicional
  Widget _buildMobileLayout() {
    return Scaffold(
      body: IndexedStack(
        index: AppTabController.tabIndex.value,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: AppTabController.tabIndex.value,
        onDestinationSelected: AppTabController.goToTab,
        destinations: _getNavigationDestinations(),
      ),
    );
  }

  /// Layout para tablets y desktop (>= 600dp)
  /// Usa NavigationRail lateral
  Widget _buildTabletDesktopLayout(DeviceType deviceType) {
    final isDesktop = deviceType == DeviceType.desktop;

    return Scaffold(
      body: Row(
        children: [
          // NavigationRail lateral
          NavigationRail(
            selectedIndex: AppTabController.tabIndex.value,
            onDestinationSelected: AppTabController.goToTab,
            // Extended en desktop (> 840dp), colapsado en tablet (600-840dp)
            extended: isDesktop,
            // En tablet: mostrar labels solo para item seleccionado
            // En desktop: siempre mostrar (pero extended ya las muestra)
            labelType: isDesktop
                ? NavigationRailLabelType.none // extended ya muestra labels
                : NavigationRailLabelType.selected,
            destinations: _getNavigationRailDestinations(),
          ),

          // Divider vertical
          const VerticalDivider(thickness: 1, width: 1),

          // Contenido principal
          Expanded(
            child: IndexedStack(
              index: AppTabController.tabIndex.value,
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }

  /// Destinations para BottomNavigationBar (Mobile)
  List<NavigationDestination> _getNavigationDestinations() {
    return [
      NavigationDestination(
        icon: PhosphorIcon(PhosphorIconsRegular.house),
        selectedIcon: PhosphorIcon(PhosphorIconsFill.house),
        label: 'Inicio',
      ),
      NavigationDestination(
        icon: PhosphorIcon(PhosphorIconsRegular.arrowsLeftRight),
        selectedIcon: PhosphorIcon(PhosphorIconsFill.arrowsLeftRight),
        label: 'Transacciones',
      ),
      NavigationDestination(
        icon: PhosphorIcon(PhosphorIconsRegular.chartBar),
        selectedIcon: PhosphorIcon(PhosphorIconsFill.chartBar),
        label: 'Reportes',
      ),
      NavigationDestination(
        icon: PhosphorIcon(PhosphorIconsRegular.trendUp),
        selectedIcon: PhosphorIcon(PhosphorIconsFill.trendUp),
        label: 'Proyección',
      ),
      NavigationDestination(
        icon: PhosphorIcon(PhosphorIconsRegular.gear),
        selectedIcon: PhosphorIcon(PhosphorIconsFill.gear),
        label: 'Config',
      ),
    ];
  }

  /// Destinations para NavigationRail (Tablet/Desktop)
  List<NavigationRailDestination> _getNavigationRailDestinations() {
    return [
      NavigationRailDestination(
        icon: PhosphorIcon(PhosphorIconsRegular.house),
        selectedIcon: PhosphorIcon(PhosphorIconsFill.house),
        label: const Text('Inicio'),
      ),
      NavigationRailDestination(
        icon: PhosphorIcon(PhosphorIconsRegular.arrowsLeftRight),
        selectedIcon: PhosphorIcon(PhosphorIconsFill.arrowsLeftRight),
        label: const Text('Transacciones'),
      ),
      NavigationRailDestination(
        icon: PhosphorIcon(PhosphorIconsRegular.chartBar),
        selectedIcon: PhosphorIcon(PhosphorIconsFill.chartBar),
        label: const Text('Reportes'),
      ),
      NavigationRailDestination(
        icon: PhosphorIcon(PhosphorIconsRegular.trendUp),
        selectedIcon: PhosphorIcon(PhosphorIconsFill.trendUp),
        label: const Text('Proyección'),
      ),
      NavigationRailDestination(
        icon: PhosphorIcon(PhosphorIconsRegular.gear),
        selectedIcon: PhosphorIcon(PhosphorIconsFill.gear),
        label: const Text('Config'),
      ),
    ];
  }
}
