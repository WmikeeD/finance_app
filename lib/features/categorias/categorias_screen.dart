import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';

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

          if (todas.isEmpty) {
            return AppEmptyState(
              icon: PhosphorIconsRegular.squaresFour,
              title: 'No hay categorías registradas',
              buttonLabel: 'Agregar Categoría',
              onAction: () => _showFormDialog(),
            );
          }

          final padres =
              filtradas.where((c) => c.categoriaPadreId == null).toList();
          final hijosPor = <int, List<Categoria>>{};
          for (final c in todas.where((c) => c.categoriaPadreId != null)) {
            hijosPor.putIfAbsent(c.categoriaPadreId!, () => []).add(c);
          }

          if (padres.isEmpty) {
            return Center(
              child: Text(
                'Sin categorías de tipo "$_filtroTipo"',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.base),
            itemCount: padres.length,
            itemBuilder: (_, i) =>
                _buildPadreCard(padres[i], hijosPor[padres[i].id] ?? []),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
        icon: PhosphorIcon(PhosphorIconsRegular.plus),
        label: const Text('Nueva Categoría'),
      ),
    );
  }

  Widget _buildPadreCard(Categoria padre, List<Categoria> hijos) {
    final color = _colorDeHex(padre.color);
    final icon = _iconData(padre.icono);
    final esPadreExpandible = hijos.isNotEmpty;

    final header = ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(padre.nombre,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Row(
        children: [
          _buildTipoBadge(padre.tipo),
          if (hijos.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${hijos.length} subcategorías',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (a) => _handleAccion(a, padre),
        itemBuilder: (_) => [
          const PopupMenuItem(
              value: 'sub', child: Text('Agregar subcategoría')),
          const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
        ],
      ),
    );

    if (!esPadreExpandible) {
      return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
          child: header);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(padre.nombre,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            _buildTipoBadge(padre.tipo),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${hijos.length} subcategorías',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
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
          ...hijos.map((h) => _buildHijoTile(h)),
          ListTile(
            leading: const SizedBox(width: 32),
            title: Text(
              '+ Agregar subcategoría',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            onTap: () => _showFormDialog(padreId: padre.id, tipo: padre.tipo),
          ),
        ],
      ),
    );
  }

  Widget _buildHijoTile(Categoria hijo) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 64, right: AppSpacing.base),
      leading: PhosphorIcon(PhosphorIconsRegular.arrowElbowDownRight,
          size: 16, color: theme.colorScheme.outline),
      title: Text(hijo.nombre, style: theme.textTheme.bodyMedium),
      subtitle: _buildTipoBadge(hijo.tipo),
      trailing: IconButton(
        icon: PhosphorIcon(PhosphorIconsRegular.trash,
            size: 18, color: AppColors.alertDanger),
        onPressed: () => _confirmarEliminar(hijo),
      ),
    );
  }

  Widget _buildTipoBadge(String tipo) {
    final esIngreso = tipo == 'ingreso';
    final color = esIngreso
        ? AppTheme.incomeColor(context)
        : AppTheme.expenseColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm - 2, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        esIngreso ? 'INGRESO' : 'EGRESO',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 9,
            ),
      ),
    );
  }

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
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppColors.alertDanger),
            ),
          ),
        ],
      ),
    );
  }

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
        builder: (ctx, setModal) {
          final scheme = Theme.of(ctx).colorScheme;
          final textTheme = Theme.of(ctx).textTheme;
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.base,
              top: AppSpacing.base,
              left: AppSpacing.base,
              right: AppSpacing.base,
            ),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl)),
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
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text(
                    padreId != null ? 'Nueva Subcategoría' : 'Nueva Categoría',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nombre',
                      hintText: 'Ej: Supermercado, Taxi...',
                      prefixIcon: PhosphorIcon(PhosphorIconsRegular.tag),
                      border: const OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa un nombre'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (padreId == null)
                    DropdownButtonFormField<String>(
                      key: ValueKey(tipoSeleccionado),
                      initialValue: tipoSeleccionado,
                      decoration: InputDecoration(
                        labelText: 'Tipo',
                        prefixIcon: PhosphorIcon(PhosphorIconsRegular.arrowsDownUp),
                        border: const OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'egreso', child: Text('Egreso')),
                        DropdownMenuItem(
                            value: 'ingreso', child: Text('Ingreso')),
                      ],
                      onChanged: (v) => setModal(() => tipoSeleccionado = v!),
                    ),
                  if (padreId == null) ...[
                    const SizedBox(height: AppSpacing.md),
                    StreamBuilder<List<Categoria>>(
                      stream:
                          (widget.database.select(widget.database.categorias)
                                ..where((c) => c.categoriaPadreId.isNull()))
                              .watch(),
                      builder: (_, snap) {
                        final padres = (snap.data ?? [])
                            .where((c) => c.tipo == tipoSeleccionado)
                            .toList();
                        if (padres.isEmpty) return const SizedBox.shrink();
                        return DropdownButtonFormField<int?>(
                          key: ValueKey(padreSeleccionado),
                          initialValue: padreSeleccionado,
                          decoration: InputDecoration(
                            labelText: 'Categoría padre (opcional)',
                            prefixIcon: PhosphorIcon(PhosphorIconsRegular.tree),
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: null,
                                child: Text('Sin padre (categoría principal)')),
                            ...padres.map((p) => DropdownMenuItem(
                                value: p.id, child: Text(p.nombre))),
                          ],
                          onChanged: (v) =>
                              setModal(() => padreSeleccionado = v),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
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
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${padreId != null ? 'Subcategoría' : 'Categoría'} creada'),
                            ),
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
          );
        },
      ),
    );
  }

  Color _colorDeHex(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  IconData _iconData(String? name) {
    switch (name) {
      case 'restaurant':
        return PhosphorIconsRegular.forkKnife;
      case 'directions_car':
        return PhosphorIconsRegular.car;
      case 'home':
        return PhosphorIconsRegular.house;
      case 'medical_services':
        return PhosphorIconsRegular.firstAid;
      case 'sports_esports':
        return PhosphorIconsRegular.gameController;
      case 'school':
        return PhosphorIconsRegular.graduationCap;
      case 'receipt':
        return PhosphorIconsRegular.receipt;
      case 'people':
        return PhosphorIconsRegular.users;
      case 'attach_money':
        return PhosphorIconsRegular.currencyDollar;
      case 'work':
        return PhosphorIconsRegular.briefcase;
      case 'trending_up':
        return PhosphorIconsRegular.trendUp;
      case 'account_balance_wallet':
        return PhosphorIconsRegular.wallet;
      default:
        return PhosphorIconsRegular.squaresFour;
    }
  }
}
