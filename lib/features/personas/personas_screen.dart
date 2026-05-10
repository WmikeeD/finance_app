import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/database.dart';
import '../../core/utils/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../core/navigation/app_tab_controller.dart';

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
            return AppErrorState(error: snapshot.error);
          }

          final personas = snapshot.data ?? [];

          if (personas.isEmpty) {
            return AppEmptyState(
              icon: Icons.people_outline,
              title: 'No hay personas registradas',
              subtitle: 'Registra personas para gestionar préstamos',
              buttonLabel: 'Agregar Persona',
              onAction: () => _showAddPersonaDialog(),
            );
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
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet, color: AppTheme.alertCaution),
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
                    backgroundColor: AppTheme.alertCaution.withValues(alpha: 0.15),
                    label: Text(
                      Formatters.monedaConSimbolo(total),
                      style: TextStyle(
                        color: AppTheme.alertCaution,
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
                return AppEmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'No hay deudas pendientes',
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
                          backgroundColor: esCuotas
                              ? AppTheme.creditColor.withValues(alpha: 0.12)
                              : AppTheme.savingsColor.withValues(alpha: 0.12),
                          child: Icon(
                            esCuotas ? Icons.credit_card : Icons.money_off,
                            color: esCuotas ? AppTheme.creditColor : AppTheme.savingsColor,
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
                                  color: Theme.of(context).colorScheme.outline,
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.expenseColor,
                              ),
                            ),
                            Text(
                              'de ${Formatters.monedaConSimbolo(deuda.montoTotal)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progreso,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progreso >= 1 ? AppTheme.alertOk : AppTheme.alertCaution,
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
                          icon: const Icon(Icons.payments, size: 16),
                          label: const Text('Cobrar deuda'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.incomeColor,
                          ),
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
        
        Color color = AppTheme.alertOk;
        if (diasRestantes < 0) {
          color = AppTheme.alertDanger;
        } else if (diasRestantes < 5) {
          color = AppTheme.alertCaution;
        }
        
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
    final cuentas = await widget.database.select(widget.database.cuentas).get();
    final categoriaCobroList = await (widget.database.select(widget.database.categorias)
          ..where((c) =>
              c.nombre.equals('Cobro de Préstamo') & c.tipo.equals('ingreso')))
        .get();
    final transaccion = await (widget.database.select(widget.database.transacciones)
          ..where((t) => t.id.equals(deuda.transaccionId)))
        .getSingleOrNull();

    if (!mounted) return;

    if (cuentas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero debes crear al menos una cuenta')),
      );
      return;
    }

    final montoController = TextEditingController(
      text: deuda.montoPendiente.toStringAsFixed(2),
    );
    final notasController = TextEditingController();
    Cuenta cuentaSeleccionada = cuentas.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: BoxDecoration(
              color: Theme.of(ctx).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.payments, color: AppTheme.incomeColor),
                    const SizedBox(width: 8),
                    const Text(
                      'Cobrar Deuda',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (transaccion != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    transaccion.descripcion,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(ctx).colorScheme.outline,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoRow(
                        ctx,
                        'Total deuda',
                        Formatters.monedaConSimbolo(deuda.montoTotal),
                        Theme.of(ctx).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoRow(
                        ctx,
                        'Pendiente',
                        Formatters.monedaConSimbolo(deuda.montoPendiente),
                        AppTheme.alertCaution.withValues(alpha: 0.1),
                        textColor: AppTheme.alertCaution,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: montoController,
                  decoration: InputDecoration(
                    labelText: 'Monto a cobrar',
                    prefixText: '\$ ',
                    prefixIcon: const Icon(Icons.attach_money),
                    helperText:
                        'Máximo: ${Formatters.monedaConSimbolo(deuda.montoPendiente)}',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Cuenta>(
                  key: ValueKey(cuentaSeleccionada),
                  initialValue: cuentaSeleccionada,
                  decoration: const InputDecoration(
                    labelText: 'Cuenta de destino',
                    prefixIcon: Icon(Icons.account_balance_wallet),
                  ),
                  items: cuentas
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.nombre),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setSheetState(() => cuentaSeleccionada = v ?? cuentaSeleccionada),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notasController,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    prefixIcon: Icon(Icons.note_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Registrar Cobro'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.incomeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final monto =
                          double.tryParse(montoController.text.trim());
                      if (monto == null || monto <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Ingresa un monto válido')),
                        );
                        return;
                      }
                      if (monto > deuda.montoPendiente) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('El monto supera la deuda pendiente')),
                        );
                        return;
                      }

                      final categoriaId = categoriaCobroList.isNotEmpty
                          ? categoriaCobroList.first.id
                          : await (widget.database.select(
                                  widget.database.categorias)
                                ..where((c) => c.tipo.equals('ingreso')))
                              .get()
                              .then((list) => list.first.id);

                      await widget.database.registrarPagoDeuda(
                        deudaId: deuda.id,
                        cuentaId: cuentaSeleccionada.id,
                        monto: monto,
                        descripcion:
                            'Cobro: ${transaccion?.descripcion ?? 'deuda'}',
                        personaId: deuda.personaId,
                        categoriaCobroId: categoriaId,
                        notas: notasController.text.isEmpty
                            ? null
                            : notasController.text,
                      );

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Cobro de ${Formatters.monedaConSimbolo(monto)} registrado',
                            ),
                            action: SnackBarAction(
                              label: 'Ver transacciones',
                              onPressed: AppTabController.goToTransacciones,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    montoController.dispose();
    notasController.dispose();
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    Color bgColor, {
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: textColor,
            ),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                if (tieneDeuda)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.expenseColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Debe: ${Formatters.monedaConSimbolo(totalDeuda)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.expenseColor,
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
                    color: deuda.estado == 'pagada' ? AppTheme.alertOk : AppTheme.alertCaution,
                  ),
                  title: Text(Formatters.monedaConSimbolo(deuda.montoTotal)),
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
        return AppTheme.alertOk.withValues(alpha: 0.15);
      case 'parcial':
        return AppTheme.alertCaution.withValues(alpha: 0.15);
      case 'vencida':
        return AppTheme.alertDanger.withValues(alpha: 0.15);
      default:
        return AppTheme.alertWarning.withValues(alpha: 0.12);
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
            child: Text('Eliminar', style: TextStyle(color: AppTheme.alertDanger)),
          ),
        ],
      ),
    );
  }
}