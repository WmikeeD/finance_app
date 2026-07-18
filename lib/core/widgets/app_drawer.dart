import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../features/cuentas/cuentas_screen.dart';
import '../../features/categorias/categorias_screen.dart';
import '../../features/personas/personas_screen.dart';
import '../../features/gastos_fijos/gastos_fijos_screen.dart';
import '../database/database.dart';
import '../navigation/app_tab_controller.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

class AppDrawer extends StatelessWidget {
  final AppDatabase database;
  final String currentRoute;

  const AppDrawer({
    super.key,
    required this.database,
    required this.currentRoute,
  });

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
          const SizedBox(height: AppSpacing.sm),
          _buildTabItem(context,
              icon: PhosphorIconsRegular.house,
              title: 'Dashboard',
              route: '/home'),
          _buildTabItem(context,
              icon: PhosphorIconsRegular.arrowsLeftRight,
              title: 'Transacciones',
              route: '/transacciones'),
          _buildTabItem(context,
              icon: PhosphorIconsRegular.chartBar,
              title: 'Reportes',
              route: '/reportes'),
          _buildTabItem(context,
              icon: PhosphorIconsRegular.trendUp,
              title: 'Proyección',
              route: '/proyeccion'),
          const Divider(height: 16),
          _buildSectionTitle(context, 'Gestión de Datos'),
          _buildDataItem(context,
              icon: PhosphorIconsRegular.wallet,
              title: 'Cuentas',
              route: '/cuentas',
              screen: CuentasScreen(database: database)),
          _buildDataItem(context,
              icon: PhosphorIconsRegular.squaresFour,
              title: 'Categorías',
              route: '/categorias',
              screen: CategoriasScreen(database: database)),
          _buildDataItem(context,
              icon: PhosphorIconsRegular.users,
              title: 'Personas',
              route: '/personas',
              screen: PersonasScreen(database: database)),
          _buildDataItem(context,
              icon: PhosphorIconsRegular.repeat,
              title: 'Gastos Fijos',
              route: '/gastos_fijos',
              screen: GastosFijosScreen(database: database)),
          const Divider(height: 16),
          _buildSectionTitle(context, 'Configuración'),
          _buildTabItem(context,
              icon: PhosphorIconsRegular.gear, title: 'Ajustes', route: '/settings'),
          _buildDataItem(context,
              icon: PhosphorIconsRegular.question,
              title: 'Ayuda',
              route: '/help',
              screen: const Placeholder()),
        ],
      ),
    );
  }

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
        Navigator.pop(context);
        final tabIdx = _tabRoutes[route];
        if (tabIdx != null) {
          AppTabController.goToTab(tabIdx);
          Navigator.popUntil(context, (r) => r.isFirst);
        }
      },
    );
  }

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
        Navigator.pop(context);
        if (!isSelected) {
          // Usar modal fullscreen para mantener visible el bottomNavigationBar
          // En tablets/desktop, limitar ancho a 600dp
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => ResponsiveHelper.wrapModal(
              context: context,
              child: screen,
            ),
          );
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
    final scheme = Theme.of(context).colorScheme;
    final color = isSelected ? scheme.primary : scheme.onSurfaceVariant;

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      child: ListTile(
        leading: PhosphorIcon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? scheme.primary : scheme.onSurface,
          ),
        ),
        selected: isSelected,
        selectedTileColor: scheme.primary.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            scheme.primary.withValues(alpha: 0.60),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: PhosphorIcon(
              PhosphorIconsRegular.wallet,
              size: 40,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Finance App',
            style: textTheme.headlineSmall?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Control de Finanzas Personales',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xs),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
