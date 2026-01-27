import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../core/database/database.dart';
import '../../core/widgets/app_drawer.dart';
import '../cuentas/cuentas_screen.dart';

class TransaccionesScreen extends StatefulWidget {
  final AppDatabase database;
  
  const TransaccionesScreen({super.key, required this.database});

  @override
  State<TransaccionesScreen> createState() => _TransaccionesScreenState();
}

class _TransaccionesScreenState extends State<TransaccionesScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transacciones'),
      ),
      drawer: AppDrawer(
        database: widget.database,
        currentRoute: '/transacciones',
      ),
      body: StreamBuilder<List<Transaccion>>(
        stream: (widget.database.select(widget.database.transacciones)
              ..orderBy([(t) => OrderingTerm.desc(t.fecha)]))
            .watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final transacciones = snapshot.data ?? [];

          if (transacciones.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transacciones.length,
            itemBuilder: (context, index) {
              final transaccion = transacciones[index];
              return _buildTransaccionCard(transaccion);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransaccionDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Transacción'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay transacciones registradas',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comienza registrando tu primera transacción',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddTransaccionDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Agregar Transacción'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransaccionCard(Transaccion transaccion) {
    final isIngreso = transaccion.tipo == 'ingreso';
    final color = isIngreso ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isIngreso ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
          ),
        ),
        title: Text(
          transaccion.descripcion,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _dateFormat.format(transaccion.fecha),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (transaccion.formaPago == 'credito')
              Row(
                children: [
                  Icon(Icons.credit_card, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${transaccion.cantidadCuotas} cuotas',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            if (transaccion.esPrestamo)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PRÉSTAMO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ),
          ],
        ),
        trailing: Text(
          '${isIngreso ? '+' : '-'}\$${transaccion.montoTotal.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        onTap: () => _showTransaccionDetails(transaccion),
      ),
    );
  }

  void _showAddTransaccionDialog() async {
    // Obtener cuentas y categorías disponibles
    final cuentas = await widget.database.select(widget.database.cuentas).get();
    final categorias = await widget.database.select(widget.database.categorias).get();

    if (!mounted) return;

    if (cuentas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Primero debes crear al menos una cuenta'),
          action: SnackBarAction(
            label: 'Ir a Cuentas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CuentasScreen(database: widget.database),
                ),
              );
            },
          ),
        ),
      );
      return;
    }

    if (categorias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero debes crear al menos una categoría')),
      );
      return;
    }

    final descripcionController = TextEditingController();
    final montoController = TextEditingController();
    String tipoTransaccion = 'egreso';
    String formaPago = 'debito';
    Cuenta? cuentaSeleccionada = cuentas.first;
    Categoria? categoriaSeleccionada = categorias.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nueva Transacción'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: tipoTransaccion,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'ingreso', child: Text('Ingreso')),
                    DropdownMenuItem(value: 'egreso', child: Text('Egreso')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      tipoTransaccion = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descripcionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Ej: Compra supermercado',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: montoController,
                  decoration: const InputDecoration(
                    labelText: 'Monto',
                    prefixText: '\$ ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Cuenta>(
                  value: cuentaSeleccionada,
                  decoration: const InputDecoration(labelText: 'Cuenta'),
                  items: cuentas.map((cuenta) {
                    return DropdownMenuItem(
                      value: cuenta,
                      child: Text(cuenta.nombre),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      cuentaSeleccionada = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Categoria>(
                  value: categoriaSeleccionada,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: categorias
                      .where((c) => c.tipo == tipoTransaccion)
                      .map((categoria) {
                    return DropdownMenuItem(
                      value: categoria,
                      child: Text(categoria.nombre),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      categoriaSeleccionada = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: formaPago,
                  decoration: const InputDecoration(labelText: 'Forma de pago'),
                  items: const [
                    DropdownMenuItem(value: 'debito', child: Text('Débito (inmediato)')),
                    DropdownMenuItem(value: 'credito', child: Text('Crédito (cuotas)')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      formaPago = value!;
                    });
                  },
                ),
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
                if (descripcionController.text.isNotEmpty &&
                    montoController.text.isNotEmpty &&
                    cuentaSeleccionada != null &&
                    categoriaSeleccionada != null) {
                  final monto = double.tryParse(montoController.text) ?? 0;

                  await widget.database.into(widget.database.transacciones).insert(
                    TransaccionesCompanion.insert(
                      tipo: tipoTransaccion,
                      descripcion: descripcionController.text,
                      montoTotal: monto,
                      formaPago: formaPago,
                      fecha: DateTime.now(),
                      cuentaId: cuentaSeleccionada!.id,
                      categoriaId: categoriaSeleccionada!.id,
                    ),
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transacción registrada exitosamente')),
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

  void _showTransaccionDetails(Transaccion transaccion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(transaccion.descripcion),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tipo: ${transaccion.tipo}'),
            Text('Monto: \$${transaccion.montoTotal}'),
            Text('Forma de pago: ${transaccion.formaPago}'),
            Text('Fecha: ${_dateFormat.format(transaccion.fecha)}'),
            if (transaccion.formaPago == 'credito')
              Text('Cuotas: ${transaccion.cantidadCuotas}'),
            if (transaccion.esPrestamo)
              const Text('Es un préstamo', style: TextStyle(color: Colors.orange)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () async {
              await (widget.database.delete(widget.database.transacciones)
                    ..where((t) => t.id.equals(transaccion.id)))
                  .go();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transacción eliminada')),
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