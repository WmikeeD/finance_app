import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift hide Column;
import '../../core/database/database.dart';
import '../../core/services/exportacion_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../cuentas/cuentas_screen.dart';

class TransaccionesScreen extends StatefulWidget {
  final AppDatabase database;

  const TransaccionesScreen({super.key, required this.database});

  @override
  State<TransaccionesScreen> createState() => _TransaccionesScreenState();
}

class _TransaccionesScreenState extends State<TransaccionesScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final TextEditingController _searchController = TextEditingController();

  String _busqueda = '';
  String _filtroTipo = 'todos';
  int? _cuentaIdFiltro;
  DateTimeRange? _rangoFechas;
  int _displayLimit = 50;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Transaccion> _aplicarFiltros(List<Transaccion> todas) {
    return todas.where((t) {
      if (_filtroTipo != 'todos' && t.tipo != _filtroTipo) return false;
      if (_cuentaIdFiltro != null && t.cuentaId != _cuentaIdFiltro) {
        return false;
      }
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
            stream:
                widget.database.select(widget.database.transacciones).watch(),
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
          preferredSize: const Size.fromHeight(116),
          child: _buildFiltrosBar(),
        ),
      ),
      body: StreamBuilder<List<Categoria>>(
        stream: widget.database.select(widget.database.categorias).watch(),
        builder: (context, catSnap) {
          final categorias = catSnap.data ?? [];
          return StreamBuilder<List<Transaccion>>(
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
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.base),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => setState(() => _displayLimit += 50),
                          icon: const Icon(Icons.expand_more),
                          label: Text(
                            'Cargar más (${transacciones.length - _displayLimit} restantes)',
                          ),
                        ),
                      ),
                    );
                  }
                  return _buildTransaccionCard(visibles[index], categorias);
                },
              );
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

  // ── Filter bar ──────────────────────────────────────────────────────────────

  Widget _buildFiltrosBar() {
    return StreamBuilder<List<Cuenta>>(
      stream: widget.database.select(widget.database.cuentas).watch(),
      builder: (context, cuentasSnap) {
        final cuentas = cuentasSnap.data ?? [];
        final nombreCuenta = _cuentaIdFiltro != null
            ? cuentas
                .firstWhere(
                  (c) => c.id == _cuentaIdFiltro,
                  orElse: () => cuentas.first,
                )
                .nombre
            : null;
        final hayFiltros = _filtroTipo != 'todos' ||
            _cuentaIdFiltro != null ||
            _rangoFechas != null;
        final rangoLabel = _rangoFechas != null
            ? '${_dateFormat.format(_rangoFechas!.start)} – ${_dateFormat.format(_rangoFechas!.end)}'
            : 'Fecha';

        return Container(
          color: Theme.of(context).appBarTheme.backgroundColor,
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppFilterBar(
            showSearch: true,
            searchHint: 'Buscar por descripción...',
            searchController: _searchController,
            onSearchChanged: (v) => setState(() => _busqueda = v),
            chips: [
              AppFilterChipData(
                label: 'Todos',
                selected: _filtroTipo == 'todos',
                onTap: () => setState(() => _filtroTipo = 'todos'),
              ),
              AppFilterChipData(
                label: 'Ingresos',
                selected: _filtroTipo == 'ingreso',
                color: AppTheme.incomeColor(context),
                onTap: () => setState(() => _filtroTipo = 'ingreso'),
              ),
              AppFilterChipData(
                label: 'Egresos',
                selected: _filtroTipo == 'egreso',
                color: AppTheme.expenseColor(context),
                onTap: () => setState(() => _filtroTipo = 'egreso'),
              ),
              if (cuentas.isNotEmpty)
                AppFilterChipData(
                  label: nombreCuenta ?? 'Cuenta',
                  selected: _cuentaIdFiltro != null,
                  avatar: const Icon(Icons.account_balance_wallet, size: 14),
                  onTap: () => _showCuentaFilterSheet(cuentas),
                ),
              AppFilterChipData(
                label: rangoLabel,
                selected: _rangoFechas != null,
                avatar: const Icon(Icons.date_range, size: 14),
                onTap: () => _showDateRangePicker(),
              ),
              if (hayFiltros)
                AppFilterChipData(
                  label: 'Limpiar',
                  selected: false,
                  avatar: const Icon(Icons.clear, size: 14),
                  onTap: _limpiarFiltros,
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCuentaFilterSheet(List<Cuenta> cuentas) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Text(
              'Filtrar por cuenta',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          ListTile(
            title: const Text('Todas las cuentas'),
            leading: const Icon(Icons.all_inclusive),
            selected: _cuentaIdFiltro == null,
            onTap: () {
              setState(() => _cuentaIdFiltro = null);
              Navigator.pop(ctx);
            },
          ),
          ...cuentas.map((c) => ListTile(
                title: Text(c.nombre),
                subtitle: Text(c.tipo),
                leading: const Icon(Icons.account_balance_wallet),
                selected: _cuentaIdFiltro == c.id,
                onTap: () {
                  setState(() => _cuentaIdFiltro = c.id);
                  Navigator.pop(ctx);
                },
              )),
          const SizedBox(height: AppSpacing.base),
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
    _searchController.clear();
    setState(() {
      _busqueda = '';
      _filtroTipo = 'todos';
      _cuentaIdFiltro = null;
      _rangoFechas = null;
      _displayLimit = 50;
    });
  }

  // ── Export ──────────────────────────────────────────────────────────────────

  Future<void> _exportar(
      String formato, List<Transaccion> transacciones) async {
    final categorias =
        await widget.database.select(widget.database.categorias).get();
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
            backgroundColor: AppColors.alertDanger,
          ),
        );
      }
    }
  }

  // ── List items ──────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return AppEmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No hay transacciones registradas',
      subtitle: 'Comienza registrando tu primera transacción',
      buttonLabel: 'Agregar Transacción',
      onAction: () => _showAddTransaccionDialog(),
    );
  }

  Widget _buildTransaccionCard(
      Transaccion transaccion, List<Categoria> categorias) {
    final isIngreso = transaccion.tipo == 'ingreso';
    final isCredito = transaccion.formaPago == 'credito';
    final categoria =
        categorias.where((c) => c.id == transaccion.categoriaId).firstOrNull;

    final type = isIngreso
        ? TransactionType.income
        : isCredito
            ? TransactionType.credit
            : TransactionType.expense;

    String? installmentInfo;
    if (isCredito && transaccion.cantidadCuotas != null) {
      installmentInfo = '${transaccion.cantidadCuotas} cuotas';
    } else if (transaccion.esPrestamo) {
      installmentInfo = 'préstamo';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onLongPress: () => _showEditTransaccionDialog(transaccion),
        child: TransactionListItem(
          type: type,
          description: transaccion.descripcion,
          category: categoria?.nombre ?? '',
          date: transaccion.fecha,
          amount: isIngreso ? transaccion.montoTotal : -transaccion.montoTotal,
          installmentInfo: installmentInfo,
          onTap: () => _showTransaccionDetails(transaccion),
        ),
      ),
    );
  }

  // ── Add transaction dialog ──────────────────────────────────────────────────

  void _showAddTransaccionDialog() async {
    final cuentas = await widget.database.select(widget.database.cuentas).get();
    final categorias =
        await widget.database.select(widget.database.categorias).get();
    final personas =
        await widget.database.select(widget.database.personas).get();
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
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => ResponsiveHelper.wrapModal(
                  context: context,
                  child: CuentasScreen(database: widget.database),
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
        const SnackBar(
            content: Text('Primero debes crear al menos una categoría')),
      );
      return;
    }

    final descripcionController = TextEditingController();
    final montoController = TextEditingController();
    final cuotasController = TextEditingController();
    final valorCuotaController = TextEditingController();
    String tipoTransaccion = 'egreso';
    String formaPago = 'debito';
    bool esPrestamo = false;
    bool gastoCompartido = false;
    Set<int> personasCompartidasIds = {};
    bool incluirme = true;
    Cuenta? cuentaSeleccionada = cuentas.first;
    Categoria? categoriaSeleccionada =
        categorias.where((c) => c.tipo == 'egreso').first;
    Persona? personaSeleccionada;
    bool esCobro = false;
    Persona? personaCobro;
    Deuda? deudaCobro;
    List<Deuda> deudasPersonaCobro = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final scheme = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;
          final categoriasDisponibles =
              categorias.where((c) => c.tipo == tipoTransaccion).toList();
          final permiteCuotas = cuentaSeleccionada?.tipo == 'credito';

          return AlertDialog(
            title: const Text('Nueva Transacción'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(tipoTransaccion),
                    initialValue: tipoTransaccion,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      prefixIcon: Icon(Icons.swap_vert),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'ingreso', child: Text('Ingreso')),
                      DropdownMenuItem(value: 'egreso', child: Text('Egreso')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        tipoTransaccion = value!;
                        final nuevasCategorias = categorias
                            .where((c) => c.tipo == tipoTransaccion)
                            .toList();
                        if (nuevasCategorias.isNotEmpty) {
                          categoriaSeleccionada = nuevasCategorias.first;
                        }
                        if (tipoTransaccion == 'egreso') {
                          esCobro = false;
                          personaCobro = null;
                          deudaCobro = null;
                          deudasPersonaCobro = [];
                        }
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.base),

                  TextField(
                    controller: descripcionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Ej: Compra supermercado',
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),

                  TextField(
                    controller: montoController,
                    decoration: const InputDecoration(
                      labelText: 'Monto',
                      prefixText: '\$ ',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.base),

                  DropdownButtonFormField<Cuenta>(
                    key: ValueKey(cuentaSeleccionada),
                    initialValue: cuentaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Cuenta',
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                    items: cuentas.map((cuenta) {
                      return DropdownMenuItem(
                          value: cuenta, child: Text(cuenta.nombre));
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        cuentaSeleccionada = value;
                        if (value?.tipo != 'credito' &&
                            formaPago == 'credito') {
                          formaPago = 'debito';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.base),

                  DropdownButtonFormField<Categoria>(
                    key: ValueKey(categoriaSeleccionada),
                    initialValue: categoriaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: categoriasDisponibles.map((categoria) {
                      return DropdownMenuItem(
                          value: categoria, child: Text(categoria.nombre));
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => categoriaSeleccionada = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // ── Cobro de préstamo (solo ingresos) ──────────────────────
                  if (tipoTransaccion == 'ingreso') ...[
                    const Divider(),
                    CheckboxListTile(
                      title: const Text('Es cobro de préstamo'),
                      subtitle: const Text(
                          'Vincula este ingreso al pago de una deuda'),
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
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs),
                          child: Text(
                            'No hay personas registradas.',
                            style: textTheme.bodySmall
                                ?.copyWith(color: scheme.error),
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
                        const SizedBox(height: AppSpacing.base),
                        if (deudasPersonaCobro.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xs),
                            child: Text(
                              '${personaCobro!.nombre} no tiene deudas pendientes.',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: AppColors.alertWarning),
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

                  // ── Forma de pago (solo cuentas crédito) ───────────────────
                  if (permiteCuotas) ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey(formaPago),
                      initialValue: formaPago,
                      decoration: const InputDecoration(
                        labelText: 'Forma de pago',
                        prefixIcon: Icon(Icons.payment),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'debito', child: Text('Débito (inmediato)')),
                        DropdownMenuItem(
                            value: 'credito', child: Text('Crédito (cuotas)')),
                      ],
                      onChanged: (value) {
                        setDialogState(() => formaPago = value!);
                      },
                    ),
                    const SizedBox(height: AppSpacing.base),
                  ],

                  // ── Cuotas ─────────────────────────────────────────────────
                  if (formaPago == 'credito') ...[
                    const Divider(),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Configuración de Cuotas',
                      style: textTheme.titleSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.base),
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
                    const SizedBox(height: AppSpacing.base),
                    TextField(
                      controller: valorCuotaController,
                      decoration: const InputDecoration(
                        labelText: 'Valor de cada cuota',
                        hintText: 'Según estado de cuenta',
                        prefixText: '\$ ',
                        prefixIcon: Icon(Icons.money),
                        helperText:
                            'El sistema calculará el interés automáticamente',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  // ── Préstamo ───────────────────────────────────────────────
                  const Divider(),
                  CheckboxListTile(
                    title: const Text('Es un préstamo a tercero'),
                    subtitle: const Text(
                        'Pagado con tu cuenta pero lo debe otra persona'),
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

                  if (esPrestamo) ...[
                    if (personas.isEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Text(
                          'No hay personas registradas. Primero crea una persona.',
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.error),
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
                              value: persona, child: Text(persona.nombre));
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => personaSeleccionada = value);
                        },
                      ),
                  ],

                  // ── Gasto compartido ───────────────────────────────────────
                  if (tipoTransaccion == 'egreso' && !esPrestamo) ...[
                    const Divider(),
                    CheckboxListTile(
                      title: const Text('Gasto compartido'),
                      subtitle:
                          const Text('Divide el gasto entre varias personas'),
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
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs),
                          child: Text(
                            'No hay personas registradas para compartir el gasto.',
                            style: textTheme.bodySmall
                                ?.copyWith(color: scheme.error),
                          ),
                        )
                      else ...[
                        const SizedBox(height: AppSpacing.xs),
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
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 0),
                            )),
                        SwitchListTile(
                          title: const Text('Incluirme en el reparto'),
                          value: incluirme,
                          onChanged: (v) => setDialogState(() => incluirme = v),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                        if (personasCompartidasIds.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Builder(builder: (ctx) {
                            final total =
                                double.tryParse(montoController.text) ?? 0.0;
                            final n = personasCompartidasIds.length +
                                (incluirme ? 1 : 0);
                            final share = n > 0 ? total / n : 0.0;
                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Column(
                                children: [
                                  ...personas
                                      .where((p) =>
                                          personasCompartidasIds.contains(p.id))
                                      .map((p) => Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(p.nombre,
                                                  style: Theme.of(ctx)
                                                      .textTheme
                                                      .bodySmall),
                                              Text(
                                                Formatters.monedaConSimbolo(
                                                    share),
                                                style: Theme.of(ctx)
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ],
                                          )),
                                  if (incluirme)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Yo',
                                            style: Theme.of(ctx)
                                                .textTheme
                                                .bodySmall),
                                        Text(
                                          Formatters.monedaConSimbolo(share),
                                          style: Theme.of(ctx)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    AppTheme.incomeColor(ctx),
                                              ),
                                        ),
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
                  final List<({Persona persona, double monto})>?
                      personasCompartidas = gastoCompartido
                          ? personas
                              .where(
                                  (p) => personasCompartidasIds.contains(p.id))
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

  // ── Edit transaction dialog ─────────────────────────────────────────────────

  void _showEditTransaccionDialog(Transaccion transaccion) async {
    final cuenta = await (widget.database.select(widget.database.cuentas)
          ..where((c) => c.id.equals(transaccion.cuentaId)))
        .getSingle();

    final categorias =
        await widget.database.select(widget.database.categorias).get();

    final descripcionController =
        TextEditingController(text: transaccion.descripcion);
    final montoController =
        TextEditingController(text: transaccion.montoTotal.toString());

    Categoria? categoriaSeleccionada = categorias.firstWhere(
      (c) => c.id == transaccion.categoriaId,
      orElse: () => categorias.first,
    );

    DateTime fechaSeleccionada = transaccion.fecha;
    double montoOriginal = transaccion.montoTotal;
    bool editarMonto = false;
    bool editarFecha = false;

    final cuotasPagadas = await (widget.database.select(widget.database.cuotas)
          ..where((c) =>
              c.transaccionId.equals(transaccion.id) & c.pagada.equals(true)))
        .get();

    final tieneCuotasPagadas = cuotasPagadas.isNotEmpty;
    final esCredito = transaccion.formaPago == 'credito';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final scheme = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;

          return AlertDialog(
            title: const Text('Editar Transacción'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cuenta: ${cuenta.nombre}',
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        Text(
                          'Tipo: ${transaccion.tipo}',
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        if (esCredito)
                          Text(
                            '${transaccion.cantidadCuotas} cuotas',
                            style: textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),

                  TextField(
                    controller: descripcionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),

                  DropdownButtonFormField<Categoria>(
                    key: ValueKey(categoriaSeleccionada),
                    initialValue: categoriaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: categorias
                        .where((c) => c.tipo == transaccion.tipo)
                        .map((categoria) {
                      return DropdownMenuItem(
                          value: categoria, child: Text(categoria.nombre));
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => categoriaSeleccionada = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  const Divider(),
                  Text('Edición Avanzada', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),

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
                          SnackBar(
                            content: const Text(
                                'No se puede editar el monto si ya hay cuotas pagadas'),
                            backgroundColor: scheme.error,
                          ),
                        );
                        return;
                      }
                      setDialogState(() => editarMonto = value ?? false);
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
                    const SizedBox(height: AppSpacing.sm),
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
                        ? null
                        : (value) {
                            setDialogState(() => editarFecha = value ?? false);
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
                          setDialogState(() => fechaSeleccionada = nuevaFecha);
                        }
                      },
                    ),
                    if (esCredito) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.alertCaution.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          '⚠️ Al cambiar la fecha, se recalcularán las fechas de vencimiento de las cuotas según el nuevo cierre de tarjeta.',
                          style: textTheme.bodySmall
                              ?.copyWith(color: AppColors.alertWarning),
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
                  final nuevoMonto =
                      double.tryParse(montoController.text) ?? montoOriginal;

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

  // ── Database helpers ────────────────────────────────────────────────────────

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
    int? cantidadCuotas;
    double? valorCuotaValue;
    double? montoConInteres;
    double? interesTotal;

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

    await widget.database.transaction(() async {
      final transaccionId =
          await widget.database.into(widget.database.transacciones).insert(
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

      if (formaPago == 'credito' &&
          cantidadCuotas != null &&
          valorCuotaValue != null) {
        final diaCierre = cuenta.diaCierre;
        final diaPago = cuenta.diaPago;

        if (diaCierre == null || diaPago == null) {
          throw Exception(
              'La cuenta de crédito no tiene configurada la fecha de cierre o pago');
        }

        final fechaCompra = DateTime.now();
        final fechaPrimeraCuota = _calcularFechaPrimeraCuota(
          fechaCompra: fechaCompra,
          diaCierre: diaCierre,
          diaPago: diaPago,
        );

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

      if (gastosCompartidos != null && gastosCompartidos.isNotEmpty) {
        for (final compartido in gastosCompartidos) {
          final subId = await widget.database
              .into(widget.database.transacciones)
              .insert(
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

      double nuevoSaldo = cuenta.saldo;
      if (tipo == 'ingreso') {
        nuevoSaldo += montoValue;
      } else if (tipo == 'egreso') {
        nuevoSaldo -= montoValue;
      }

      await widget.database
          .update(widget.database.cuentas)
          .replace(cuenta.copyWith(saldo: nuevoSaldo));

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

      await widget.database.update(widget.database.transacciones).replace(
            transaccion.copyWith(
              descripcion: nuevaDescripcion,
              categoriaId: nuevaCategoriaId,
              montoTotal: editarMonto ? nuevoMonto : transaccion.montoTotal,
              fecha: editarFecha ? nuevaFecha : transaccion.fecha,
              montoTotalConInteres: (editarMonto && esCredito)
                  ? drift.Value(nuevoMonto *
                      (transaccion.montoTotalConInteres! / montoAnterior))
                  : drift.Value(transaccion.montoTotalConInteres),
              valorCuota: (editarMonto && esCredito)
                  ? drift.Value(nuevoMonto / transaccion.cantidadCuotas!)
                  : drift.Value(transaccion.valorCuota),
            ),
          );

      if (editarMonto && !esCredito) {
        final diferencia = nuevoMonto - montoAnterior;
        double nuevoSaldo = cuenta.saldo;
        if (transaccion.tipo == 'egreso') {
          nuevoSaldo -= diferencia;
        } else if (transaccion.tipo == 'ingreso') {
          nuevoSaldo += diferencia;
        }
        await widget.database
            .update(widget.database.cuentas)
            .replace(cuenta.copyWith(saldo: nuevoSaldo));
      }

      if (editarMonto && esCredito) {
        final cuotasPendientes =
            await (widget.database.select(widget.database.cuotas)
                  ..where((c) =>
                      c.transaccionId.equals(transaccion.id) &
                      c.pagada.equals(false)))
                .get();

        final nuevoValorCuota = nuevoMonto / transaccion.cantidadCuotas!;
        for (final cuota in cuotasPendientes) {
          await widget.database
              .update(widget.database.cuotas)
              .replace(cuota.copyWith(monto: nuevoValorCuota));
        }

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
                ..orderBy(
                    [(c) => drift.OrderingTerm(expression: c.numeroCuota)]))
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

  DateTime _calcularFechaPrimeraCuota({
    required DateTime fechaCompra,
    required int diaCierre,
    required int diaPago,
  }) {
    final year = fechaCompra.year;
    final month = fechaCompra.month;
    final day = fechaCompra.day;

    if (day <= diaCierre) {
      return DateTime(year, month + 1, diaPago);
    } else {
      return DateTime(year, month + 2, diaPago);
    }
  }

  // ── Detail / delete dialog ──────────────────────────────────────────────────

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
              _buildDetailRow(context, 'Tipo', transaccion.tipo.toUpperCase()),
              _buildDetailRow(context, 'Monto',
                  '\$${transaccion.montoTotal.toStringAsFixed(0)}'),
              _buildDetailRow(context, 'Forma de pago', transaccion.formaPago),
              _buildDetailRow(
                  context, 'Fecha', _dateFormat.format(transaccion.fecha)),
              if (transaccion.formaPago == 'credito') ...[
                const Divider(height: 24),
                _buildDetailRow(
                    context, 'Cuotas', transaccion.cantidadCuotas.toString()),
                _buildDetailRow(context, 'Valor cuota',
                    '\$${transaccion.valorCuota?.toStringAsFixed(0) ?? '0'}'),
                if (transaccion.montoTotalConInteres != null)
                  _buildDetailRow(context, 'Total con interés',
                      '\$${transaccion.montoTotalConInteres!.toStringAsFixed(0)}'),
                if (transaccion.interesTotal != null)
                  _buildDetailRow(context, 'Interés',
                      '\$${transaccion.interesTotal!.toStringAsFixed(0)}'),
              ],
              if (transaccion.esPrestamo) ...[
                const Divider(height: 24),
                _buildDetailRow(context, 'Es préstamo', 'Sí'),
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
                  content:
                      const Text('¿Estás seguro de eliminar esta transacción?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        'Eliminar',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (confirmar == true && context.mounted) {
                await widget.database.transaction(() async {
                  final cuenta =
                      await (widget.database.select(widget.database.cuentas)
                            ..where((c) => c.id.equals(transaccion.cuentaId)))
                          .getSingle();

                  double nuevoSaldo = cuenta.saldo;
                  if (transaccion.tipo == 'ingreso') {
                    nuevoSaldo -= transaccion.montoTotal;
                  } else if (transaccion.tipo == 'egreso') {
                    nuevoSaldo += transaccion.montoTotal;
                  }

                  await widget.database
                      .update(widget.database.cuentas)
                      .replace(cuenta.copyWith(saldo: nuevoSaldo));

                  if (transaccion.formaPago == 'credito') {
                    await (widget.database.delete(widget.database.cuotas)
                          ..where(
                              (c) => c.transaccionId.equals(transaccion.id)))
                        .go();
                  }

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
            child: Text(
              'Eliminar',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          Text(value,
              style:
                  textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
