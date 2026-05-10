import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift hide Column;
import '../../core/database/database.dart';
import '../../core/services/exportacion_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
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

  // Filtros
  String _busqueda = '';
  String _filtroTipo = 'todos'; // 'todos', 'ingreso', 'egreso'
  int? _cuentaIdFiltro;
  DateTimeRange? _rangoFechas;

  // Paginación de display
  int _displayLimit = 50;

  List<Transaccion> _aplicarFiltros(List<Transaccion> todas) {
    return todas.where((t) {
      if (_filtroTipo != 'todos' && t.tipo != _filtroTipo) return false;
      if (_cuentaIdFiltro != null && t.cuentaId != _cuentaIdFiltro) return false;
      if (_busqueda.isNotEmpty &&
          !t.descripcion.toLowerCase().contains(_busqueda.toLowerCase())) {
        return false;
      }
      if (_rangoFechas != null) {
        if (t.fecha.isBefore(_rangoFechas!.start) ||
            t.fecha.isAfter(_rangoFechas!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transacciones'),
        actions: [
          StreamBuilder<List<Transaccion>>(
            stream: widget.database.select(widget.database.transacciones).watch(),
            builder: (_, snap) {
              final todas = snap.data ?? [];
              final transacciones = _aplicarFiltros(todas);
              if (transacciones.isEmpty) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                icon: const Icon(Icons.ios_share),
                tooltip: 'Exportar',
                onSelected: (fmt) => _exportar(fmt, transacciones),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'csv', child: Text('Exportar CSV')),
                  PopupMenuItem(value: 'pdf', child: Text('Exportar PDF')),
                ],
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: _buildFiltrosBar(),
        ),
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
            return AppErrorState(error: snapshot.error);
          }

          final todas = snapshot.data ?? [];
          final transacciones = _aplicarFiltros(todas);

          if (todas.isEmpty) return _buildEmptyState();

          if (transacciones.isEmpty) {
            return AppEmptyState(
              icon: Icons.search_off,
              title: 'Sin resultados',
              subtitle: 'Prueba con otros filtros',
              buttonLabel: 'Limpiar filtros',
              onAction: _limpiarFiltros,
            );
          }

          final visibles = transacciones.take(_displayLimit).toList();
          final hayMas = transacciones.length > _displayLimit;

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.base),
            itemCount: visibles.length + (hayMas ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == visibles.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _displayLimit += 50),
                      icon: const Icon(Icons.expand_more),
                      label: Text(
                        'Cargar más (${transacciones.length - _displayLimit} restantes)',
                      ),
                    ),
                  ),
                );
              }
              return _buildTransaccionCard(visibles[index]);
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

  Widget _buildFiltrosBar() {
    final hayFiltros = _filtroTipo != 'todos' ||
        _cuentaIdFiltro != null ||
        _rangoFechas != null;

    return Container(
      color: Theme.of(context).appBarTheme.backgroundColor ??
          Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          // Barra de búsqueda
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por descripción...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _busqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _busqueda = ''),
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (v) => setState(() => _busqueda = v),
          ),
          const SizedBox(height: 6),
          // Chips de filtro
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChip(
                  label: 'Todos',
                  selected: _filtroTipo == 'todos',
                  onTap: () => setState(() => _filtroTipo = 'todos'),
                ),
                const SizedBox(width: 6),
                _buildChip(
                  label: 'Ingresos',
                  selected: _filtroTipo == 'ingreso',
                  color: AppTheme.incomeColor,
                  onTap: () => setState(() => _filtroTipo = 'ingreso'),
                ),
                const SizedBox(width: 6),
                _buildChip(
                  label: 'Egresos',
                  selected: _filtroTipo == 'egreso',
                  color: AppTheme.expenseColor,
                  onTap: () => setState(() => _filtroTipo = 'egreso'),
                ),
                const SizedBox(width: 6),
                _buildCuentaChip(),
                const SizedBox(width: 6),
                _buildFechaChip(),
                if (hayFiltros) ...[
                  const SizedBox(width: 6),
                  ActionChip(
                    label: const Text('Limpiar'),
                    avatar: const Icon(Icons.clear, size: 14),
                    onPressed: _limpiarFiltros,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? color,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: (color ?? Theme.of(context).colorScheme.primary)
          .withValues(alpha: 0.2),
      checkmarkColor: color ?? Theme.of(context).colorScheme.primary,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected
            ? (color ?? Theme.of(context).colorScheme.primary)
            : null,
      ),
    );
  }

  Widget _buildCuentaChip() {
    return StreamBuilder<List<Cuenta>>(
      stream: widget.database.select(widget.database.cuentas).watch(),
      builder: (_, snap) {
        final cuentas = snap.data ?? [];
        if (cuentas.isEmpty) return const SizedBox.shrink();

        final nombreCuenta = _cuentaIdFiltro != null
            ? cuentas
                .firstWhere(
                  (c) => c.id == _cuentaIdFiltro,
                  orElse: () => cuentas.first,
                )
                .nombre
            : null;

        return FilterChip(
          label: Text(nombreCuenta ?? 'Cuenta'),
          selected: _cuentaIdFiltro != null,
          avatar: const Icon(Icons.account_balance_wallet, size: 14),
          onSelected: (_) => _showCuentaFilterSheet(cuentas),
          labelStyle: const TextStyle(fontSize: 12),
        );
      },
    );
  }

  Widget _buildFechaChip() {
    final label = _rangoFechas != null
        ? '${_dateFormat.format(_rangoFechas!.start)} – ${_dateFormat.format(_rangoFechas!.end)}'
        : 'Fecha';

    return FilterChip(
      label: Text(label),
      selected: _rangoFechas != null,
      avatar: const Icon(Icons.date_range, size: 14),
      onSelected: (_) => _showDateRangePicker(),
      labelStyle: const TextStyle(fontSize: 12),
    );
  }

  void _showCuentaFilterSheet(List<Cuenta> cuentas) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Filtrar por cuenta',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            title: const Text('Todas las cuentas'),
            leading: const Icon(Icons.all_inclusive),
            selected: _cuentaIdFiltro == null,
            onTap: () {
              setState(() => _cuentaIdFiltro = null);
              Navigator.pop(context);
            },
          ),
          ...cuentas.map((c) => ListTile(
                title: Text(c.nombre),
                subtitle: Text(c.tipo),
                leading: const Icon(Icons.account_balance_wallet),
                selected: _cuentaIdFiltro == c.id,
                onTap: () {
                  setState(() => _cuentaIdFiltro = c.id);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _rangoFechas,
      locale: const Locale('es', 'ES'),
      helpText: 'Selecciona rango de fechas',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (rango != null) setState(() => _rangoFechas = rango);
  }

  void _limpiarFiltros() {
    setState(() {
      _busqueda = '';
      _filtroTipo = 'todos';
      _cuentaIdFiltro = null;
      _rangoFechas = null;
      _displayLimit = 50;
    });
  }

  Future<void> _exportar(String formato, List<Transaccion> transacciones) async {
    final categorias = await widget.database.select(widget.database.categorias).get();
    final cuentas = await widget.database.select(widget.database.cuentas).get();

    final periodo = _rangoFechas != null
        ? '${_dateFormat.format(_rangoFechas!.start)} – ${_dateFormat.format(_rangoFechas!.end)}'
        : null;

    if (!mounted) return;

    try {
      if (formato == 'csv') {
        await ExportacionService.exportarTransaccionesCSV(
          transacciones: transacciones,
          categorias: categorias,
          cuentas: cuentas,
          periodoLabel: periodo,
        );
      } else {
        await ExportacionService.exportarTransaccionesPDF(
          transacciones: transacciones,
          categorias: categorias,
          cuentas: cuentas,
          periodoLabel: periodo,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: AppTheme.alertDanger,
          ),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return AppEmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No hay transacciones registradas',
      subtitle: 'Comienza registrando tu primera transacción',
      buttonLabel: 'Agregar Transacción',
      onAction: () => _showAddTransaccionDialog(),
    );
  }

  Widget _buildTransaccionCard(Transaccion transaccion) {
    final isIngreso = transaccion.tipo == 'ingreso';
    final color = isIngreso ? AppTheme.incomeColor : AppTheme.expenseColor;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListTile(
        leading: AppSemanticIcon(
          icon: isIngreso ? Icons.arrow_downward : Icons.arrow_upward,
          color: color,
          size: AppIconSize.sm,
        ),
        title: Text(
          transaccion.descripcion,
          style: theme.textTheme.labelLarge,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _dateFormat.format(transaccion.fecha),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            if (transaccion.formaPago == 'credito')
              Row(
                children: [
                  Icon(Icons.credit_card, size: 12,
                      color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    '${transaccion.cantidadCuotas} cuotas',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            if (transaccion.esPrestamo)
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.alertCaution.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smBR,
                ),
                child: Text(
                  'PRÉSTAMO',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.alertWarning,
                    fontSize: 9,
                  ),
                ),
              ),
          ],
        ),
        trailing: Text(
          '${isIngreso ? '+' : '-'}${Formatters.monedaConSimbolo(transaccion.montoTotal)}',
          style: theme.textTheme.titleMedium?.copyWith(color: color),
        ),
        onTap: () => _showTransaccionDetails(transaccion),
        onLongPress: () => _showEditTransaccionDialog(transaccion),
      ),
    );
  }

  void _showAddTransaccionDialog() async {
    // Obtener datos necesarios
    final cuentas = await widget.database.select(widget.database.cuentas).get();
    final categorias = await widget.database.select(widget.database.categorias).get();
    final personas = await widget.database.select(widget.database.personas).get();
    final todasDeudas = await (widget.database.select(widget.database.deudas)
          ..where((d) => d.estado.isNotIn(['pagada'])))
        .get();

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
    // Variables de estado
    String tipoTransaccion = 'egreso';
    String formaPago = 'debito';
    bool esPrestamo = false;
    bool gastoCompartido = false;
    Set<int> personasCompartidasIds = {};
    bool incluirme = true;
    Cuenta? cuentaSeleccionada = cuentas.first;
    Categoria? categoriaSeleccionada = categorias.where((c) => c.tipo == 'egreso').first;
    Persona? personaSeleccionada;
    // Cobro de préstamo (solo ingresos)
    bool esCobro = false;
    Persona? personaCobro;
    Deuda? deudaCobro;
    List<Deuda> deudasPersonaCobro = [];

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
                    key: ValueKey(tipoTransaccion),
                    initialValue: tipoTransaccion,
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
                        // Limpiar cobro si cambia a egreso
                        if (tipoTransaccion == 'egreso') {
                          esCobro = false;
                          personaCobro = null;
                          deudaCobro = null;
                          deudasPersonaCobro = [];
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
                    key: ValueKey(cuentaSeleccionada),
                    initialValue: cuentaSeleccionada,
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
                    key: ValueKey(categoriaSeleccionada),
                    initialValue: categoriaSeleccionada,
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

                  // ── Cobro de préstamo (solo ingresos) ────────────────────
                  if (tipoTransaccion == 'ingreso') ...[
                    const Divider(),
                    CheckboxListTile(
                      title: const Text('Es cobro de préstamo'),
                      subtitle: const Text('Vincula este ingreso al pago de una deuda'),
                      value: esCobro,
                      onChanged: (v) => setDialogState(() {
                        esCobro = v ?? false;
                        if (!esCobro) {
                          personaCobro = null;
                          deudaCobro = null;
                          deudasPersonaCobro = [];
                        }
                      }),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (esCobro) ...[
                      if (personas.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'No hay personas registradas.',
                            style: TextStyle(color: Colors.red[700], fontSize: 12),
                          ),
                        )
                      else
                        DropdownButtonFormField<Persona>(
                          key: ValueKey(personaCobro),
                          initialValue: personaCobro,
                          decoration: const InputDecoration(
                            labelText: 'Persona que paga',
                            prefixIcon: Icon(Icons.person),
                          ),
                          items: personas
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p.nombre),
                                  ))
                              .toList(),
                          onChanged: (v) => setDialogState(() {
                            personaCobro = v;
                            deudaCobro = null;
                            deudasPersonaCobro = todasDeudas
                                .where((d) => d.personaId == v?.id)
                                .toList();
                          }),
                        ),
                      if (personaCobro != null) ...[
                        const SizedBox(height: 16),
                        if (deudasPersonaCobro.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '${personaCobro!.nombre} no tiene deudas pendientes.',
                              style: TextStyle(
                                  color: Colors.orange[700], fontSize: 12),
                            ),
                          )
                        else
                          DropdownButtonFormField<Deuda>(
                            key: ValueKey(deudaCobro),
                            initialValue: deudaCobro,
                            decoration: const InputDecoration(
                              labelText: 'Deuda a saldar',
                              prefixIcon: Icon(Icons.receipt_long),
                            ),
                            items: deudasPersonaCobro
                                .map((d) => DropdownMenuItem(
                                      value: d,
                                      child: Text(
                                        '${Formatters.monedaConSimbolo(d.montoPendiente)} — ${d.tipo == 'cuotas' ? 'cuotas' : 'pago único'}',
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) => setDialogState(() {
                              deudaCobro = v;
                              if (v != null) {
                                montoController.text =
                                    v.montoPendiente.toStringAsFixed(2);
                              }
                            }),
                          ),
                      ],
                    ],
                  ],

                  // Forma de pago (solo si la cuenta lo permite)
                  if (permiteCuotas) ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey(formaPago),
                      initialValue: formaPago,
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
                        if (esPrestamo) {
                          gastoCompartido = false;
                          personasCompartidasIds.clear();
                        }
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
                        key: ValueKey(personaSeleccionada),
                        initialValue: personaSeleccionada,
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

                  // ── Gasto compartido (solo egresos, incompatible con préstamo) ─
                  if (tipoTransaccion == 'egreso' && !esPrestamo) ...[
                    const Divider(),
                    CheckboxListTile(
                      title: const Text('Gasto compartido'),
                      subtitle: const Text('Divide el gasto entre varias personas'),
                      value: gastoCompartido,
                      onChanged: (v) => setDialogState(() {
                        gastoCompartido = v ?? false;
                        if (!gastoCompartido) personasCompartidasIds.clear();
                      }),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (gastoCompartido) ...[
                      if (personas.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'No hay personas registradas para compartir el gasto.',
                            style: TextStyle(color: Colors.red[700], fontSize: 12),
                          ),
                        )
                      else ...[
                        const SizedBox(height: 4),
                        ...personas.map((p) => CheckboxListTile(
                              title: Text(p.nombre),
                              value: personasCompartidasIds.contains(p.id),
                              onChanged: (v) => setDialogState(() {
                                if (v == true) {
                                  personasCompartidasIds.add(p.id);
                                } else {
                                  personasCompartidasIds.remove(p.id);
                                }
                              }),
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                            )),
                        SwitchListTile(
                          title: const Text('Incluirme en el reparto'),
                          value: incluirme,
                          onChanged: (v) => setDialogState(() => incluirme = v),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                        if (personasCompartidasIds.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Builder(builder: (ctx) {
                            final total = double.tryParse(montoController.text) ?? 0.0;
                            final n = personasCompartidasIds.length + (incluirme ? 1 : 0);
                            final share = n > 0 ? total / n : 0.0;
                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  ...personas
                                      .where((p) => personasCompartidasIds.contains(p.id))
                                      .map((p) => Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(p.nombre, style: Theme.of(ctx).textTheme.bodySmall),
                                              Text(Formatters.monedaConSimbolo(share),
                                                  style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                                                        fontWeight: FontWeight.bold,
                                                      )),
                                            ],
                                          )),
                                  if (incluirme)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Yo', style: Theme.of(ctx).textTheme.bodySmall),
                                        Text(Formatters.monedaConSimbolo(share),
                                            style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.incomeColor,
                                                )),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
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
                  final total = double.tryParse(montoController.text) ?? 0.0;
                  final n = personasCompartidasIds.length + (incluirme ? 1 : 0);
                  final double share = n > 0 ? total / n : 0.0;
                  final List<({Persona persona, double monto})>? personasCompartidas = gastoCompartido
                      ? personas
                          .where((p) => personasCompartidasIds.contains(p.id))
                          .map((p) => (persona: p, monto: share))
                          .toList()
                      : null;

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
                    gastosCompartidos: personasCompartidas,
                    deudaCobro: deudaCobro,
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
                    key: ValueKey(categoriaSeleccionada),
                    initialValue: categoriaSeleccionada,
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
    List<({Persona persona, double monto})>? gastosCompartidos,
    Deuda? deudaCobro,
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

      // Gastos compartidos: sub-transacciones por persona sin tocar el saldo
      if (gastosCompartidos != null && gastosCompartidos.isNotEmpty) {
        for (final compartido in gastosCompartidos) {
          final subId = await widget.database.into(widget.database.transacciones).insert(
            TransaccionesCompanion.insert(
              tipo: 'egreso',
              descripcion: '$descripcion (${compartido.persona.nombre})',
              montoTotal: compartido.monto,
              formaPago: 'debito',
              fecha: DateTime.now(),
              cuentaId: cuenta.id,
              categoriaId: categoria.id,
              esPrestamo: const drift.Value(true),
              personaId: drift.Value(compartido.persona.id),
            ),
          );
          await _crearDeudaDesdeTransaccion(
            personaId: compartido.persona.id,
            transaccionId: subId,
            tipo: 'simple',
            montoTotal: compartido.monto,
          );
        }
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

      // Vincular con deuda si es un cobro de préstamo
      if (deudaCobro != null) {
        await widget.database.vincularPagoConDeuda(
          deudaId: deudaCobro.id,
          transaccionId: transaccionId,
          monto: montoValue,
        );
      }
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