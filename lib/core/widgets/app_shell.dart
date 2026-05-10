import 'package:flutter/material.dart';
import '../../core/database/database.dart';
import '../../core/navigation/app_tab_controller.dart';
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
    return Scaffold(
      body: IndexedStack(
        index: AppTabController.tabIndex.value,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: AppTabController.tabIndex.value,
        onDestinationSelected: AppTabController.goToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz),
            label: 'Transacciones',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reportes',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up),
            label: 'Proyección',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Config',
          ),
        ],
      ),
    );
  }
}
