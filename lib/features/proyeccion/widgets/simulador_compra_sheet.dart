import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../models/simulacion_models.dart';

/// Modal para configurar una compra simulada en cuotas
class SimuladorCompraSheet extends StatefulWidget {
  final CompraSimulada? compraActual;
  final DateTime mesInicioProyeccion;

  const SimuladorCompraSheet({
    super.key,
    this.compraActual,
    required this.mesInicioProyeccion,
  });

  @override
  State<SimuladorCompraSheet> createState() => _SimuladorCompraSheetState();
}

class _SimuladorCompraSheetState extends State<SimuladorCompraSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();
  final _montoController = TextEditingController();

  int _cuotasSeleccionadas = 12;
  late DateTime _mesInicio;

  // Opciones de cuotas disponibles
  static const _opcionesCuotas = [1, 3, 6, 9, 12, 18, 24, 36, 48];

  @override
  void initState() {
    super.initState();

    if (widget.compraActual != null) {
      // Editar simulación existente
      _descripcionController.text = widget.compraActual!.descripcion;
      _montoController.text =
          widget.compraActual!.montoTotal.toStringAsFixed(0);
      _cuotasSeleccionadas = widget.compraActual!.cantidadCuotas;
      _mesInicio = widget.compraActual!.mesInicio;
    } else {
      // Nueva simulación: mes siguiente por defecto
      _mesInicio = DateTime(
        widget.mesInicioProyeccion.year,
        widget.mesInicioProyeccion.month + 1,
        1,
      );
    }
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  double get _montoTotal {
    return double.tryParse(_montoController.text.replaceAll('.', '')) ?? 0;
  }

  double get _montoCuota {
    if (_montoTotal == 0) return 0;
    return _montoTotal / _cuotasSeleccionadas;
  }

  void _aplicarSimulacion() {
    if (_formKey.currentState!.validate()) {
      final compra = CompraSimulada(
        descripcion: _descripcionController.text.trim(),
        montoTotal: _montoTotal,
        cantidadCuotas: _cuotasSeleccionadas,
        mesInicio: _mesInicio,
      );
      Navigator.of(context).pop(compra);
    }
  }

  void _limpiarSimulacion() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ResponsiveHelper.wrapModal(
      context: context,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIconsRegular.calculator,
                        size: 28,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Simular Compra en Cuotas',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: PhosphorIcon(PhosphorIconsRegular.x),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Descripción
                  TextFormField(
                    controller: _descripcionController,
                    decoration: InputDecoration(
                      labelText: 'Descripción de la compra',
                      hintText: 'Ej: PlayStation 5, Smart TV, etc.',
                      prefixIcon: PhosphorIcon(PhosphorIconsRegular.tag),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.lgBR,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa una descripción';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Monto Total
                  TextFormField(
                    controller: _montoController,
                    decoration: InputDecoration(
                      labelText: 'Monto total',
                      hintText: '0',
                      prefixText: '\$ ',
                      prefixIcon: PhosphorIcon(PhosphorIconsRegular.currencyDollar),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.lgBR,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa el monto';
                      }
                      final monto = double.tryParse(value.replaceAll('.', ''));
                      if (monto == null || monto <= 0) {
                        return 'Ingresa un monto válido';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}), // Recalcular cuota
                  ),

                  const SizedBox(height: 20),

                  // Número de Cuotas
                  Text(
                    'Número de cuotas',
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _opcionesCuotas.map((cuotas) {
                      final isSelected = cuotas == _cuotasSeleccionadas;
                      return ChoiceChip(
                        label: Text('$cuotas'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _cuotasSeleccionadas = cuotas);
                          }
                        },
                        selectedColor: scheme.primary.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? scheme.primary : scheme.onSurface,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Mes de inicio
                  Text(
                    'Mes de inicio del cobro',
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<DateTime>(
                    initialValue: _mesInicio,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.lgBR,
                      ),
                      prefixIcon: PhosphorIcon(PhosphorIconsRegular.calendar),
                    ),
                    items: _generarMesesDisponibles(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _mesInicio = value);
                      }
                    },
                  ),

                  const SizedBox(height: 24),

                  // Resumen de la cuota
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      borderRadius: AppRadius.xlBR,
                      border: Border.all(
                        color: scheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Valor cuota mensual',
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              Formatters.monedaConSimbolo(_montoCuota),
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.creditColor(context),
                              ),
                            ),
                          ],
                        ),
                        if (_montoTotal > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${Formatters.monedaConSimbolo(_montoTotal)} ÷ $_cuotasSeleccionadas cuotas',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Botones
                  Row(
                    children: [
                      if (widget.compraActual != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _limpiarSimulacion,
                            icon: PhosphorIcon(PhosphorIconsRegular.trash),
                            label: const Text('Limpiar'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              foregroundColor: AppTheme.expenseColor(context),
                              side: BorderSide(
                                color: AppTheme.expenseColor(context),
                              ),
                            ),
                          ),
                        ),
                      if (widget.compraActual != null) const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _aplicarSimulacion,
                          icon: PhosphorIcon(PhosphorIconsRegular.play),
                          label: const Text('Aplicar Simulación'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<DateTime>> _generarMesesDisponibles() {
    final meses = <DropdownMenuItem<DateTime>>[];
    for (int i = 0; i < 24; i++) {
      final mes = DateTime(
        widget.mesInicioProyeccion.year,
        widget.mesInicioProyeccion.month + i,
        1,
      );
      meses.add(DropdownMenuItem(
        value: mes,
        child: Text(_formatearMes(mes)),
      ));
    }
    return meses;
  }

  String _formatearMes(DateTime mes) {
    const meses = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic'
    ];
    return '${meses[mes.month - 1]} ${mes.year}';
  }
}
