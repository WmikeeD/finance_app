import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import '../../core/database/database.dart';
import '../../core/widgets/app_drawer.dart';

class CategoriasScreen extends StatefulWidget {
  final AppDatabase database;
  
  const CategoriasScreen({super.key, required this.database});

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  String _filtroTipo = 'todos'; // 'todos', 'ingreso', 'egreso'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Categorías'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _filtroTipo,
            onSelected: (value) {
              setState(() {
                _filtroTipo = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'todos', child: Text('Todas')),
              const PopupMenuItem(value: 'ingreso', child: Text('Ingresos')),
              const PopupMenuItem(value: 'egreso', child: Text('Egresos')),
            ],
          ),
        ],
      ),
      drawer: AppDrawer(
        database: widget.database,
        currentRoute: '/categorias',
      ),
      body: StreamBuilder<List<Categoria>>(
        stream: _getCategoriasStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final categorias = snapshot.data ?? [];

          if (categorias.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categorias.length,
            itemBuilder: (context, index) {
              final categoria = categorias[index];
              return _buildCategoriaCard(categoria);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoriaDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Categoría'),
      ),
    );
  }

  Stream<List<Categoria>> _getCategoriasStream() {
    if (_filtroTipo == 'todos') {
      return widget.database.select(widget.database.categorias).watch();
    } else {
      return (widget.database.select(widget.database.categorias)
            ..where((c) => c.tipo.equals(_filtroTipo)))
          .watch();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay categorías registradas',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddCategoriaDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Agregar Categoría'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriaCard(Categoria categoria) {
    IconData iconData = _getIconData(categoria.icono);
    Color categoryColor = Color(int.parse(categoria.color.replaceFirst('#', '0xFF')));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(iconData, color: categoryColor),
        ),
        title: Text(
          categoria.nombre,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: categoria.tipo == 'ingreso' ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                categoria.tipo == 'ingreso' ? 'INGRESO' : 'EGRESO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: categoria.tipo == 'ingreso' ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
            if (categoria.categoriaPadreId != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.subdirectory_arrow_right, size: 12, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'Subcategoría',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showEditCategoriaDialog(categoria),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car;
      case 'home':
        return Icons.home;
      case 'medical_services':
        return Icons.medical_services;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'school':
        return Icons.school;
      case 'receipt':
        return Icons.receipt;
      case 'people':
        return Icons.people;
      case 'attach_money':
        return Icons.attach_money;
      case 'work':
        return Icons.work;
      case 'trending_up':
        return Icons.trending_up;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      default:
        return Icons.category;
    }
  }

  void _showAddCategoriaDialog() {
    final nombreController = TextEditingController();
    String tipoCategoria = 'egreso';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nueva Categoría'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la categoría',
                  hintText: 'Ej: Supermercado',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: tipoCategoria,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                ),
                items: const [
                  DropdownMenuItem(value: 'ingreso', child: Text('Ingreso')),
                  DropdownMenuItem(value: 'egreso', child: Text('Egreso')),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    tipoCategoria = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nombreController.text.isNotEmpty) {
                  await widget.database.into(widget.database.categorias).insert(
                    CategoriasCompanion.insert(
                      nombre: nombreController.text,
                      tipo: tipoCategoria,
                    ),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Categoría creada exitosamente')),
                    );
                  }
                }
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoriaDialog(Categoria categoria) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(categoria.nombre),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tipo: ${categoria.tipo}'),
            Text('Color: ${categoria.color}'),
            if (categoria.categoriaPadreId != null)
              const Text('Es una subcategoría'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () async {
              await (widget.database.delete(widget.database.categorias)
                    ..where((c) => c.id.equals(categoria.id)))
                  .go();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Categoría eliminada')),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}