import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' as drift;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';

class CuentasScreen extends StatefulWidget {
  final AppDatabase database;

  const CuentasScreen({super.key, required this.database});

  @override
  State<CuentasScreen> createState() => _CuentasScreenState();
}

class _CuentasScreenState extends State<CuentasScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Cuentas'),
      ),
      drawer: AppDrawer(
        database: widget.database,
        currentRoute: '/cuentas',
      ),
      body: StreamBuilder<List<Cuenta>>(
        stream: widget.database.select(widget.database.cuentas).watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return AppErrorState(error: snapshot.error);
          }

          final cuentas = snapshot.data ?? [];

          if (cuentas.isEmpty) {
            return AppEmptyState(
              icon: PhosphorIconsRegular.wallet,
              title: 'No hay cuentas registradas',
              subtitle: 'Comienza agregando tu primera cuenta',
              buttonLabel: 'Agregar Cuenta',
              onAction: () => _showAddCuentaDialog(),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.base),
            itemCount: cuentas.length,
            itemBuilder: (context, index) {
              final cuenta = cuentas[index];
              return _buildCuentaCard(cuenta);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCuentaDialog(),
        icon: PhosphorIcon(PhosphorIconsRegular.plus),
        label: const Text('Nueva Cuenta'),
      ),
    );
  }

  Widget _buildCuentaCard(Cuenta cuenta) {
    final theme = Theme.of(context);
    IconData iconData;
    switch (cuenta.icono) {
      case 'credit_card':
        iconData = PhosphorIconsRegular.creditCard;
        break;
      case 'account_balance':
        iconData = PhosphorIconsRegular.bank;
        break;
      case 'payments':
        iconData = PhosphorIconsRegular.money;
        break;
      default:
        iconData = PhosphorIconsRegular.wallet;
    }

    final Color cardColor =
        Color(int.parse(cuenta.color.replaceFirst('#', '0xFF')));

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cardColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: PhosphorIcon(iconData, color: cardColor, size: 24),
        ),
        title: Text(
          cuenta.nombre,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          cuenta.tipo.toUpperCase(),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${cuenta.saldo.toStringAsFixed(0)}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: cuenta.saldo >= 0
                    ? AppTheme.incomeColor(context)
                    : AppTheme.expenseColor(context),
              ),
            ),
            if (cuenta.tipo == 'credito' && cuenta.limiteCredito != null)
              Text(
                'Límite: \$${cuenta.limiteCredito!.toStringAsFixed(0)}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
          ],
        ),
        onTap: () => _showEditCuentaDialog(cuenta),
      ),
    );
  }

  void _showAddCuentaDialog() {
    final nombreController = TextEditingController();
    final saldoController = TextEditingController(text: '0');
    final limiteController = TextEditingController();
    final diaCierreController = TextEditingController();
    final diaPagoController = TextEditingController();
    final metaController = TextEditingController();

    String tipoCuenta = 'debito';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nueva Cuenta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre de la cuenta',
                    hintText: 'Ej: Cuenta Corriente',
                    prefixIcon: PhosphorIcon(PhosphorIconsRegular.pencilSimple),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                DropdownButtonFormField<String>(
                  key: ValueKey(tipoCuenta),
                  initialValue: tipoCuenta,
                  decoration: InputDecoration(
                    labelText: 'Tipo de cuenta',
                    prefixIcon: PhosphorIcon(PhosphorIconsRegular.squaresFour),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'efectivo', child: Text('Efectivo')),
                    DropdownMenuItem(
                        value: 'debito',
                        child: Text('Débito / Cuenta Bancaria')),
                    DropdownMenuItem(
                        value: 'credito', child: Text('Tarjeta de Crédito')),
                    DropdownMenuItem(
                        value: 'ahorro', child: Text('Cuenta de Ahorro')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      tipoCuenta = value!;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.base),
                TextField(
                  controller: saldoController,
                  decoration: InputDecoration(
                    labelText: 'Saldo inicial',
                    hintText: '0',
                    prefixIcon: PhosphorIcon(PhosphorIconsRegular.currencyDollar),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                ),
                if (tipoCuenta == 'credito') ...[
                  const SizedBox(height: AppSpacing.base),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Configuración de Tarjeta de Crédito',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  TextField(
                    controller: limiteController,
                    decoration: InputDecoration(
                      labelText: 'Límite de crédito',
                      hintText: 'Ej: 500000',
                      prefixIcon: PhosphorIcon(PhosphorIconsRegular.creditCard),
                      helperText: 'Máximo que puedes gastar',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: AppSpacing.base),
                  TextField(
                    controller: diaCierreController,
                    decoration: InputDecoration(
                      labelText: 'Día de cierre',
                      hintText: 'Ej: 25',
                      prefixIcon: PhosphorIcon(PhosphorIconsRegular.calendarBlank),
                      helperText: 'Día del mes (1-31)',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.base),
                  TextField(
                    controller: diaPagoController,
                    decoration: InputDecoration(
                      labelText: 'Día de pago',
                      hintText: 'Ej: 5',
                      prefixIcon: PhosphorIcon(PhosphorIconsRegular.calendar),
                      helperText: 'Día del mes (1-31)',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                  ),
                ],
                if (tipoCuenta == 'ahorro') ...[
                  const SizedBox(height: AppSpacing.base),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Configuración de Ahorro',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  TextField(
                    controller: metaController,
                    decoration: InputDecoration(
                      labelText: 'Meta de ahorro (opcional)',
                      hintText: 'Ej: 500000',
                      prefixIcon: PhosphorIcon(PhosphorIconsRegular.flag),
                      helperText: 'Monto que deseas ahorrar',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nombreController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Ingresa un nombre para la cuenta')),
                  );
                  return;
                }

                final saldo = double.tryParse(saldoController.text) ?? 0.0;
                final saldoFinal =
                    tipoCuenta == 'credito' ? -saldo.abs() : saldo;

                if (tipoCuenta == 'credito') {
                  final limite = double.tryParse(limiteController.text);
                  final diaCierre = int.tryParse(diaCierreController.text);
                  final diaPago = int.tryParse(diaPagoController.text);

                  if (limite == null || limite <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Ingresa un límite de crédito válido')),
                    );
                    return;
                  }

                  if (diaCierre == null || diaCierre < 1 || diaCierre > 31) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('El día de cierre debe estar entre 1 y 31')),
                    );
                    return;
                  }

                  if (diaPago == null || diaPago < 1 || diaPago > 31) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('El día de pago debe estar entre 1 y 31')),
                    );
                    return;
                  }

                  await widget.database.into(widget.database.cuentas).insert(
                        CuentasCompanion.insert(
                          nombre: nombreController.text,
                          tipo: tipoCuenta,
                          saldo: drift.Value(saldoFinal),
                          limiteCredito: drift.Value(limite),
                          diaCierre: drift.Value(diaCierre),
                          diaPago: drift.Value(diaPago),
                        ),
                      );
                } else if (tipoCuenta == 'ahorro') {
                  final meta = double.tryParse(metaController.text);

                  await widget.database.into(widget.database.cuentas).insert(
                        CuentasCompanion.insert(
                          nombre: nombreController.text,
                          tipo: tipoCuenta,
                          saldo: drift.Value(saldoFinal),
                          meta: drift.Value(meta),
                        ),
                      );
                } else {
                  await widget.database.into(widget.database.cuentas).insert(
                        CuentasCompanion.insert(
                          nombre: nombreController.text,
                          tipo: tipoCuenta,
                          saldo: drift.Value(saldoFinal),
                        ),
                      );
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cuenta creada exitosamente')),
                  );
                }
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCuentaDialog(Cuenta cuenta) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cuenta.nombre),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Tipo', cuenta.tipo.toUpperCase()),
              _buildInfoRow('Saldo', '\$${cuenta.saldo.toStringAsFixed(0)}'),
              if (cuenta.tipo == 'credito') ...[
                const Divider(height: 24),
                if (cuenta.limiteCredito != null)
                  _buildInfoRow('Límite de crédito',
                      '\$${cuenta.limiteCredito!.toStringAsFixed(0)}'),
                if (cuenta.limiteCredito != null)
                  _buildInfoRow(
                    'Disponible',
                    '\$${(cuenta.limiteCredito! + cuenta.saldo).toStringAsFixed(0)}',
                  ),
                if (cuenta.diaCierre != null)
                  _buildInfoRow('Día de cierre', cuenta.diaCierre.toString()),
                if (cuenta.diaPago != null)
                  _buildInfoRow('Día de pago', cuenta.diaPago.toString()),
              ],
              if (cuenta.tipo == 'ahorro') ...[
                const Divider(height: 24),
                if (cuenta.meta != null)
                  _buildInfoRow('Meta', '\$${cuenta.meta!.toStringAsFixed(0)}'),
                if (cuenta.meta != null)
                  _buildInfoRow(
                    'Progreso',
                    '${((cuenta.saldo / cuenta.meta!) * 100).toStringAsFixed(1)}%',
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          if (cuenta.tipo == 'ahorro')
            TextButton(
              onPressed: () => _showEditMetaDialog(cuenta),
              child: const Text('Editar Meta'),
            ),
          TextButton(
            onPressed: () async {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirmar eliminación'),
                  content:
                      Text('¿Estás seguro de eliminar "${cuenta.nombre}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Eliminar',
                        style: TextStyle(color: AppColors.alertDanger),
                      ),
                    ),
                  ],
                ),
              );

              if (confirmar == true && context.mounted) {
                await (widget.database.delete(widget.database.cuentas)
                      ..where((c) => c.id.equals(cuenta.id)))
                    .go();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cuenta eliminada')),
                  );
                }
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

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showEditMetaDialog(Cuenta cuenta) {
    final metaController = TextEditingController(
      text: cuenta.meta != null ? cuenta.meta!.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Meta de Ahorro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Saldo actual: \$${cuenta.saldo.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: AppSpacing.base),
            TextField(
              controller: metaController,
              decoration: InputDecoration(
                labelText: 'Meta de ahorro',
                hintText: 'Ej: 500000',
                prefixIcon: PhosphorIcon(PhosphorIconsRegular.flag),
                prefixText: '\$ ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              autofocus: true,
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
              final meta = double.tryParse(metaController.text);

              await (widget.database.update(widget.database.cuentas)
                    ..where((c) => c.id.equals(cuenta.id)))
                  .write(
                CuentasCompanion(
                  meta: drift.Value(meta),
                ),
              );

              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Meta actualizada')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
