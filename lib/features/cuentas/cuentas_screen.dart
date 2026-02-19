import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/database.dart';
import '../../core/widgets/app_drawer.dart';

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
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final cuentas = snapshot.data ?? [];

          if (cuentas.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
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
        icon: const Icon(Icons.add),
        label: const Text('Nueva Cuenta'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay cuentas registradas',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comienza agregando tu primera cuenta',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddCuentaDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Agregar Cuenta'),
          ),
        ],
      ),
    );
  }

  Widget _buildCuentaCard(Cuenta cuenta) {
    IconData iconData;
    switch (cuenta.icono) {
      case 'credit_card':
        iconData = Icons.credit_card;
        break;
      case 'account_balance':
        iconData = Icons.account_balance;
        break;
      case 'payments':
        iconData = Icons.payments;
        break;
      default:
        iconData = Icons.account_balance_wallet;
    }

    Color cardColor = Color(int.parse(cuenta.color.replaceFirst('#', '0xFF')));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cardColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(iconData, color: cardColor),
        ),
        title: Text(
          cuenta.nombre,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          cuenta.tipo.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${cuenta.saldo.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cuenta.saldo >= 0 ? Colors.green : Colors.red,
              ),
            ),
            if (cuenta.tipo == 'credito' && cuenta.limiteCredito != null)
              Text(
                'Límite: \$${cuenta.limiteCredito!.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
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
                // Nombre de la cuenta
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la cuenta',
                    hintText: 'Ej: Cuenta Corriente',
                    prefixIcon: Icon(Icons.edit),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Tipo de cuenta
                DropdownButtonFormField<String>(
                  value: tipoCuenta,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de cuenta',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                    DropdownMenuItem(value: 'debito', child: Text('Débito / Cuenta Bancaria')),
                    DropdownMenuItem(value: 'credito', child: Text('Tarjeta de Crédito')),
                    DropdownMenuItem(value: 'ahorro', child: Text('Cuenta de Ahorro')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      tipoCuenta = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Saldo inicial
                TextField(
                  controller: saldoController,
                  decoration: const InputDecoration(
                    labelText: 'Saldo inicial',
                    hintText: '0',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                ),
                
                // Campos específicos para CRÉDITO
                if (tipoCuenta == 'credito') ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Configuración de Tarjeta de Crédito',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Límite de crédito
                  TextField(
                    controller: limiteController,
                    decoration: const InputDecoration(
                      labelText: 'Límite de crédito',
                      hintText: 'Ej: 500000',
                      prefixIcon: Icon(Icons.credit_score),
                      helperText: 'Máximo que puedes gastar',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Día de cierre
                  TextField(
                    controller: diaCierreController,
                    decoration: const InputDecoration(
                      labelText: 'Día de cierre',
                      hintText: 'Ej: 25',
                      prefixIcon: Icon(Icons.calendar_today),
                      helperText: 'Día del mes (1-31)',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Día de pago
                  TextField(
                    controller: diaPagoController,
                    decoration: const InputDecoration(
                      labelText: 'Día de pago',
                      hintText: 'Ej: 5',
                      prefixIcon: Icon(Icons.event),
                      helperText: 'Día del mes (1-31)',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
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
                // Validaciones
                if (nombreController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingresa un nombre para la cuenta')),
                  );
                  return;
                }

                final saldo = double.tryParse(saldoController.text) ?? 0.0;
                
                // Para crédito, el saldo es negativo (lo que debes)
                final saldoFinal = tipoCuenta == 'credito' ? -saldo.abs() : saldo;
                
                // Validar campos de crédito
                if (tipoCuenta == 'credito') {
                  final limite = double.tryParse(limiteController.text);
                  final diaCierre = int.tryParse(diaCierreController.text);
                  final diaPago = int.tryParse(diaPagoController.text);
                  
                  if (limite == null || limite <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingresa un límite de crédito válido')),
                    );
                    return;
                  }
                  
                  if (diaCierre == null || diaCierre < 1 || diaCierre > 31) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('El día de cierre debe estar entre 1 y 31')),
                    );
                    return;
                  }
                  
                  if (diaPago == null || diaPago < 1 || diaPago > 31) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('El día de pago debe estar entre 1 y 31')),
                    );
                    return;
                  }
                  
                  // Insertar cuenta de crédito con todos los campos
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
                } else {
                  // Insertar cuenta normal (efectivo, débito, ahorro)
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
                  _buildInfoRow('Límite de crédito', '\$${cuenta.limiteCredito!.toStringAsFixed(0)}'),
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () async {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirmar eliminación'),
                  content: Text('¿Estás seguro de eliminar "${cuenta.nombre}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
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
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}