import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Value;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';

class IngresosRecurrentesScreen extends StatefulWidget {
  final AppDatabase database;

  const IngresosRecurrentesScreen({super.key, required this.database});

  @override
  State<IngresosRecurrentesScreen> createState() =>
      _IngresosRecurrentesScreenState();
}

class _IngresosRecurrentesScreenState
    extends State<IngresosRecurrentesScreen> {
  bool _soloActivos = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingresos Recurrentes'),
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
      body: StreamBuilder<List<IngresoRecurrente>>(
        stream: _watchIngresos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final ingresos = snapshot.data ?? [];

          if (ingresos.isEmpty) {
            return AppEmptyState(
              icon: PhosphorIconsRegular.arrowDownLeft,
              title: 'No hay ingresos recurrentes',
              subtitle: 'Agrega ingresos que se repiten cada mes',
              buttonLabel: 'Nuevo Ingreso',
              onAction: () => _showFormDialog(),
            );
          }

          final totalActivos = ingresos
              .where((i) => i.activo)
              .fold(0.0, (sum, i) => sum + i.monto);

          return Column(
            children: [
              _buildResumenCard(totalActivos, ingresos),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: ingresos.length,
                  itemBuilder: (context, index) =>
                      _buildIngresoCard(ingresos[index]),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
        icon: PhosphorIcon(PhosphorIconsRegular.plus),
        label: const Text('Nuevo Ingreso'),
      ),
    );
  }

  Stream<List<IngresoRecurrente>> _watchIngresos() {
    var query = widget.database.select(widget.database.ingresosRecurrentes)
      ..where((i) => i.deletedAt.isNull());

    if (_soloActivos) {
      query = query..where((i) => i.activo.equals(true));
    }

    return query.watch();
  }

  Widget _buildResumenCard(double totalActivos, List<IngresoRecurrente> ingresos) {
    final totalCount = ingresos.where((i) => i.activo).length;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.incomeColor(context),
            AppTheme.incomeColor(context).withValues(alpha: 0.65),
          ],
        ),
        borderRadius: AppRadius.xlBR,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: AppRadius.mdBR,
            ),
            child: PhosphorIcon(
              PhosphorIconsRegular.arrowDownLeft,
              color: Colors.white,
              size: 28,
            ),
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

  Widget _buildIngresoCard(IngresoRecurrente ingreso) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: ingreso.activo
                ? AppTheme.incomeColor(context).withValues(alpha: 0.12)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: AppRadius.lgBR,
          ),
          child: PhosphorIcon(
            PhosphorIconsRegular.arrowDownLeft,
            color: ingreso.activo
                ? AppTheme.incomeColor(context)
                : Colors.grey,
            size: 22,
          ),
        ),
        title: Text(
          ingreso.descripcion,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: ingreso.activo ? null : Colors.grey,
            decoration: ingreso.activo ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          _formatearFrecuencia(ingreso.frecuencia, ingreso.diaMes),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.monedaConSimbolo(ingreso.monto),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: ingreso.activo
                        ? AppTheme.incomeColor(context)
                        : Colors.grey,
                  ),
                ),
                Text(
                  ingreso.activo ? 'activo' : 'inactivo',
                  style: TextStyle(
                    fontSize: 11,
                    color: ingreso.activo
                        ? AppColors.alertOk
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (action) => _handleAction(action, ingreso),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(ingreso.activo ? 'Desactivar' : 'Activar'),
                ),
                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Eliminar',
                    style: TextStyle(color: AppTheme.expenseColor(context)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatearFrecuencia(String frecuencia, int? diaMes) {
    switch (frecuencia) {
      case 'ultimo_dia_habil':
        return 'Último día hábil del mes';
      case 'primer_dia_habil':
        return 'Primer día hábil del mes';
      case 'dia_fijo':
        return diaMes != null ? 'Día $diaMes de cada mes' : 'Día fijo';
      case 'quincenal':
        return 'Quincenal (días 15 y fin de mes)';
      default:
        return frecuencia;
    }
  }

  void _handleAction(String action, IngresoRecurrente ingreso) async {
    switch (action) {
      case 'toggle':
        await _toggleActivo(ingreso);
      case 'edit':
        _showFormDialog(ingreso: ingreso);
      case 'delete':
        _confirmarEliminar(ingreso);
    }
  }

  Future<void> _toggleActivo(IngresoRecurrente ingreso) async {
    await (widget.database.update(widget.database.ingresosRecurrentes)
          ..where((i) => i.id.equals(ingreso.id)))
        .write(
      IngresosRecurrentesCompanion(
        activo: Value(!ingreso.activo),
        updatedAt: Value(DateTime.now()),
        sincronizado: const Value(false),
        ultimaModificacion: Value(DateTime.now()),
      ),
    );
  }

  void _confirmarEliminar(IngresoRecurrente ingreso) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar ingreso recurrente'),
        content: Text(
          '¿Eliminar "${ingreso.descripcion}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _eliminarIngreso(ingreso.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${ingreso.descripcion} eliminado')),
              );
            },
            child: Text(
              'Eliminar',
              style: TextStyle(color: AppTheme.expenseColor(context)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarIngreso(int id) async {
    await (widget.database.update(widget.database.ingresosRecurrentes)
          ..where((i) => i.id.equals(id)))
        .write(
      IngresosRecurrentesCompanion(
        deletedAt: Value(DateTime.now()),
        sincronizado: const Value(false),
        ultimaModificacion: Value(DateTime.now()),
      ),
    );
  }

  void _showFormDialog({IngresoRecurrente? ingreso}) {
    final isEditing = ingreso != null;
    final descripcionCtrl = TextEditingController(text: ingreso?.descripcion ?? '');
    final montoCtrl = TextEditingController(
      text: ingreso != null ? ingreso.monto.toStringAsFixed(0) : '',
    );
    int? cuentaId = ingreso?.cuentaId;
    String frecuencia = ingreso?.frecuencia ?? 'ultimo_dia_habil';
    final diaCtrl = TextEditingController(
      text: ingreso?.diaMes?.toString() ?? '',
    );
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
          child: SingleChildScrollView(
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
                    isEditing ? 'Editar Ingreso Recurrente' : 'Nuevo Ingreso Recurrente',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: descripcionCtrl,
                    decoration: InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Ej: Sueldo, Honorarios, Arriendo...',
                      prefixIcon: PhosphorIcon(PhosphorIconsRegular.tag),
                      border: const OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Ingresa una descripción' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: montoCtrl,
                    decoration: InputDecoration(
                      labelText: 'Monto mensual',
                      prefixIcon: PhosphorIcon(PhosphorIconsRegular.currencyDollar),
                      prefixText: '\$ ',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Ingresa un monto';
                      final parsed = double.tryParse(v.replaceAll('.', ''));
                      if (parsed == null || parsed <= 0) return 'Monto inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  StreamBuilder<List<Cuenta>>(
                    stream: (widget.database.select(widget.database.cuentas)
                          ..where((c) => c.activa.equals(true))
                          ..where((c) => c.tipo.isIn(['efectivo', 'debito'])))
                        .watch(),
                    builder: (_, snap) {
                      final cuentas = snap.data ?? [];
                      return DropdownButtonFormField<int?>(
                        key: ValueKey(cuentaId),
                        initialValue: cuentaId,
                        decoration: InputDecoration(
                          labelText: 'Cuenta destino (solo líquidas)',
                          prefixIcon: PhosphorIcon(PhosphorIconsRegular.wallet),
                          border: const OutlineInputBorder(),
                        ),
                        items: cuentas.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.nombre),
                        )).toList(),
                        validator: (v) => v == null ? 'Selecciona una cuenta' : null,
                        onChanged: (v) => setModalState(() => cuentaId = v),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey(frecuencia),
                    initialValue: frecuencia,
                    decoration: InputDecoration(
                      labelText: 'Frecuencia de cobro',
                      prefixIcon: PhosphorIcon(PhosphorIconsRegular.calendar),
                      border: const OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'ultimo_dia_habil',
                        child: Text('Último día hábil del mes'),
                      ),
                      DropdownMenuItem(
                        value: 'primer_dia_habil',
                        child: Text('Primer día hábil del mes'),
                      ),
                      DropdownMenuItem(
                        value: 'dia_fijo',
                        child: Text('Día fijo del mes'),
                      ),
                      DropdownMenuItem(
                        value: 'quincenal',
                        child: Text('Quincenal (15 y fin de mes)'),
                      ),
                    ],
                    onChanged: (v) => setModalState(() {
                      frecuencia = v!;
                      if (v != 'dia_fijo') {
                        diaCtrl.clear();
                      }
                    }),
                  ),
                  if (frecuencia == 'dia_fijo') ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: diaCtrl,
                      decoration: InputDecoration(
                        labelText: 'Día del mes',
                        hintText: '1 - 31',
                        prefixIcon: PhosphorIcon(PhosphorIconsRegular.calendarBlank),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (frecuencia == 'dia_fijo') {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa el día del mes';
                          }
                          final d = int.tryParse(v);
                          if (d == null || d < 1 || d > 31) {
                            return 'Día entre 1 y 31';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _guardar(
                        formKey: formKey,
                        isEditing: isEditing,
                        ingreso: ingreso,
                        descripcionCtrl: descripcionCtrl,
                        montoCtrl: montoCtrl,
                        cuentaId: cuentaId,
                        frecuencia: frecuencia,
                        diaCtrl: diaCtrl,
                      ),
                      child: Text(isEditing ? 'Guardar cambios' : 'Agregar ingreso'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _guardar({
    required GlobalKey<FormState> formKey,
    required bool isEditing,
    required IngresoRecurrente? ingreso,
    required TextEditingController descripcionCtrl,
    required TextEditingController montoCtrl,
    required int? cuentaId,
    required String frecuencia,
    required TextEditingController diaCtrl,
  }) async {
    if (!formKey.currentState!.validate()) return;

    final monto = double.parse(montoCtrl.text.replaceAll('.', ''));
    final dia = (frecuencia == 'dia_fijo' && diaCtrl.text.trim().isNotEmpty)
        ? int.parse(diaCtrl.text.trim())
        : null;

    final companion = IngresosRecurrentesCompanion(
      id: isEditing ? Value(ingreso!.id) : const Value.absent(),
      descripcion: Value(descripcionCtrl.text.trim()),
      monto: Value(monto),
      cuentaId: Value(cuentaId!),
      frecuencia: Value(frecuencia),
      diaMes: Value(dia),
      activo: isEditing ? Value(ingreso!.activo) : const Value(true),
      fechaInicio: isEditing ? Value(ingreso!.fechaInicio) : Value(DateTime.now()),
      fechaFin: const Value(null),
      updatedAt: Value(DateTime.now()),
      sincronizado: const Value(false),
      ultimaModificacion: Value(DateTime.now()),
    );

    if (isEditing) {
      await (widget.database.update(widget.database.ingresosRecurrentes)
            ..where((i) => i.id.equals(ingreso!.id)))
          .write(companion);
    } else {
      await widget.database.into(widget.database.ingresosRecurrentes).insert(companion);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'Ingreso actualizado' : 'Ingreso recurrente agregado',
          ),
        ),
      );
    }
  }
}
