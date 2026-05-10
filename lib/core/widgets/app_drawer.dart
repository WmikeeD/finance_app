import 'package:flutter/material.dart';
import '../../features/cuentas/cuentas_screen.dart';
import '../../features/categorias/categorias_screen.dart';
import '../../features/personas/personas_screen.dart';
import '../../features/gastos_fijos/gastos_fijos_screen.dart';
import '../database/database.dart';
import '../navigation/app_tab_controller.dart';

class AppDrawer extends StatelessWidget {
  final AppDatabase database;
  final String currentRoute;

  const AppDrawer({
    super.key,
    required this.database,
    required this.currentRoute,
  });

  // Rutas que corresponden a un tab del AppShell
  static const Map<String, int> _tabRoutes = {
    '/home': 0,
    '/transacciones': 1,
    '/reportes': 2,
    '/proyeccion': 3,
    '/settings': 4,
  };

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(context),
          const SizedBox(height: 8),

          // ── Navegación principal (tabs) ──────────────────────
          _buildTabItem(context, icon: Icons.dashboard, title: 'Dashboard', route: '/home'),
          _buildTabItem(context, icon: Icons.swap_horiz, title: 'Transacciones', route: '/transacciones'),
          _buildTabItem(context, icon: Icons.bar_chart, title: 'Reportes', route: '/reportes'),
          _buildTabItem(context, icon: Icons.trending_up, title: 'Proyección', route: '/proyeccion'),

          const Divider(height: 16),

          // ── Gestión de datos (pantallas adicionales) ─────────
          _buildSectionTitle('Gestión de Datos'),
          _buildDataItem(context, icon: Icons.account_balance_wallet, title: 'Cuentas', route: '/cuentas',
              screen: CuentasScreen(database: database)),
          _buildDataItem(context, icon: Icons.category, title: 'Categorías', route: '/categorias',
              screen: CategoriasScreen(database: database)),
          _buildDataItem(context, icon: Icons.people, title: 'Personas', route: '/personas',
              screen: PersonasScreen(database: database)),
          _buildDataItem(context, icon: Icons.repeat, title: 'Gastos Fijos', route: '/gastos_fijos',
              screen: GastosFijosScreen(database: database)),

          const Divider(height: 16),

          // ── Configuración ────────────────────────────────────
          _buildSectionTitle('Configuración'),
          _buildTabItem(context, icon: Icons.settings, title: 'Ajustes', route: '/settings'),
          _buildDataItem(context, icon: Icons.help_outline, title: 'Ayuda', route: '/help',
              screen: const Placeholder()),
        ],
      ),
    );
  }

  /// Navega a un tab del AppShell (sin crear nueva ruta en el stack).
  Widget _buildTabItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
  }) {
    final isSelected = currentRoute == route;
    return _buildTile(
      context,
      icon: icon,
      title: title,
      isSelected: isSelected,
      onTap: () {
        Navigator.pop(context); // cierra el drawer
        final tabIdx = _tabRoutes[route];
        if (tabIdx != null) {
          AppTabController.goToTab(tabIdx);
          // Vuelve al root del navigator (el AppShell) si hay rutas encima
          Navigator.popUntil(context, (r) => r.isFirst);
        }
      },
    );
  }

  /// Navega a una pantalla de datos via Navigator.push (preserva el stack).
  Widget _buildDataItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    required Widget screen,
  }) {
    final isSelected = currentRoute == route;
    return _buildTile(
      context,
      icon: icon,
      title: title,
      isSelected: isSelected,
      onTap: () {
        Navigator.pop(context); // cierra el drawer
        if (!isSelected) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
        }
      },
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        selected: isSelected,
        selectedTileColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.60),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.account_balance_wallet,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Finance App',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Control de Finanzas Personales',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
