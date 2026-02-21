import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/database.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_drawer.dart';

class PersonasScreen extends StatefulWidget {
  final AppDatabase database;
  
  const PersonasScreen({super.key, required this.database});

  @override
  State<PersonasScreen> createState() => _PersonasScreenState();
}

class _PersonasScreenState extends State<PersonasScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Personas'),
        actions: [
          // ✅ Botón para ver resumen de deudas
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Ver deudas',
            onPressed: () => _showResumenDeudas(),
          ),
        ],
      ),
      drawer: AppDrawer(
        database: widget.database,
        currentRoute: '/personas',
      ),
      body: StreamBuilder<List<Persona>>(
        stream: widget.database.select(widget.database.personas).watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final personas = snapshot.data ?? [];

          if (personas.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: personas.length,
            itemBuilder: (context, index) {
              final persona = personas[index];
              return _buildPersonaCard(persona);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPersonaDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Persona'),
      ),
    );
  }

  // ✅ NUEVO: Mostrar resumen de todas las deudas
  void _showResumenDeudas() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return _buildDeudasSheet(scrollController);
        },
      ),
    );
  }

  Widget _buildDeudasSheet(ScrollController scrollController) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.orange),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Deudas Pendientes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              StreamBuilder<List<Deuda>>(
                stream: (widget.database.select(widget.database.deudas)
                  ..where((d) => d.estado.equals('pendiente') | d.estado.equals('parcial')))
                  .watch(),
                builder: (context, snapshot) {
                  final deudas = snapshot.data ?? [];
                  final total = deudas.fold(0.0, (sum, d) => sum + d.montoPendiente);
                  
                  return Chip(
                    backgroundColor: Colors.orange[100],
                    label: Text(
                      Formatters.monedaConSimbolo(total),
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: StreamBuilder<List<Deuda>>(
            stream: (widget.database.select(widget.database.deudas)
                  ..where((d) => d.estado.isNotIn(['pagada']))
                  ..orderBy([(d) => drift.OrderingTerm(expression: d.creadaEn, mode: drift.OrderingMode.desc)]))
                .watch(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final deudas = snapshot.data ?? [];

              if (deudas.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green[200]),
                      const SizedBox(height: 16),
                      const Text(
                        'No hay deudas pendientes',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: deudas.length,
                itemBuilder: (context, index) => _buildDeudaCard(deudas[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeudaCard(Deuda deuda) {
    return FutureBuilder<Persona?>(
      future: (widget.database.select(widget.database.personas)
            ..where((p) => p.id.equals(deuda.personaId)))
          .getSingleOrNull(),
      builder: (context, snapshot) {
        final persona = snapshot.data;
        
        return FutureBuilder<Transaccion?>(
          future: (widget.database.select(widget.database.transacciones)
                ..where((t) => t.id.equals(deuda.transaccionId)))
              .getSingleOrNull(),
          builder: (context, transSnapshot) {
            final transaccion = transSnapshot.data;
            
            final esCuotas = deuda.tipo == 'cuotas';
            final progreso = deuda.montoPagado / deuda.montoTotal;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: esCuotas ? Colors.purple[100] : Colors.blue[100],
                          child: Icon(
                            esCuotas ? Icons.credit_card : Icons.money_off,
                            color: esCuotas ? Colors.purple : Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                persona?.nombre ?? 'Desconocido',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                transaccion?.descripcion ?? 'Sin descripción',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Formatters.monedaConSimbolo(deuda.montoPendiente),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red,
                              ),
                            ),
                            Text(
                              'de ${Formatters.monedaConSimbolo(deuda.montoTotal)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progreso,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progreso >= 1 ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Chip(
                          label: Text(
                            esCuotas ? 'A cuotas' : 'Pago único',
                            style: const TextStyle(fontSize: 11),
                          ),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        if (esCuotas)
                          _buildProximaCuotaInfo(deuda.transaccionId),
                        TextButton.icon(
                          onPressed: () => _registrarPago(deuda),
                          icon: const Icon(Icons.add_circle, size: 16),
                          label: const Text('Registrar pago'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProximaCuotaInfo(int transaccionId) {
    return FutureBuilder<List<Cuota>>(
      future: (widget.database.select(widget.database.cuotas)
            ..where((c) => c.transaccionId.equals(transaccionId) & c.pagada.equals(false))
            ..orderBy([(c) => drift.OrderingTerm(expression: c.fechaVencimiento)])
            ..limit(1))
          .get(),
      builder: (context, snapshot) {
        final cuotas = snapshot.data ?? [];
        if (cuotas.isEmpty) return const SizedBox.shrink();
        
        final cuota = cuotas.first;
        final diasRestantes = cuota.fechaVencimiento.difference(DateTime.now()).inDays;
        
        Color color = Colors.green;
        if (diasRestantes < 0) color = Colors.red;
        else if (diasRestantes < 5) color = Colors.orange;
        
        return Text(
          'Próxima: ${Formatters.fecha(cuota.fechaVencimiento)}',
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }

  Future<void> _registrarPago(Deuda deuda) async {
    final montoController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deuda pendiente: ${Formatters.monedaConSimbolo(deuda.montoPendiente)}'),
            const SizedBox(height: 16),
            TextField(
              controller: montoController,
              decoration: const InputDecoration(
                labelText: 'Monto a pagar',
                prefixText: '\$ ',
              ),
              keyboardType: TextInputType.number,
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
              final monto = double.tryParse(montoController.text);
              if (monto == null || monto <= 0) return;
              
              if (monto > deuda.montoPendiente) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El pago excede la deuda pendiente')),
                );
                return;
              }

              await widget.database.transaction(() async {
                // 1. Registrar el pago
                await widget.database.into(widget.database.pagosDeuda).insert(
                  PagosDeudaCompanion.insert(
                    deudaId: deuda.id,
                    monto: monto,
                  ),
                );

                // 2. Actualizar la deuda
                final nuevoPagado = deuda.montoPagado + monto;
                final nuevoPendiente = deuda.montoTotal - nuevoPagado;
                final nuevoEstado = nuevoPendiente <= 0 ? 'pagada' : 
                                   (nuevoPagado > 0 ? 'parcial' : 'pendiente');

                await widget.database.update(widget.database.deudas).replace(
                  deuda.copyWith(
                    montoPagado: nuevoPagado,
                    montoPendiente: nuevoPendiente,
                    estado: nuevoEstado,
                  ),
                );

                // 3. Si es deuda a cuotas, marcar cuota como pagada (simplificado)
                if (deuda.tipo == 'cuotas') {
                  final cuotasPendientes = await (widget.database.select(widget.database.cuotas)
                        ..where((c) => c.transaccionId.equals(deuda.transaccionId) & c.pagada.equals(false))
                        ..orderBy([(c) => drift.OrderingTerm(expression: c.numeroCuota)]))
                      .get();

                  double montoRestante = monto;
                  for (final cuota in cuotasPendientes) {
                    if (montoRestante <= 0) break;
                    
                    if (montoRestante >= cuota.monto) {
                      // Paga la cuota completa
                      await widget.database.update(widget.database.cuotas).replace(
                        cuota.copyWith(
                          pagada: true, 
                          fechaPago: drift.Value(DateTime.now()),
                        ),
                      );
                      montoRestante -= cuota.monto;
                    }
                    // Si el pago es parcial de una cuota, necesitarías lógica adicional
                  }
                }
              });

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pago registrado exitosamente')),
                );
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  // ... resto de métodos existentes (_buildEmptyState, _buildPersonaCard, etc) ...
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay personas registradas',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Registra personas para gestionar préstamos',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddPersonaDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Agregar Persona'),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaCard(Persona persona) {
    Color personaColor = Color(int.parse(persona.color.replaceFirst('#', '0xFF')));
    String iniciales = persona.avatar ?? _getIniciales(persona.nombre);

    // ✅ MOSTRAR DEUDA TOTAL DE LA PERSONA
    return StreamBuilder<List<Deuda>>(
      stream: (widget.database.select(widget.database.deudas)
            ..where((d) => d.personaId.equals(persona.id) & d.estado.isNotIn(['pagada'])))
          .watch(),
      builder: (context, snapshot) {
        final deudas = snapshot.data ?? [];
        final totalDeuda = deudas.fold(0.0, (sum, d) => sum + d.montoPendiente);
        final tieneDeuda = totalDeuda > 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: personaColor,
              child: Text(
                iniciales,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              persona.nombre,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (persona.relacion != null)
                  Text(
                    persona.relacion!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                if (tieneDeuda)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Debe: ${Formatters.monedaConSimbolo(totalDeuda)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showEditPersonaDialog(persona),
            ),
            onTap: () => _verDetallePersona(persona),
          ),
        );
      },
    );
  }

  void _verDetallePersona(Persona persona) {
    // Mostrar detalle de deudas específicas de esta persona
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildDetalleDeudasPersona(persona),
    );
  }

  Widget _buildDetalleDeudasPersona(Persona persona) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deudas de ${persona.nombre}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Deuda>>(
            stream: (widget.database.select(widget.database.deudas)
                  ..where((d) => d.personaId.equals(persona.id))
                  ..orderBy([(d) => drift.OrderingTerm(expression: d.creadaEn, mode: drift.OrderingMode.desc)]))
                .watch(),
            builder: (context, snapshot) {
              final deudas = snapshot.data ?? [];
              
              if (deudas.isEmpty) {
                return const Center(
                  child: Text('No tiene deudas registradas'),
                );
              }

              return Column(
                children: deudas.map((deuda) => ListTile(
                  leading: Icon(
                    deuda.tipo == 'cuotas' ? Icons.credit_card : Icons.money_off,
                    color: deuda.estado == 'pagada' ? Colors.green : Colors.orange,
                  ),
                  title: Text('${Formatters.monedaConSimbolo(deuda.montoTotal)}'),
                  subtitle: Text('Pendiente: ${Formatters.monedaConSimbolo(deuda.montoPendiente)}'),
                  trailing: Chip(
                    label: Text(deuda.estado.toUpperCase()),
                    backgroundColor: _getColorEstado(deuda.estado),
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'pagada':
        return Colors.green[100]!;
      case 'parcial':
        return Colors.orange[100]!;
      case 'vencida':
        return Colors.red[100]!;
      default:
        return Colors.grey[200]!;
    }
  }

  String _getIniciales(String nombre) {
    final palabras = nombre.trim().split(' ');
    if (palabras.isEmpty) return '??';
    if (palabras.length == 1) {
      return palabras[0].substring(0, 1).toUpperCase();
    }
    return (palabras[0].substring(0, 1) + palabras[1].substring(0, 1)).toUpperCase();
  }

  void _showAddPersonaDialog() {
    final nombreController = TextEditingController();
    final telefonoController = TextEditingController();
    final relacionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Persona'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  hintText: 'Ej: Juan Pérez',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: relacionController,
                decoration: const InputDecoration(
                  labelText: 'Relación (opcional)',
                  hintText: 'Ej: Hermano, Amigo',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: telefonoController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (opcional)',
                  hintText: 'Ej: +56 9 1234 5678',
                ),
                keyboardType: TextInputType.phone,
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
              if (nombreController.text.isNotEmpty) {
                final iniciales = _getIniciales(nombreController.text);
                
                await widget.database.into(widget.database.personas).insert(
                  PersonasCompanion.insert(
                    nombre: nombreController.text,
                    telefono: telefonoController.text.isEmpty 
                        ? const drift.Value(null) 
                        : drift.Value(telefonoController.text),
                    relacion: relacionController.text.isEmpty 
                        ? const drift.Value(null) 
                        : drift.Value(relacionController.text),
                    avatar: drift.Value(iniciales),
                  ),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Persona registrada exitosamente')),
                  );
                }
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showEditPersonaDialog(Persona persona) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(persona.nombre),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (persona.relacion != null)
              Text('Relación: ${persona.relacion}'),
            if (persona.telefono != null)
              Text('Teléfono: ${persona.telefono}'),
            if (persona.email != null)
              Text('Email: ${persona.email}'),
            if (persona.notas != null)
              Text('Notas: ${persona.notas}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () async {
              await (widget.database.delete(widget.database.personas)
                    ..where((p) => p.id.equals(persona.id)))
                  .go();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Persona eliminada')),
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