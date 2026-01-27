import 'package:flutter/material.dart';
import '../../features/home/home_screen.dart';
import '../../features/cuentas/cuentas_screen.dart';
import '../../features/categorias/categorias_screen.dart';
import '../../features/personas/personas_screen.dart';
import '../../features/transacciones/transacciones_screen.dart';
import '../database/database.dart';

class AppDrawer extends StatelessWidget {
  final AppDatabase database;
  final String currentRoute;
  
  const AppDrawer({
    super.key,
    required this.database,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(context),
          const SizedBox(height: 8),
          _buildMenuItem(
            context: context,
            icon: Icons.dashboard,
            title: 'Dashboard',
            route: '/home',
            screen: HomeScreen(database: database),
          ),
          const Divider(height: 1),
          _buildSectionTitle('Gestión de Datos'),
          _buildMenuItem(
            context: context,
            icon: Icons.account_balance_wallet,
            title: 'Cuentas',
            route: '/cuentas',
            screen: CuentasScreen(database: database),
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.category,
            title: 'Categorías',
            route: '/categorias',
            screen: CategoriasScreen(database: database),
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.people,
            title: 'Personas',
            route: '/personas',
            screen: PersonasScreen(database: database),
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.receipt_long,
            title: 'Transacciones',
            route: '/transacciones',
            screen: TransaccionesScreen(database: database),
          ),
          const Divider(height: 1),
          _buildSectionTitle('Configuración'),
          _buildMenuItem(
            context: context,
            icon: Icons.settings,
            title: 'Ajustes',
            route: '/settings',
            screen: const Placeholder(), // TODO: Implementar más adelante
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.help_outline,
            title: 'Ayuda',
            route: '/help',
            screen: const Placeholder(), // TODO: Implementar más adelante
          ),
        ],
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
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
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
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String route,
    required Widget screen,
  }) {
    final isSelected = currentRoute == route;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected 
              ? Theme.of(context).colorScheme.primary 
              : Colors.grey[600],
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected 
                ? Theme.of(context).colorScheme.primary 
                : Colors.grey[800],
          ),
        ),
        selected: isSelected,
        selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onTap: () {
          if (!isSelected) {
            Navigator.pop(context); // Cerrar drawer
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => screen),
            );
          } else {
            Navigator.pop(context); // Solo cerrar drawer si ya estamos en esa pantalla
          }
        },
      ),
    );
  }
}