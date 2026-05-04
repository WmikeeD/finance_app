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
  String _filtroTipo = 'todos';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Categorías'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _filtroTipo,
            onSelected: (v) => setState(() => _filtroTipo = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'todos', child: Text('Todas')),
              PopupMenuItem(value: 'ingreso', child: Text('Ingresos')),
              PopupMenuItem(value: 'egreso', child: Text('Egresos')),
            ],
          ),
        ],
      ),
      drawer: AppDrawer(
        database: widget.database,
        currentRoute: '/categorias',
      ),
      body: StreamBuilder<List<Categoria>>(
        stream: widget.database.select(widget.database.categorias).watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final todas = snapshot.data ?? [];
          final filtradas = _filtroTipo == 'todos'
              ? todas
              : todas.where((c) => c.tipo == _filtroTipo).toList();

          if (todas.isEmpty) return _buildEmptyState();

          // Separar padres e hijos
          final padres = filtradas
              .where((c) => c.categoriaPadreId == null)
              .toList();
          final hijosPor = <int, List<Categoria>>{};
          for (final c in todas.where((c) => c.categoriaPadreId != null)) {
            hijosPor.putIfAbsent(c.categoriaPadreId!, () => []).add(c);
          }

          if (padres.isEmpty) {
            return Center(
              child: Text(
                'Sin categorías de tipo "$_filtroTipo"',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: padres.length,
            itemBuilder: (_, i) =>
                _buildPadreCard(padres[i], hijosPor[padres[i].id] ?? []),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Categoría'),
      ),
    );
  }

  // ── Tarjeta de categoría padre con hijos expansibles ─────────────────────

  Widget _buildPadreCard(Categoria padre, List<Categoria> hijos) {
    final color = _colorDeHex(padre.color);
    final icon = _iconData(padre.icono);
    final esPadreExpandible = hijos.isNotEmpty;

    final header = ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(padre.nombre,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Row(
        children: [
          _buildTipoBadge(padre.tipo),
          if (hijos.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text('${hijos.length} subcategorías',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (a) => _handleAccion(a, padre),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'sub', child: Text('Agregar subcategoría')),
          const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
        ],
      ),
    );

    if (!esPadreExpandible) {
      return Card(margin: const EdgeInsets.only(bottom: 10), child: header);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(padre.nombre,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            _buildTipoBadge(padre.tipo),
            const SizedBox(width: 8),
            Text('${hijos.length} subcategorías',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              onSelected: (a) => _handleAccion(a, padre),
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'sub', child: Text('Agregar subcategoría')),
                const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          ...hijos.map((h) => _buildHijoTile(h, color)),
          ListTile(
            leading: const SizedBox(width: 32),
            title: Text(
              '+ Agregar subcategoría',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary, fontSize: 13),
            ),
            onTap: () => _showFormDialog(padreId: padre.id, tipo: padre.tipo),
          ),
        ],
      ),
    );
  }

  Widget _buildHijoTile(Categoria hijo, Color colorPadre) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 64, right: 16),
      leading: const Icon(Icons.subdirectory_arrow_right,
          size: 16, color: Colors.grey),
      title: Text(hijo.nombre, style: const TextStyle(fontSize: 14)),
      subtitle: _buildTipoBadge(hijo.tipo),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
        onPressed: () => _confirmarEliminar(hijo),
      ),
    );
  }

  Widget _buildTipoBadge(String tipo) {
    final esIngreso = tipo == 'ingreso';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: esIngreso ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        esIngreso ? 'INGRESO' : 'EGRESO',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: esIngreso ? Colors.green[700] : Colors.red[700],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No hay categorías registradas',
              style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showFormDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Agregar Categoría'),
          ),
        ],
      ),
    );
  }

  // ── Acciones ──────────────────────────────────────────────────────────────

  void _handleAccion(String accion, Categoria categoria) {
    switch (accion) {
      case 'sub':
        _showFormDialog(padreId: categoria.id, tipo: categoria.tipo);
      case 'delete':
        _confirmarEliminar(categoria);
    }
  }

  void _confirmarEliminar(Categoria categoria) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text(
            '¿Eliminar "${categoria.nombre}"? Las transacciones asociadas quedarán sin categoría.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await (widget.database.delete(widget.database.categorias)
                    ..where((c) => c.id.equals(categoria.id)))
                  .go();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${categoria.nombre} eliminada')),
                );
              }
            },
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Formulario crear/agregar subcategoría ─────────────────────────────────

  void _showFormDialog({int? padreId, String? tipo}) {
    final nombreCtrl = TextEditingController();
    String tipoSeleccionado = tipo ?? 'egreso';
    int? padreSeleccionado = padreId;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 16,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  padreId != null ? 'Nueva Subcategoría' : 'Nueva Categoría',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej: Supermercado, Taxi...',
                    prefixIcon: Icon(Icons.label_outline),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa un nombre'
                      : null,
                ),
                const SizedBox(height: 14),
                // Tipo — solo visible si no viene prefijado
                if (padreId == null)
                  DropdownButtonFormField<String>(
                    value: tipoSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      prefixIcon: Icon(Icons.swap_vert),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'egreso', child: Text('Egreso')),
                      DropdownMenuItem(
                          value: 'ingreso', child: Text('Ingreso')),
                    ],
                    onChanged: (v) =>
                        setModal(() => tipoSeleccionado = v!),
                  ),
                // Categoría padre — visible solo si no viene prefijada
                if (padreId == null) ...[
                  const SizedBox(height: 14),
                  StreamBuilder<List<Categoria>>(
                    stream: (widget.database.select(widget.database.categorias)
                          ..where((c) => c.categoriaPadreId.isNull()))
                        .watch(),
                    builder: (_, snap) {
                      final padres = (snap.data ?? [])
                          .where((c) => c.tipo == tipoSeleccionado)
                          .toList();
                      if (padres.isEmpty) return const SizedBox.shrink();
                      return DropdownButtonFormField<int?>(
                        value: padreSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Categoría padre (opcional)',
                          prefixIcon:
                              Icon(Icons.account_tree_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Sin padre (categoría principal)')),
                          ...padres.map((p) => DropdownMenuItem(
                              value: p.id, child: Text(p.nombre))),
                        ],
                        onChanged: (v) =>
                            setModal(() => padreSeleccionado = v),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      await widget.database
                          .into(widget.database.categorias)
                          .insert(
                            CategoriasCompanion.insert(
                              nombre: nombreCtrl.text.trim(),
                              tipo: tipoSeleccionado,
                              categoriaPadreId: Value(padreSeleccionado),
                            ),
                          );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  '${padreId != null ? 'Subcategoría' : 'Categoría'} creada')),
                        );
                      }
                    },
                    child: Text(padreId != null
                        ? 'Crear subcategoría'
                        : 'Crear categoría'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Utilidades ────────────────────────────────────────────────────────────

  Color _colorDeHex(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  IconData _iconData(String? name) {
    switch (name) {
      case 'restaurant':       return Icons.restaurant;
      case 'directions_car':   return Icons.directions_car;
      case 'home':             return Icons.home;
      case 'medical_services': return Icons.medical_services;
      case 'sports_esports':   return Icons.sports_esports;
      case 'school':           return Icons.school;
      case 'receipt':          return Icons.receipt;
      case 'people':           return Icons.people;
      case 'attach_money':     return Icons.attach_money;
      case 'work':             return Icons.work;
      case 'trending_up':      return Icons.trending_up;
      case 'account_balance_wallet': return Icons.account_balance_wallet;
      default:                 return Icons.category;
    }
  }
}
