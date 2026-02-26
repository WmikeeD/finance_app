import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift hide Column;
import '../../core/database/database.dart';
import '../../core/widgets/app_drawer.dart';
import '../cuentas/cuentas_screen.dart';
import '../../core/utils/formatters.dart';

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
        // Botón de editar
        onLongPress: () => _showEditTransaccionDialog(transaccion),
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

  void _showEditTransaccionDialog(Transaccion transaccion) async {
    // Obtener datos relacionados
    final cuenta = await (widget.database.select(widget.database.cuentas)
          ..where((c) => c.id.equals(transaccion.cuentaId)))
        .getSingle();
    
    final categorias = await widget.database.select(widget.database.categorias).get();
    
    // Controllers
    final descripcionController = TextEditingController(text: transaccion.descripcion);
    final montoController = TextEditingController(text: transaccion.montoTotal.toString());
    
    // Variables de estado
    Categoria? categoriaSeleccionada = categorias.firstWhere(
      (c) => c.id == transaccion.categoriaId,
      orElse: () => categorias.first,
    );
    
    DateTime fechaSeleccionada = transaccion.fecha;
    double montoOriginal = transaccion.montoTotal;
    bool editarMonto = false;
    bool editarFecha = false;

    // Verificar si hay cuotas pagadas
    final cuotasPagadas = await (widget.database.select(widget.database.cuotas)
          ..where((c) => c.transaccionId.equals(transaccion.id) & c.pagada.equals(true)))
        .get();
    
    final tieneCuotasPagadas = cuotasPagadas.isNotEmpty;
    final esCredito = transaccion.formaPago == 'credito';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Editar Transacción'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info no editable
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cuenta: ${cuenta.nombre}', style: TextStyle(color: Colors.grey[700])),
                        Text('Tipo: ${transaccion.tipo}', style: TextStyle(color: Colors.grey[700])),
                        if (esCredito)
                          Text('${transaccion.cantidadCuotas} cuotas', style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ✅ EDICIÓN BÁSICA - Siempre permitida
                  
                  // Descripción
                  TextField(
                    controller: descripcionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Categoría
                  DropdownButtonFormField<Categoria>(
                    value: categoriaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: categorias.where((c) => c.tipo == transaccion.tipo).map((categoria) {
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
                  const SizedBox(height: 24),

                  // ✅ EDICIÓN AVANZADA - Con restricciones
                  
                  const Divider(),
                  const Text(
                    'Edición Avanzada',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),

                  // Monto
                  CheckboxListTile(
                    title: const Text('Editar monto'),
                    subtitle: Text(
                      esCredito 
                        ? 'Recalculará el valor de las cuotas pendientes'
                        : 'Ajustará el saldo de la cuenta',
                    ),
                    value: editarMonto,
                    onChanged: (value) {
                      if (esCredito && tieneCuotasPagadas) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No se puede editar el monto si ya hay cuotas pagadas'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      setDialogState(() {
                        editarMonto = value ?? false;
                      });
                    },
                  ),
                  if (editarMonto) ...[
                    TextField(
                      controller: montoController,
                      decoration: InputDecoration(
                        labelText: 'Nuevo monto',
                        prefixText: '\$ ',
                        helperText: esCredito 
                          ? 'Monto original: ${Formatters.monedaConSimbolo(montoOriginal)}'
                          : null,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Fecha
                  CheckboxListTile(
                    title: const Text('Editar fecha'),
                    subtitle: Text(
                      esCredito
                        ? tieneCuotasPagadas
                          ? '❌ No disponible: hay cuotas pagadas'
                          : 'Recalculará las fechas de vencimiento de cuotas'
                        : 'Cambiará la fecha del registro',
                    ),
                    value: editarFecha,
                    onChanged: (tieneCuotasPagadas && esCredito) 
                      ? null  // Deshabilitado si hay cuotas pagadas
                      : (value) {
                          setDialogState(() {
                            editarFecha = value ?? false;
                          });
                        },
                  ),
                  if (editarFecha) ...[
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Fecha de compra'),
                      subtitle: Text(Formatters.fecha(fechaSeleccionada)),
                      trailing: const Icon(Icons.edit),
                      onTap: () async {
                        final nuevaFecha = await showDatePicker(
                          context: context,
                          initialDate: fechaSeleccionada,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (nuevaFecha != null) {
                          setDialogState(() {
                            fechaSeleccionada = nuevaFecha;
                          });
                        }
                      },
                    ),
                    if (esCredito) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '⚠️ Al cambiar la fecha, se recalcularán las fechas de vencimiento de las cuotas según el nuevo cierre de tarjeta.',
                          style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                        ),
                      ),
                    ],
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
                  final nuevoMonto = double.tryParse(montoController.text) ?? montoOriginal;
                  
                  if (editarMonto && nuevoMonto <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingresa un monto válido')),
                    );
                    return;
                  }

                  await _actualizarTransaccion(
                    transaccion: transaccion,
                    nuevaDescripcion: descripcionController.text,
                    nuevaCategoriaId: categoriaSeleccionada!.id,
                    editarMonto: editarMonto,
                    nuevoMonto: nuevoMonto,
                    editarFecha: editarFecha,
                    nuevaFecha: fechaSeleccionada,
                    cuenta: cuenta,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transacción actualizada')),
                    );
                  }
                },
                child: const Text('Guardar cambios'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _crearDeudaDesdeTransaccion({
    required int personaId,
    required int transaccionId,
    required String tipo,
    required double montoTotal,
    int? cantidadCuotas,
  }) async {
    await widget.database.into(widget.database.deudas).insert(
      DeudasCompanion.insert(
        personaId: personaId,
        transaccionId: transaccionId,
        tipo: tipo,
        montoTotal: montoTotal,
        montoPendiente: montoTotal,
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
    
    // Si es a crédito, validar campos de cuotas
    int? cantidadCuotas;
    double? valorCuotaValue;
    double? montoConInteres;
    double? interesTotal;

    // VALIDACIONES INICIALES (antes de la transacción)
    if (descripcion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una descripción')),
      );
      return;
    }

    // PARSEAR MONTO AQUÍ para tenerlo disponible
    final montoValue = double.tryParse(monto);
    if (montoValue == null || montoValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido')),
      );
      return;
    }

    // VALIDAR QUE CUENTA Y CATEGORIA NO SEAN NULL
    if (cuenta == null || categoria == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona cuenta y categoría')),
      );
      return;
    }    

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

      montoConInteres = valorCuotaValue * cantidadCuotas;
      interesTotal = montoConInteres - montoValue;
    }

    // AHORA SÍ: Ejecutar en transacción atómica
    // cuenta ya está validada que no es null
    await widget.database.transaction(() async {
      // 1. Crear transacción
      final transaccionId = await widget.database.into(widget.database.transacciones).insert(
        TransaccionesCompanion.insert(
          tipo: tipo,
          descripcion: descripcion,
          montoTotal: montoValue, // ✅ Ya está definido
          formaPago: formaPago,
          fecha: DateTime.now(),
          cuentaId: cuenta.id, // ✅ Safe porque validamos cuenta != null
          categoriaId: categoria.id,
          esPrestamo: drift.Value(esPrestamo),
          personaId: drift.Value(persona?.id),
          cantidadCuotas: drift.Value(cantidadCuotas),
          valorCuota: drift.Value(valorCuotaValue),
          montoTotalConInteres: drift.Value(montoConInteres),
          interesTotal: drift.Value(interesTotal),
        ),
      );

      // 2. Si es a crédito, crear las cuotas con lógica de fechas correcta
      if (formaPago == 'credito' && cantidadCuotas != null && valorCuotaValue != null) {
        // ✅ OBTENER fechas de la cuenta (ya validada que no es null)
        final diaCierre = cuenta.diaCierre;
        final diaPago = cuenta.diaPago;
        
        if (diaCierre == null || diaPago == null) {
          throw Exception('La cuenta de crédito no tiene configurada la fecha de cierre o pago');
        }

        final fechaCompra = DateTime.now();
        
        // ✅ CALCULAR fecha de la primera cuota
        final fechaPrimeraCuota = _calcularFechaPrimeraCuota(
          fechaCompra: fechaCompra,
          diaCierre: diaCierre,
          diaPago: diaPago,
        );

        // Crear cada cuota sumando meses a partir de la primera
        for (int i = 0; i < cantidadCuotas; i++) {
          final fechaVencimiento = DateTime(
            fechaPrimeraCuota.year,
            fechaPrimeraCuota.month + i,
            diaPago,
          );
          
          await widget.database.into(widget.database.cuotas).insert(
            CuotasCompanion.insert(
              transaccionId: transaccionId,
              numeroCuota: i + 1,
              monto: valorCuotaValue,
              fechaVencimiento: fechaVencimiento,
            ),
          );
        }
      }

      if (esPrestamo && persona != null) {
        await _crearDeudaDesdeTransaccion(
          personaId: persona.id,
          transaccionId: transaccionId,
          tipo: formaPago == 'credito' ? 'cuotas' : 'simple',
          montoTotal: formaPago == 'credito' ? montoConInteres! : montoValue,
          cantidadCuotas: cantidadCuotas,
        );
      }

      // 3. Actualizar saldo de la cuenta ✅ cuenta no es null
      double nuevoSaldo = cuenta.saldo;
      
      if (tipo == 'ingreso') {
        nuevoSaldo += montoValue;
      } else if (tipo == 'egreso') {
        if (formaPago == 'debito' || formaPago == 'efectivo') {
          nuevoSaldo -= montoValue;
        } else if (formaPago == 'credito') {
          nuevoSaldo -= montoValue;
        }
      }

      await widget.database.update(widget.database.cuentas).replace(
        cuenta.copyWith(saldo: nuevoSaldo),
      );
    });

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transacción registrada exitosamente')),
      );
    }
  }

  Future<void> _actualizarTransaccion({
    required Transaccion transaccion,
    required String nuevaDescripcion,
    required int nuevaCategoriaId,
    required bool editarMonto,
    required double nuevoMonto,
    required bool editarFecha,
    required DateTime nuevaFecha,
    required Cuenta cuenta,
  }) async {
    await widget.database.transaction(() async {
      final esCredito = transaccion.formaPago == 'credito';
      final montoAnterior = transaccion.montoTotal;
      
      // 1. Actualizar datos básicos siempre
      await widget.database.update(widget.database.transacciones).replace(
        transaccion.copyWith(
          descripcion: nuevaDescripcion,
          categoriaId: nuevaCategoriaId,
          montoTotal: editarMonto ? nuevoMonto : transaccion.montoTotal,
          fecha: editarFecha ? nuevaFecha : transaccion.fecha,
          // Si edita monto y es crédito, recalcular campos relacionados
          montoTotalConInteres: (editarMonto && esCredito)
            ? drift.Value(nuevoMonto * (transaccion.montoTotalConInteres! / montoAnterior))
            : drift.Value(transaccion.montoTotalConInteres),

          // Lo mismo para valorCuota
          valorCuota: (editarMonto && esCredito)
              ? drift.Value(nuevoMonto / transaccion.cantidadCuotas!)
              : drift.Value(transaccion.valorCuota),
        ),
      );

      // 2. Si edita monto y es débito/efectivo, ajustar saldo de cuenta
      if (editarMonto && !esCredito) {
        final diferencia = nuevoMonto - montoAnterior;
        double nuevoSaldo = cuenta.saldo;
        
        if (transaccion.tipo == 'egreso') {
          // Si era egreso de $50 y ahora es $60, restar $10 más
          nuevoSaldo -= diferencia;
        } else if (transaccion.tipo == 'ingreso') {
          // Si era ingreso de $50 y ahora es $60, sumar $10 más
          nuevoSaldo += diferencia;
        }

        await widget.database.update(widget.database.cuentas).replace(
          cuenta.copyWith(saldo: nuevoSaldo),
        );
      }

      // 3. Si edita monto y es crédito, recalcular cuotas pendientes
      if (editarMonto && esCredito) {
        final cuotasPendientes = await (widget.database.select(widget.database.cuotas)
              ..where((c) => c.transaccionId.equals(transaccion.id) & c.pagada.equals(false)))
            .get();

        final nuevoValorCuota = nuevoMonto / transaccion.cantidadCuotas!;
        
        for (final cuota in cuotasPendientes) {
          await widget.database.update(widget.database.cuotas).replace(
            cuota.copyWith(monto: nuevoValorCuota),
          );
        }

        // Actualizar deuda asociada si es préstamo
        if (transaccion.esPrestamo) {
          final deuda = await (widget.database.select(widget.database.deudas)
                ..where((d) => d.transaccionId.equals(transaccion.id)))
              .getSingleOrNull();
          
          if (deuda != null) {
            final proporcionPagada = deuda.montoPagado / deuda.montoTotal;
            final nuevoMontoPagado = nuevoMonto * proporcionPagada;
            
            await widget.database.update(widget.database.deudas).replace(
              deuda.copyWith(
                montoTotal: nuevoMonto,
                montoPendiente: nuevoMonto - nuevoMontoPagado,
                montoPagado: nuevoMontoPagado,
              ),
            );
          }
        }
      }

      // 4. Si edita fecha y es crédito, recalcular fechas de cuotas
      if (editarFecha && esCredito) {
        final diaCierre = cuenta.diaCierre;
        final diaPago = cuenta.diaPago;
        
        if (diaCierre != null && diaPago != null) {
          final nuevaFechaPrimeraCuota = _calcularFechaPrimeraCuota(
            fechaCompra: nuevaFecha,
            diaCierre: diaCierre,
            diaPago: diaPago,
          );

          final cuotas = await (widget.database.select(widget.database.cuotas)
                ..where((c) => c.transaccionId.equals(transaccion.id))
                ..orderBy([(c) => drift.OrderingTerm(expression: c.numeroCuota)]))
              .get();

          for (int i = 0; i < cuotas.length; i++) {
            final nuevaFechaVencimiento = DateTime(
              nuevaFechaPrimeraCuota.year,
              nuevaFechaPrimeraCuota.month + i,
              diaPago,
            );
            
            await widget.database.update(widget.database.cuotas).replace(
              cuotas[i].copyWith(fechaVencimiento: nuevaFechaVencimiento),
            );
          }
        }
      }
    });
  }

  ///MÉTODO AUXILIAR: Calcula la fecha de la primera cuota según lógica de tarjeta de crédito
  DateTime _calcularFechaPrimeraCuota({
    required DateTime fechaCompra,
    required int diaCierre,
    required int diaPago,
  }) {
    final year = fechaCompra.year;        // ✅ 'year' en lugar de 'año'
    final month = fechaCompra.month;      // ✅ 'month' en lugar de 'mes'
    final day = fechaCompra.day;          // ✅ 'day' en lugar de 'dia'

    // Fecha de cierre del mes actual
    //final fechaCierreEsteMes = DateTime(year, month, diaCierre);
    
    // Comparar: ¿la compra es ANTES o el DÍA del cierre?
    // Si es EL DÍA del cierre, se considera DESPUÉS (entra al siguiente periodo)
    if (day <= diaCierre) {
      // ✅ COMPRA ANTES O EL DÍA DEL CIERRE
      // - Entra en el resumen que cierra ESTE mes
      // - Se paga el mes siguiente
      return DateTime(year, month + 1, diaPago);
    } else {
      // ✅ COMPRA DESPUÉS DEL CIERRE
      // - Entra en el resumen que cierra el MES SIGUIENTE
      // - Se paga dentro de 2 meses
      return DateTime(year, month + 2, diaPago);
    }
  }
  /*Future<void> _guardarTransaccion({
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
  }*/

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
                // ✅ NUEVO: Revertir el saldo antes de eliminar
                await widget.database.transaction(() async {
                  // 1. Obtener la cuenta asociada
                  final cuenta = await (widget.database.select(widget.database.cuentas)
                        ..where((c) => c.id.equals(transaccion.cuentaId)))
                      .getSingle();
                  
                  // 2. Calcular el nuevo saldo (revertir la transacción)
                  double nuevoSaldo = cuenta.saldo;
                  
                  if (transaccion.tipo == 'ingreso') {
                    // Si era ingreso, restamos el monto (lo quitamos)
                    nuevoSaldo -= transaccion.montoTotal;
                  } else if (transaccion.tipo == 'egreso') {
                    // Si era egreso, sumamos el monto (lo devolvemos)
                    if (transaccion.formaPago == 'debito' || transaccion.formaPago == 'efectivo') {
                      nuevoSaldo += transaccion.montoTotal;
                    } else if (transaccion.formaPago == 'credito') {
                      nuevoSaldo += transaccion.montoTotal; // Reducimos la deuda
                    }
                  }
                  
                  // 3. Actualizar la cuenta
                  await widget.database.update(widget.database.cuentas).replace(
                    cuenta.copyWith(saldo: nuevoSaldo),
                  );
                  
                  // 4. Si es crédito, eliminar las cuotas asociadas
                  if (transaccion.formaPago == 'credito') {
                    await (widget.database.delete(widget.database.cuotas)
                          ..where((c) => c.transaccionId.equals(transaccion.id)))
                        .go();
                  }
                  
                  // 5. Eliminar la transacción
                  await (widget.database.delete(widget.database.transacciones)
                        ..where((t) => t.id.equals(transaccion.id)))
                      .go();
                });

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
          /*TextButton(
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
          ),*/
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