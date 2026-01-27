import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
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
    String tipoCuenta = 'debito';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nueva Cuenta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la cuenta',
                  hintText: 'Ej: Cuenta Corriente',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: tipoCuenta,
                decoration: const InputDecoration(
                  labelText: 'Tipo de cuenta',
                ),
                items: const [
                  DropdownMenuItem(value: 'debito', child: Text('Débito')),
                  DropdownMenuItem(value: 'credito', child: Text('Crédito')),
                  DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                  DropdownMenuItem(value: 'ahorro', child: Text('Ahorro')),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    tipoCuenta = value!;
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
                  await widget.database.into(widget.database.cuentas).insert(
                    CuentasCompanion.insert(
                      nombre: nombreController.text,
                      tipo: tipoCuenta,
                    ),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cuenta creada exitosamente')),
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

  void _showEditCuentaDialog(Cuenta cuenta) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cuenta.nombre),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tipo: ${cuenta.tipo}'),
            Text('Saldo: \$${cuenta.saldo}'),
            if (cuenta.tipo == 'credito' && cuenta.limiteCredito != null)
              Text('Límite: \$${cuenta.limiteCredito}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () async {
              await (widget.database.delete(widget.database.cuentas)
                    ..where((c) => c.id.equals(cuenta.id)))
                  .go();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cuenta eliminada')),
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