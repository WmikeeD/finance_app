import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';

class GastosFijosScreen extends StatefulWidget {
  final AppDatabase database;

  const GastosFijosScreen({super.key, required this.database});

  @override
  State<GastosFijosScreen> createState() => _GastosFijosScreenState();
}

class _GastosFijosScreenState extends State<GastosFijosScreen> {
  bool _soloActivos = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gastos Fijos'),
        actions: [
          Row(
            children: [
              const Text('Solo activos', style: TextStyle(fontSize: 13)),
              Switch(
                value: _soloActivos,
                onChanged: (v) => setState(() => _soloActivos = v),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<GastoFijo>>(
        stream: widget.database.watchGastosFijos(
          soloActivos: _soloActivos ? true : null,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final gastos = snapshot.data ?? [];

          if (gastos.isEmpty) {
            return AppEmptyState(
              icon: Icons.repeat_outlined,
              title: 'No hay gastos fijos',
              subtitle: 'Agrega gastos que se repiten cada mes',
              buttonLabel: 'Nuevo Gasto Fijo',
              onAction: () => _showFormDialog(),
            );
          }

          final totalActivos = gastos
              .where((g) => g.activo)
              .fold(0.0, (sum, g) => sum + g.monto);

          return Column(
            children: [
              _buildResumenCard(totalActivos, gastos),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: gastos.length,
                  itemBuilder: (context, index) =>
                      _buildGastoCard(gastos[index]),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Gasto Fijo'),
      ),
    );
  }

  Widget _buildResumenCard(double totalActivos, List<GastoFijo> gastos) {
    final totalCount = gastos.where((g) => g.activo).length;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.65),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.repeat, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total mensual activo',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  Formatters.monedaConSimbolo(totalActivos),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$totalCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'activos',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGastoCard(GastoFijo gasto) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: gasto.activo
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: AppRadius.lgBR,
          ),
          child: Icon(
            Icons.repeat,
            color: gasto.activo
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
            size: 22,
          ),
        ),
        title: Text(
          gasto.nombre,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: gasto.activo ? null : Colors.grey,
            decoration: gasto.activo ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: gasto.diaVencimiento != null
            ? Text(
                'Vence el día ${gasto.diaVencimiento} de cada mes',
                style: const TextStyle(fontSize: 12),
              )
            : const Text(
                'Sin día de vencimiento fijo',
                style: TextStyle(fontSize: 12),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.monedaConSimbolo(gasto.monto),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: gasto.activo
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                ),
                Text(
                  gasto.activo ? 'activo' : 'inactivo',
                  style: TextStyle(
                    fontSize: 11,
                    color: gasto.activo
                        ? AppColors.alertOk
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (action) => _handleAction(action, gasto),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(gasto.activo ? 'Desactivar' : 'Activar'),
                ),
                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(String action, GastoFijo gasto) {
    switch (action) {
      case 'toggle':
        widget.database.actualizarGastoFijo(
          GastosFijosCompanion(
            id: Value(gasto.id),
            activo: Value(!gasto.activo),
          ),
        );
      case 'edit':
        _showFormDialog(gasto: gasto);
      case 'delete':
        _confirmarEliminar(gasto);
    }
  }

  void _confirmarEliminar(GastoFijo gasto) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar gasto fijo'),
        content: Text('¿Eliminar "${gasto.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.database.eliminarGastoFijo(gasto.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${gasto.nombre} eliminado')),
              );
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showFormDialog({GastoFijo? gasto}) {
    final isEditing = gasto != null;
    final nombreCtrl = TextEditingController(text: gasto?.nombre ?? '');
    final montoCtrl = TextEditingController(
      text: gasto != null ? gasto.monto.toStringAsFixed(0) : '',
    );
    final diaCtrl = TextEditingController(
      text: gasto?.diaVencimiento?.toString() ?? '',
    );
    int? categoriaId = gasto?.categoriaId;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 16,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isEditing ? 'Editar Gasto Fijo' : 'Nuevo Gasto Fijo',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del gasto',
                    hintText: 'Ej: Arriendo, Netflix, Gym...',
                    prefixIcon: Icon(Icons.label_outline),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: montoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Monto mensual',
                    prefixIcon: Icon(Icons.attach_money),
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingresa un monto';
                    final parsed = double.tryParse(v.replaceAll('.', ''));
                    if (parsed == null || parsed <= 0) return 'Monto inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: diaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Día de vencimiento (opcional)',
                    hintText: '1 - 31',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final d = int.tryParse(v);
                    if (d == null || d < 1 || d > 31) return 'Día entre 1 y 31';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                StreamBuilder<List<Categoria>>(
                  stream: (widget.database.select(widget.database.categorias)
                        ..where((c) => c.tipo.equals('egreso')))
                      .watch(),
                  builder: (_, snap) {
                    final cats = snap.data ?? [];
                    return DropdownButtonFormField<int?>(
                      key: ValueKey(categoriaId),
                      initialValue: categoriaId,
                      decoration: const InputDecoration(
                        labelText: 'Categoría (opcional)',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Sin categoría'),
                        ),
                        ...cats.map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.nombre),
                          ),
                        ),
                      ],
                      onChanged: (v) => setModalState(() => categoriaId = v),
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _guardar(
                      formKey: formKey,
                      isEditing: isEditing,
                      gasto: gasto,
                      nombreCtrl: nombreCtrl,
                      montoCtrl: montoCtrl,
                      diaCtrl: diaCtrl,
                      categoriaId: categoriaId,
                    ),
                    child: Text(isEditing ? 'Guardar cambios' : 'Agregar gasto fijo'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _guardar({
    required GlobalKey<FormState> formKey,
    required bool isEditing,
    required GastoFijo? gasto,
    required TextEditingController nombreCtrl,
    required TextEditingController montoCtrl,
    required TextEditingController diaCtrl,
    required int? categoriaId,
  }) {
    if (!formKey.currentState!.validate()) return;

    final monto = double.parse(montoCtrl.text.replaceAll('.', ''));
    final dia = diaCtrl.text.trim().isEmpty
        ? null
        : int.parse(diaCtrl.text.trim());

    if (isEditing) {
      widget.database.actualizarGastoFijo(
        GastosFijosCompanion(
          id: Value(gasto!.id),
          nombre: Value(nombreCtrl.text.trim()),
          monto: Value(monto),
          diaVencimiento: Value(dia),
          categoriaId: Value(categoriaId),
        ),
      );
    } else {
      widget.database.insertarGastoFijo(
        GastosFijosCompanion.insert(
          nombre: nombreCtrl.text.trim(),
          monto: monto,
          diaVencimiento: Value(dia),
          categoriaId: Value(categoriaId),
        ),
      );
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditing ? 'Gasto actualizado' : 'Gasto fijo agregado',
        ),
      ),
    );
  }
}
