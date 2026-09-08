import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/ocr_service.dart';
import '../../../../core/models/ocr_result.dart';
import '../../../../core/utils/formatters.dart';

/// Modal unificado para crear transacciones con soporte completo para:
/// - Débito/Efectivo/Crédito
/// - Cuotas con cálculo de intereses
/// - Préstamos a terceros
/// - Gastos compartidos
/// - Cobro de deudas
/// - Escaneo OCR de boletas
class CrearTransaccionSheet extends StatefulWidget {
  final AppDatabase database;

  const CrearTransaccionSheet({
    super.key,
    required this.database,
  });

  @override
  State<CrearTransaccionSheet> createState() => _CrearTransaccionSheetState();
}

class _CrearTransaccionSheetState extends State<CrearTransaccionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();
  final _montoController = TextEditingController();
  final _cuotasController = TextEditingController();
  final _valorCuotaController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  String _tipo = 'egreso';
  String _formaPago = 'debito';
  bool _esPrestamo = false;
  bool _gastoCompartido = false;
  bool _esCobro = false;
  bool _incluirme = true;
  final Set<int> _personasCompartidasIds = {};

  Cuenta? _cuentaSeleccionada;
  Cuenta? _cuentaDestino; // Para transferencias
  Categoria? _categoriaSeleccionada;
  Persona? _personaSeleccionada;
  Persona? _personaCobro;
  Deuda? _deudaCobro;
  DateTime _fecha = DateTime.now();

  List<Cuenta> _cuentas = [];
  List<Categoria> _categorias = [];
  List<Persona> _personas = [];
  List<Deuda> _todasDeudas = [];
  List<Deuda> _deudasPersonaCobro = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _montoController.dispose();
    _cuotasController.dispose();
    _valorCuotaController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final cuentas = await widget.database.select(widget.database.cuentas).get();
    final categoriasRaw = await (widget.database.select(widget.database.categorias)
          ..where((c) => c.activa.equals(true)))
        .get();
    final categorias = _deduplicarCategorias(categoriasRaw);
    final personas = await widget.database.select(widget.database.personas).get();
    final todasDeudas = await (widget.database.select(widget.database.deudas)
          ..where((d) => d.estado.isNotIn(['pagada'])))
        .get();

    if (mounted) {
      setState(() {
        _cuentas = cuentas;
        _categorias = categorias;
        _personas = personas;
        _todasDeudas = todasDeudas;
        if (cuentas.isNotEmpty) _cuentaSeleccionada = cuentas.first;
        final categoriasEgreso = categorias.where((c) => c.tipo == 'egreso');
        if (categoriasEgreso.isNotEmpty) {
          _categoriaSeleccionada = categoriasEgreso.first;
        }
      });
    }
  }

  List<Categoria> _deduplicarCategorias(List<Categoria> categorias) {
    final mapa = <String, Categoria>{};
    for (final cat in categorias) {
      final key = '${cat.nombre.toLowerCase()}_${cat.tipo}';
      if (!mapa.containsKey(key)) {
        mapa[key] = cat;
      }
    }
    return mapa.values.toList();
  }

  Future<void> _guardarTransaccion() async {
    if (!_formKey.currentState!.validate()) return;

    // Validación para transferencias
    if (_tipo == 'transferencia') {
      if (_cuentaSeleccionada == null || _cuentaDestino == null) {
        _mostrarError('Selecciona cuenta origen y destino');
        return;
      }
      if (_cuentaSeleccionada!.id == _cuentaDestino!.id) {
        _mostrarError('La cuenta origen y destino deben ser diferentes');
        return;
      }
      if (_categoriaSeleccionada == null) {
        _mostrarError('No se encontró la categoría Transferencia. Recarga la app.');
        return;
      }
    } else {
      if (_cuentaSeleccionada == null || _categoriaSeleccionada == null) {
        _mostrarError('Selecciona cuenta y categoría');
        return;
      }
    }

    final monto = double.tryParse(_montoController.text.replaceAll(',', '.'));
    if (monto == null || monto <= 0) {
      _mostrarError('El monto debe ser mayor a cero');
      return;
    }

    // Validación de techo de pago para transferencias a tarjetas de crédito
    if (_tipo == 'transferencia' && _cuentaDestino?.tipo == 'credito') {
      final deudaReal = await widget.database.calcularDeudaRealTarjeta(_cuentaDestino!.id);

      if (deudaReal <= 0) {
        _mostrarError('La tarjeta no tiene deuda pendiente');
        return;
      }

      if (monto > deudaReal) {
        _mostrarError('Excede la deuda (\$${Formatters.moneda(deudaReal)})');
        return;
      }
    }

    int? cantidadCuotas;
    double? valorCuotaValue;
    double? montoConInteres;
    double? interesTotal;

    if (_formaPago == 'credito') {
      cantidadCuotas = int.tryParse(_cuotasController.text);
      valorCuotaValue = double.tryParse(_valorCuotaController.text);

      if (cantidadCuotas == null || cantidadCuotas <= 0) {
        _mostrarError('Ingresa un número de cuotas válido');
        return;
      }

      if (valorCuotaValue == null || valorCuotaValue <= 0) {
        _mostrarError('Ingresa el valor de la cuota');
        return;
      }

      montoConInteres = valorCuotaValue * cantidadCuotas;
      interesTotal = montoConInteres - monto;
    }

    if (_esPrestamo && _personaSeleccionada == null) {
      _mostrarError('Selecciona la persona que debe');
      return;
    }

    try {
      await widget.database.transaction(() async {
        // Generar UUID único para transferencias
        String? transferenciaId;
        if (_tipo == 'transferencia') {
          transferenciaId = const Uuid().v4();
        }

        final transaccionId =
            await widget.database.into(widget.database.transacciones).insert(
                  TransaccionesCompanion.insert(
                    tipo: _tipo,
                    descripcion: _descripcionController.text.trim(),
                    montoTotal: monto,
                    formaPago: _formaPago,
                    fecha: _fecha,
                    cuentaId: _cuentaSeleccionada!.id,
                    categoriaId: _categoriaSeleccionada!.id,
                    esPrestamo: drift.Value(_esPrestamo),
                    personaId: drift.Value(_personaSeleccionada?.id),
                    cuentaDestinoId: drift.Value(_cuentaDestino?.id),
                    transferenciaId: drift.Value(transferenciaId),
                    cantidadCuotas: drift.Value(cantidadCuotas),
                    valorCuota: drift.Value(valorCuotaValue),
                    montoTotalConInteres: drift.Value(montoConInteres),
                    interesTotal: drift.Value(interesTotal),
                  ),
                );

        // Crear cuotas si es crédito
        if (_formaPago == 'credito' &&
            cantidadCuotas != null &&
            valorCuotaValue != null) {
          final diaCierre = _cuentaSeleccionada!.diaCierre;
          final diaPago = _cuentaSeleccionada!.diaPago;

          if (diaCierre == null || diaPago == null) {
            throw Exception(
                'La cuenta de crédito no tiene configurada la fecha de cierre o pago');
          }

          final fechaPrimeraCuota = _calcularFechaPrimeraCuota(
            fechaCompra: _fecha,
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

        // Crear deuda si es préstamo
        if (_esPrestamo && _personaSeleccionada != null) {
          await widget.database.into(widget.database.deudas).insert(
                DeudasCompanion.insert(
                  personaId: _personaSeleccionada!.id,
                  transaccionId: transaccionId,
                  tipo: _formaPago == 'credito' ? 'cuotas' : 'simple',
                  montoTotal:
                      _formaPago == 'credito' ? montoConInteres! : monto,
                  montoPendiente:
                      _formaPago == 'credito' ? montoConInteres! : monto,
                ),
              );
        }

        // Crear deudas para gastos compartidos
        if (_gastoCompartido && _personasCompartidasIds.isNotEmpty) {
          final n = _personasCompartidasIds.length + (_incluirme ? 1 : 0);
          final share = monto / n;

          for (final personaId in _personasCompartidasIds) {
            final persona =
                _personas.firstWhere((p) => p.id == personaId);
            final subId = await widget.database
                .into(widget.database.transacciones)
                .insert(
                  TransaccionesCompanion.insert(
                    tipo: 'egreso',
                    descripcion:
                        '${_descripcionController.text.trim()} (${persona.nombre})',
                    montoTotal: share,
                    formaPago: 'debito',
                    fecha: _fecha,
                    cuentaId: _cuentaSeleccionada!.id,
                    categoriaId: _categoriaSeleccionada!.id,
                    esPrestamo: const drift.Value(true),
                    personaId: drift.Value(persona.id),
                  ),
                );

            await widget.database.into(widget.database.deudas).insert(
                  DeudasCompanion.insert(
                    personaId: persona.id,
                    transaccionId: subId,
                    tipo: 'simple',
                    montoTotal: share,
                    montoPendiente: share,
                  ),
                );
          }
        }

        // Actualizar saldo de cuenta
        // Recalcular saldo de la cuenta origen
        await widget.database.recalcularSaldoCuenta(_cuentaSeleccionada!.id);

        // Para transferencias, recalcular también cuenta destino
        if (_tipo == 'transferencia' && _cuentaDestino != null) {
          // Si es transferencia a tarjeta de crédito, amortizar cuotas
          if (_cuentaDestino!.tipo == 'credito') {
            await widget.database.amortizarCuotasPorAbono(
              _cuentaDestino!.id,
              monto,
            );
          }

          await widget.database.recalcularSaldoCuenta(_cuentaDestino!.id);
        }

        // Vincular pago con deuda si es cobro
        if (_esCobro && _deudaCobro != null) {
          await widget.database.vincularPagoConDeuda(
            deudaId: _deudaCobro!.id,
            transaccionId: transaccionId,
            monto: monto,
          );
        }
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transacción creada exitosamente'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _mostrarError('Error al guardar la transacción: $e');
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _fecha) {
      setState(() => _fecha = picked);
    }
  }

  Future<void> _escanearBoleta() async {
    final scheme = Theme.of(context).colorScheme;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  PhosphorIcon(PhosphorIconsRegular.camera, color: scheme.primary),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading:
                  PhosphorIcon(PhosphorIconsRegular.image, color: scheme.primary),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);

    if (image == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final ocrService = OcrService();
      final result = await ocrService.processImage(image.path);

      if (!mounted) return;
      Navigator.pop(context);

      switch (result.status) {
        case OcrStatus.success:
        case OcrStatus.partial:
          final draft = result.draft!;
          setState(() {
            if (draft.monto != null) {
              _montoController.text = draft.monto!.toStringAsFixed(0);
            }
            if (draft.descripcion != null) {
              _descripcionController.text = draft.descripcion!;
            }
            if (draft.fecha != null) {
              _fecha = draft.fecha!;
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  PhosphorIcon(PhosphorIconsRegular.checkCircle,
                      color: Colors.white),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      result.status == OcrStatus.success
                          ? 'Datos extraídos de la boleta'
                          : 'Datos parciales extraídos. Completa los campos faltantes.',
                    ),
                  ),
                ],
              ),
              backgroundColor: scheme.tertiary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
          break;

        case OcrStatus.unrecognized:
        case OcrStatus.error:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  PhosphorIcon(PhosphorIconsRegular.warning,
                      color: Colors.white),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(result.status.getUserMessage(result)),
                  ),
                ],
              ),
              backgroundColor: scheme.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
          break;
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar imagen: $e'),
          backgroundColor: scheme.error,
        ),
      );
    }
  }

  DateTime _calcularFechaPrimeraCuota({
    required DateTime fechaCompra,
    required int diaCierre,
    required int diaPago,
  }) {
    final year = fechaCompra.year;
    final month = fechaCompra.month;
    final day = fechaCompra.day;

    // REGLA DEL DÍA BORDE (FASE 1 - CICLO BANCARIO):
    // - Si compra >= diaCierre: entra al ciclo siguiente → vence en 2 meses
    // - Si compra < diaCierre: entra al ciclo actual → vence en 1 mes
    if (day >= diaCierre) {
      // Compra en o después del cierre → ciclo siguiente
      return DateTime(year, month + 2, diaPago);
    } else {
      // Compra antes del cierre → ciclo actual
      return DateTime(year, month + 1, diaPago);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final categoriasDisponibles =
        _categorias.where((c) => c.tipo == _tipo).toList();
    final permiteCuotas = _cuentaSeleccionada?.tipo == 'credito';

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.base,
        right: AppSpacing.base,
        top: AppSpacing.base,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.base,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.base),
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Título con botón de escaneo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Nueva Transacción',
                      style: textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _escanearBoleta,
                    icon: PhosphorIcon(PhosphorIconsRegular.scan),
                    tooltip: 'Escanear boleta',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Tipo de transacción
              DropdownButtonFormField<String>(
                key: ValueKey(_tipo),
                initialValue: _tipo,
                decoration: InputDecoration(
                  labelText: 'Tipo',
                  prefixIcon: PhosphorIcon(PhosphorIconsRegular.arrowsDownUp),
                ),
                items: const [
                  DropdownMenuItem(value: 'ingreso', child: Text('Ingreso')),
                  DropdownMenuItem(value: 'egreso', child: Text('Egreso')),
                  DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                ],
                onChanged: (value) {
                  setState(() {
                    _tipo = value!;
                    if (_tipo == 'transferencia') {
                      // Para transferencias, usar categoría "Transferencia"
                      _categoriaSeleccionada = _categorias
                          .where((c) => c.nombre == 'Transferencia' && c.tipo == 'ingreso')
                          .firstOrNull;
                      _formaPago = 'debito'; // Transferencias siempre son débito
                      _esPrestamo = false;
                      _gastoCompartido = false;
                      _esCobro = false;
                      _cuentaDestino = _cuentas.length > 1 ? _cuentas[1] : null;
                    } else {
                      final nuevasCategorias =
                          _categorias.where((c) => c.tipo == _tipo).toList();
                      if (nuevasCategorias.isNotEmpty) {
                        _categoriaSeleccionada = nuevasCategorias.first;
                      } else {
                        _categoriaSeleccionada = null;
                      }
                      _cuentaDestino = null;
                    }

                    // Si se seleccionó ingreso y la cuenta actual es de crédito,
                    // resetear a la primera cuenta líquida disponible
                    if (_tipo == 'ingreso' && _cuentaSeleccionada?.tipo == 'credito') {
                      final cuentasLiquidas = _cuentas.where((c) => c.tipo != 'credito').toList();
                      if (cuentasLiquidas.isNotEmpty) {
                        _cuentaSeleccionada = cuentasLiquidas.first;
                      }
                    }

                    if (_tipo == 'egreso') {
                      _esCobro = false;
                      _personaCobro = null;
                      _deudaCobro = null;
                      _deudasPersonaCobro = [];
                    }
                  });
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Descripción
              TextFormField(
                controller: _descripcionController,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Ej: Compra supermercado',
                  prefixIcon: PhosphorIcon(PhosphorIconsRegular.textT),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'La descripción es requerida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Monto
              TextFormField(
                controller: _montoController,
                decoration: InputDecoration(
                  labelText: 'Monto',
                  prefixText: '\$ ',
                  prefixIcon:
                      PhosphorIcon(PhosphorIconsRegular.currencyCircleDollar),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El monto es requerido';
                  }
                  final monto = double.tryParse(value.replaceAll(',', '.'));
                  if (monto == null || monto <= 0) {
                    return 'Ingresa un monto válido';
                  }

                  // Validación de techo de pago para transferencias a tarjetas de crédito
                  // NOTA: Esta validación es asíncrona pero FormField.validator debe ser síncrona.
                  // La validación real se hace en _guardarTransaccion(), aquí solo validamos formato.

                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Cuenta
              DropdownButtonFormField<Cuenta>(
                key: ValueKey(_cuentaSeleccionada),
                initialValue: _cuentaSeleccionada,
                decoration: InputDecoration(
                  labelText: 'Cuenta',
                  prefixIcon: PhosphorIcon(PhosphorIconsRegular.wallet),
                  helperText: _tipo == 'ingreso'
                      ? 'Solo cuentas de efectivo/débito'
                      : null,
                  helperMaxLines: 2,
                ),
                items: _cuentas
                    .where((cuenta) =>
                        // Filtrar cuentas de crédito si es ingreso
                        // Las cuentas de crédito solo reciben dinero via transferencias
                        _tipo != 'ingreso' || cuenta.tipo != 'credito')
                    .map((cuenta) {
                  return DropdownMenuItem(
                    value: cuenta,
                    child: Text(cuenta.nombre),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _cuentaSeleccionada = value;
                    if (value?.tipo != 'credito' && _formaPago == 'credito') {
                      _formaPago = 'debito';
                    }
                  });
                },
                validator: (value) {
                  if (value == null) return 'Selecciona una cuenta';
                  // Validación adicional: no permitir ingresos a cuentas de crédito
                  if (_tipo == 'ingreso' && value.tipo == 'credito') {
                    return 'No se pueden registrar ingresos en tarjetas de crédito';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Cuenta Destino (solo para transferencias)
              if (_tipo == 'transferencia') ...[
                DropdownButtonFormField<Cuenta>(
                  key: ValueKey(_cuentaDestino),
                  initialValue: _cuentaDestino,
                  decoration: InputDecoration(
                    labelText: 'Cuenta Destino',
                    prefixIcon: PhosphorIcon(PhosphorIconsRegular.arrowRight),
                  ),
                  items: _cuentas
                      .where((c) => c.id != _cuentaSeleccionada?.id)
                      .map((cuenta) {
                    return DropdownMenuItem(
                      value: cuenta,
                      child: Text(cuenta.nombre),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _cuentaDestino = value);
                  },
                  validator: (value) {
                    if (_tipo == 'transferencia' && value == null) {
                      return 'Selecciona la cuenta destino';
                    }
                    if (value?.id == _cuentaSeleccionada?.id) {
                      return 'La cuenta destino debe ser diferente';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Banner informativo de deuda (solo si destino es crédito)
                if (_cuentaDestino?.tipo == 'credito') ...[
                  FutureBuilder<double>(
                    future: widget.database.calcularDeudaRealTarjeta(_cuentaDestino!.id),
                    builder: (context, snapshot) {
                      final deudaTotal = snapshot.data ?? 0.0;
                      final creditoDisponible = (_cuentaDestino!.limiteCredito ?? 0) - deudaTotal;

                      return Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              PhosphorIcon(
                                PhosphorIconsRegular.creditCard,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  'Estado de la Tarjeta',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Deuda total:',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                Formatters.monedaConSimbolo(deudaTotal),
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: deudaTotal > 0
                                      ? AppTheme.expenseColor(context)
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Crédito disponible:',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                Formatters.monedaConSimbolo(creditoDisponible),
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                          if (deudaTotal > 0) ...[
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.tonal(
                                onPressed: () {
                                  setState(() {
                                    _montoController.text = deudaTotal.toStringAsFixed(0);
                                  });
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PhosphorIcon(PhosphorIconsRegular.checkCircle, size: 18),
                                    const SizedBox(width: AppSpacing.xs),
                                    const Text('Pagar Totalidad'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],

              // Categoría (oculta para transferencias)
              if (_tipo != 'transferencia') ...[
                DropdownButtonFormField<Categoria>(
                  key: ValueKey(_categoriaSeleccionada),
                  initialValue: _categoriaSeleccionada,
                  decoration: InputDecoration(
                    labelText: 'Categoría',
                    prefixIcon: PhosphorIcon(PhosphorIconsRegular.squaresFour),
                  ),
                  items: categoriasDisponibles.map((categoria) {
                    return DropdownMenuItem(
                      value: categoria,
                      child: Text(categoria.nombre),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _categoriaSeleccionada = value);
                  },
                  validator: (value) {
                    if (value == null) return 'Selecciona una categoría';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Fecha
              InkWell(
                onTap: _seleccionarFecha,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha',
                    prefixIcon: PhosphorIcon(PhosphorIconsRegular.calendar),
                  ),
                  child: Text(_dateFormat.format(_fecha)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Forma de pago (solo cuentas crédito) ─────────────────────
              if (permiteCuotas) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey(_formaPago),
                  initialValue: _formaPago,
                  decoration: InputDecoration(
                    labelText: 'Forma de pago',
                    prefixIcon: PhosphorIcon(PhosphorIconsRegular.creditCard),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'debito', child: Text('Débito (inmediato)')),
                    DropdownMenuItem(
                        value: 'credito', child: Text('Crédito (cuotas)')),
                  ],
                  onChanged: (value) {
                    setState(() => _formaPago = value!);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // ── Cuotas ───────────────────────────────────────────────────
              if (_formaPago == 'credito') ...[
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Configuración de Cuotas',
                  style: textTheme.titleSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _cuotasController,
                  decoration: InputDecoration(
                    labelText: 'Número de cuotas',
                    hintText: 'Ej: 12',
                    prefixIcon:
                        PhosphorIcon(PhosphorIconsRegular.listNumbers),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _valorCuotaController,
                  decoration: InputDecoration(
                    labelText: 'Valor de cada cuota',
                    hintText: 'Según estado de cuenta',
                    prefixText: '\$ ',
                    prefixIcon: PhosphorIcon(PhosphorIconsRegular.money),
                    helperText:
                        'El sistema calculará el interés automáticamente',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // ── Cobro de préstamo (solo ingresos) ─────────────────────────
              if (_tipo == 'ingreso') ...[
                const Divider(),
                CheckboxListTile(
                  title: const Text('Es cobro de préstamo'),
                  subtitle:
                      const Text('Vincula este ingreso al pago de una deuda'),
                  value: _esCobro,
                  onChanged: (v) => setState(() {
                    _esCobro = v ?? false;
                    if (!_esCobro) {
                      _personaCobro = null;
                      _deudaCobro = null;
                      _deudasPersonaCobro = [];
                    }
                  }),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_esCobro) ...[
                  if (_personas.isEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Text(
                        'No hay personas registradas.',
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.error),
                      ),
                    )
                  else
                    DropdownButtonFormField<Persona>(
                      key: ValueKey(_personaCobro),
                      initialValue: _personaCobro,
                      decoration: InputDecoration(
                        labelText: 'Persona que paga',
                        prefixIcon: PhosphorIcon(PhosphorIconsRegular.user),
                      ),
                      items: _personas
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(p.nombre),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _personaCobro = v;
                        _deudaCobro = null;
                        _deudasPersonaCobro = _todasDeudas
                            .where((d) => d.personaId == v?.id)
                            .toList();
                      }),
                    ),
                  if (_personaCobro != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    if (_deudasPersonaCobro.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs),
                        child: Text(
                          '${_personaCobro!.nombre} no tiene deudas pendientes.',
                          style: textTheme.bodySmall
                              ?.copyWith(color: AppColors.alertWarning),
                        ),
                      )
                    else
                      DropdownButtonFormField<Deuda>(
                        key: ValueKey(_deudaCobro),
                        initialValue: _deudaCobro,
                        decoration: InputDecoration(
                          labelText: 'Deuda a saldar',
                          prefixIcon:
                              PhosphorIcon(PhosphorIconsRegular.receipt),
                        ),
                        items: _deudasPersonaCobro
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(
                                    '${Formatters.monedaConSimbolo(d.montoPendiente)} — ${d.tipo == 'cuotas' ? 'cuotas' : 'pago único'}',
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _deudaCobro = v;
                          if (v != null) {
                            _montoController.text =
                                v.montoPendiente.toStringAsFixed(2);
                          }
                        }),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],
              ],

              // ── Préstamo ─────────────────────────────────────────────────
              const Divider(),
              CheckboxListTile(
                title: const Text('Es un préstamo a tercero'),
                subtitle: const Text(
                    'Pagado con tu cuenta pero lo debe otra persona'),
                value: _esPrestamo,
                onChanged: (value) {
                  setState(() {
                    _esPrestamo = value ?? false;
                    if (_esPrestamo) {
                      _gastoCompartido = false;
                      _personasCompartidasIds.clear();
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              if (_esPrestamo) ...[
                if (_personas.isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      'No hay personas registradas. Primero crea una persona.',
                      style:
                          textTheme.bodySmall?.copyWith(color: scheme.error),
                    ),
                  )
                else
                  DropdownButtonFormField<Persona>(
                    key: ValueKey(_personaSeleccionada),
                    initialValue: _personaSeleccionada,
                    decoration: InputDecoration(
                      labelText: 'Persona que debe',
                      prefixIcon: PhosphorIcon(PhosphorIconsRegular.user),
                    ),
                    items: _personas.map((persona) {
                      return DropdownMenuItem(
                          value: persona, child: Text(persona.nombre));
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _personaSeleccionada = value);
                    },
                  ),
                const SizedBox(height: AppSpacing.md),
              ],

              // ── Gasto compartido ─────────────────────────────────────────
              if (_tipo == 'egreso' && !_esPrestamo) ...[
                const Divider(),
                CheckboxListTile(
                  title: const Text('Gasto compartido'),
                  subtitle:
                      const Text('Divide el gasto entre varias personas'),
                  value: _gastoCompartido,
                  onChanged: (v) => setState(() {
                    _gastoCompartido = v ?? false;
                    if (!_gastoCompartido) _personasCompartidasIds.clear();
                  }),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_gastoCompartido) ...[
                  if (_personas.isEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Text(
                        'No hay personas registradas para compartir el gasto.',
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.error),
                      ),
                    )
                  else ...[
                    const SizedBox(height: AppSpacing.xs),
                    ..._personas.map((p) => CheckboxListTile(
                          title: Text(p.nombre),
                          value: _personasCompartidasIds.contains(p.id),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _personasCompartidasIds.add(p.id);
                            } else {
                              _personasCompartidasIds.remove(p.id);
                            }
                          }),
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 0),
                        )),
                    SwitchListTile(
                      title: const Text('Incluirme en el reparto'),
                      value: _incluirme,
                      onChanged: (v) => setState(() => _incluirme = v),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    if (_personasCompartidasIds.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Builder(builder: (ctx) {
                        final total =
                            double.tryParse(_montoController.text) ?? 0.0;
                        final n =
                            _personasCompartidasIds.length + (_incluirme ? 1 : 0);
                        final share = n > 0 ? total / n : 0.0;
                        return Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Column(
                            children: [
                              ..._personas
                                  .where((p) =>
                                      _personasCompartidasIds.contains(p.id))
                                  .map((p) => Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(p.nombre,
                                                style: textTheme.bodySmall,
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Text(
                                            Formatters.monedaConSimbolo(share),
                                            style: textTheme.labelMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )),
                              if (_incluirme)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text('Yo',
                                          style: textTheme.bodySmall),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      Formatters.monedaConSimbolo(share),
                                      style:
                                          textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.incomeColor(ctx),
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
                  const SizedBox(height: AppSpacing.md),
                ],
              ],

              // Botones de acción
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _guardarTransaccion,
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
