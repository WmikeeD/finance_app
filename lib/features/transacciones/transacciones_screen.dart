import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
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
              ..orderBy([
                (t) => drift.OrderingTerm(
                      expression: t.fecha,
                      mode: drift.OrderingMode.desc,
                    )
              ]))
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
    // Obtener datos necesarios
    final cuentas = await widget.database.select(widget.database.cuentas).get();
    final categorias = await widget.database.select(widget.database.categorias).get();
    final personas = await widget.database.select(widget.database.personas).get();

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

    // Controllers
    final descripcionController = TextEditingController();
    final montoController = TextEditingController();
    final cuotasController = TextEditingController();
    final valorCuotaController = TextEditingController();
    final tasaInteresController = TextEditingController();
    
    // Variables de estado
    String tipoTransaccion = 'egreso';
    String formaPago = 'debito';
    bool esPrestamo = false;
    Cuenta? cuentaSeleccionada = cuentas.first;
    Categoria? categoriaSeleccionada = categorias.where((c) => c.tipo == 'egreso').first;
    Persona? personaSeleccionada;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Filtrar categorías según tipo
          final categoriasDisponibles = categorias.where((c) => c.tipo == tipoTransaccion).toList();
          
          // Verificar si la cuenta permite crédito
          final permiteCuotas = cuentaSeleccionada?.tipo == 'credito';

          return AlertDialog(
            title: const Text('Nueva Transacción'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tipo de transacción
                  DropdownButtonFormField<String>(
                    value: tipoTransaccion,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      prefixIcon: Icon(Icons.swap_vert),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ingreso', child: Text('Ingreso')),
                      DropdownMenuItem(value: 'egreso', child: Text('Egreso')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        tipoTransaccion = value!;
                        // Actualizar categoría al cambiar tipo
                        final nuevasCategorias = categorias.where((c) => c.tipo == tipoTransaccion).toList();
                        if (nuevasCategorias.isNotEmpty) {
                          categoriaSeleccionada = nuevasCategorias.first;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Descripción
                  TextField(
                    controller: descripcionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Ej: Compra supermercado',
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Monto
                  TextField(
                    controller: montoController,
                    decoration: const InputDecoration(
                      labelText: 'Monto',
                      prefixText: '\$ ',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Cuenta
                  DropdownButtonFormField<Cuenta>(
                    value: cuentaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Cuenta',
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                    items: cuentas.map((cuenta) {
                      return DropdownMenuItem(
                        value: cuenta,
                        child: Text(cuenta.nombre),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        cuentaSeleccionada = value;
                        // Si cambia a cuenta no-crédito, resetear forma de pago
                        if (value?.tipo != 'credito' && formaPago == 'credito') {
                          formaPago = 'debito';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Categoría
                  DropdownButtonFormField<Categoria>(
                    value: categoriaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: categoriasDisponibles.map((categoria) {
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

                  // Forma de pago (solo si la cuenta lo permite)
                  if (permiteCuotas) ...[
                    DropdownButtonFormField<String>(
                      value: formaPago,
                      decoration: const InputDecoration(
                        labelText: 'Forma de pago',
                        prefixIcon: Icon(Icons.payment),
                      ),
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
                    const SizedBox(height: 16),
                  ],

                  // Campos de crédito/cuotas
                  if (formaPago == 'credito') ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Configuración de Cuotas',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Número de cuotas
                    TextField(
                      controller: cuotasController,
                      decoration: const InputDecoration(
                        labelText: 'Número de cuotas',
                        hintText: 'Ej: 12',
                        prefixIcon: Icon(Icons.format_list_numbered),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 16),

                    // Valor de cada cuota
                    TextField(
                      controller: valorCuotaController,
                      decoration: const InputDecoration(
                        labelText: 'Valor de cada cuota',
                        hintText: 'Según estado de cuenta',
                        prefixText: '\$ ',
                        prefixIcon: Icon(Icons.money),
                        helperText: 'El sistema calculará el interés automáticamente',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Es préstamo?
                  const Divider(),
                  CheckboxListTile(
                    title: const Text('Es un préstamo a tercero'),
                    subtitle: const Text('Pagado con tu cuenta pero lo debe otra persona'),
                    value: esPrestamo,
                    onChanged: (value) {
                      setDialogState(() {
                        esPrestamo = value ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),

                  // Selector de persona (si es préstamo)
                  if (esPrestamo) ...[
                    if (personas.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No hay personas registradas. Primero crea una persona.',
                          style: TextStyle(color: Colors.red[700], fontSize: 12),
                        ),
                      )
                    else
                      DropdownButtonFormField<Persona>(
                        value: personaSeleccionada,
                        decoration: const InputDecoration(
                          labelText: 'Persona que debe',
                          prefixIcon: Icon(Icons.person),
                        ),
                        items: personas.map((persona) {
                          return DropdownMenuItem(
                            value: persona,
                            child: Text(persona.nombre),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            personaSeleccionada = value;
                          });
                        },
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
                  await _guardarTransaccion(
                    context: context,
                    descripcion: descripcionController.text,
                    monto: montoController.text,
                    tipo: tipoTransaccion,
                    formaPago: formaPago,
                    cuenta: cuentaSeleccionada,
                    categoria: categoriaSeleccionada,
                    esPrestamo: esPrestamo,
                    persona: personaSeleccionada,
                    cuotas: cuotasController.text,
                    valorCuota: valorCuotaController.text,
                  );
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _guardarTransaccion({
    required BuildContext context,
    required String descripcion,
    required String monto,
    required String tipo,
    required String formaPago,
    required Cuenta? cuenta,
    required Categoria? categoria,
    required bool esPrestamo,
    required Persona? persona,
    required String cuotas,
    required String valorCuota,
  }) async {
    // Validaciones
    if (descripcion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una descripción')),
      );
      return;
    }

    final montoValue = double.tryParse(monto);
    if (montoValue == null || montoValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido')),
      );
      return;
    }

    if (cuenta == null || categoria == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona cuenta y categoría')),
      );
      return;
    }

    if (esPrestamo && persona == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la persona que debe el préstamo')),
      );
      return;
    }

    // Si es a crédito, validar campos de cuotas
    int? cantidadCuotas;
    double? valorCuotaValue;
    double? montoConInteres;
    double? interesTotal;

    if (formaPago == 'credito') {
      cantidadCuotas = int.tryParse(cuotas);
      valorCuotaValue = double.tryParse(valorCuota);

      if (cantidadCuotas == null || cantidadCuotas <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa un número de cuotas válido')),
        );
        return;
      }

      if (valorCuotaValue == null || valorCuotaValue <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa el valor de la cuota')),
        );
        return;
      }

      // Calcular monto con interés e interés total
      montoConInteres = valorCuotaValue * cantidadCuotas;
      interesTotal = montoConInteres - montoValue;
    }

    // Crear transacción
    final transaccionId = await widget.database.into(widget.database.transacciones).insert(
      TransaccionesCompanion.insert(
        tipo: tipo,
        descripcion: descripcion,
        montoTotal: montoValue,
        formaPago: formaPago,
        fecha: DateTime.now(),
        cuentaId: cuenta.id,
        categoriaId: categoria.id,
        esPrestamo: drift.Value(esPrestamo),
        personaId: drift.Value(persona?.id),
        cantidadCuotas: drift.Value(cantidadCuotas),
        valorCuota: drift.Value(valorCuotaValue),
        montoTotalConInteres: drift.Value(montoConInteres),
        interesTotal: drift.Value(interesTotal),
      ),
    );

    // Si es a crédito, crear las cuotas
    if (formaPago == 'credito' && cantidadCuotas != null && valorCuotaValue != null) {
      for (int i = 1; i <= cantidadCuotas; i++) {
        final fechaVencimiento = DateTime.now().add(Duration(days: 30 * i));
        
        await widget.database.into(widget.database.cuotas).insert(
          CuotasCompanion.insert(
            transaccionId: transaccionId,
            numeroCuota: i,
            monto: valorCuotaValue,
            fechaVencimiento: fechaVencimiento,
          ),
        );
      }
    }

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transacción registrada exitosamente')),
      );
    }
  }

  void _showTransaccionDetails(Transaccion transaccion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(transaccion.descripcion),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Tipo', transaccion.tipo.toUpperCase()),
              _buildDetailRow('Monto', '\$${transaccion.montoTotal.toStringAsFixed(0)}'),
              _buildDetailRow('Forma de pago', transaccion.formaPago),
              _buildDetailRow('Fecha', _dateFormat.format(transaccion.fecha)),
              if (transaccion.formaPago == 'credito') ...[
                const Divider(height: 24),
                _buildDetailRow('Cuotas', transaccion.cantidadCuotas.toString()),
                _buildDetailRow('Valor cuota', '\$${transaccion.valorCuota?.toStringAsFixed(0) ?? '0'}'),
                if (transaccion.montoTotalConInteres != null)
                  _buildDetailRow('Total con interés', '\$${transaccion.montoTotalConInteres!.toStringAsFixed(0)}'),
                if (transaccion.interesTotal != null)
                  _buildDetailRow('Interés', '\$${transaccion.interesTotal!.toStringAsFixed(0)}'),
              ],
              if (transaccion.esPrestamo) ...[
                const Divider(height: 24),
                _buildDetailRow('Es préstamo', 'Sí'),
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
                  content: const Text('¿Estás seguro de eliminar esta transacción?'),
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
                await (widget.database.delete(widget.database.transacciones)
                      ..where((t) => t.id.equals(transaccion.id)))
                    .go();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transacción eliminada')),
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

  Widget _buildDetailRow(String label, String value) {
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