import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/database/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/models/ocr_result.dart';

class CrearTransaccionModal extends StatefulWidget {
  final AppDatabase database;

  const CrearTransaccionModal({
    super.key,
    required this.database,
  });

  @override
  State<CrearTransaccionModal> createState() => _CrearTransaccionModalState();
}

class _CrearTransaccionModalState extends State<CrearTransaccionModal> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();
  final _montoController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  String _tipo = 'egreso';
  Cuenta? _cuentaSeleccionada;
  Categoria? _categoriaSeleccionada;
  DateTime _fecha = DateTime.now();

  List<Cuenta> _cuentas = [];
  List<Categoria> _categorias = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final cuentas =
        await widget.database.select(widget.database.cuentas).get();
    final categorias =
        await widget.database.select(widget.database.categorias).get();

    if (mounted) {
      setState(() {
        _cuentas = cuentas;
        _categorias = categorias;
        if (cuentas.isNotEmpty) _cuentaSeleccionada = cuentas.first;
        final categoriasEgreso = categorias.where((c) => c.tipo == 'egreso');
        if (categoriasEgreso.isNotEmpty) {
          _categoriaSeleccionada = categoriasEgreso.first;
        }
      });
    }
  }

  Future<void> _guardarTransaccion() async {
    if (!_formKey.currentState!.validate()) return;

    if (_cuentaSeleccionada == null) {
      _mostrarError('Debes seleccionar una cuenta');
      return;
    }

    if (_categoriaSeleccionada == null) {
      _mostrarError('Debes seleccionar una categoría');
      return;
    }

    final monto = double.tryParse(_montoController.text.replaceAll(',', '.'));
    if (monto == null || monto <= 0) {
      _mostrarError('El monto debe ser mayor a cero');
      return;
    }

    try {
      await widget.database.transaction(() async {
        // Insertar transacción
        await widget.database.into(widget.database.transacciones).insert(
              TransaccionesCompanion.insert(
                tipo: _tipo,
                descripcion: _descripcionController.text.trim(),
                montoTotal: monto,
                formaPago: 'debito',
                fecha: _fecha,
                cuentaId: _cuentaSeleccionada!.id,
                categoriaId: _categoriaSeleccionada!.id,
                esPrestamo: const drift.Value(false),
              ),
            );

        // Actualizar saldo de la cuenta
        final cuenta = _cuentaSeleccionada!;
        final nuevoSaldo = _tipo == 'ingreso'
            ? cuenta.saldo + monto
            : cuenta.saldo - monto;

        await widget.database
            .update(widget.database.cuentas)
            .replace(cuenta.copyWith(saldo: nuevoSaldo));
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

    // Mostrar opciones de fuente de imagen
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: PhosphorIcon(PhosphorIconsRegular.camera, color: scheme.primary),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: PhosphorIcon(PhosphorIconsRegular.image, color: scheme.primary),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    // Capturar imagen
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);

    if (image == null) return;

    // Mostrar indicador de carga
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Procesar imagen con OCR
      final ocrService = OcrService();
      final result = await ocrService.processImage(image.path);

      if (!mounted) return;
      Navigator.pop(context); // Cerrar indicador de carga

      // Procesar resultado según el estado
      switch (result.status) {
        case OcrStatus.success:
        case OcrStatus.partial:
          // Auto-completar campos
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

          // Mostrar SnackBar sutil
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  PhosphorIcon(PhosphorIconsRegular.checkCircle, color: Colors.white),
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
          // Mostrar error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  PhosphorIcon(PhosphorIconsRegular.warning, color: Colors.white),
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
      Navigator.pop(context); // Cerrar indicador de carga

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar imagen: $e'),
          backgroundColor: scheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final categoriasDisponibles =
        _categorias.where((c) => c.tipo == _tipo).toList();

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
                  // Botón de escaneo OCR
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
                ],
                onChanged: (value) {
                  setState(() {
                    _tipo = value!;
                    final nuevasCategorias =
                        _categorias.where((c) => c.tipo == _tipo).toList();
                    if (nuevasCategorias.isNotEmpty) {
                      _categoriaSeleccionada = nuevasCategorias.first;
                    } else {
                      _categoriaSeleccionada = null;
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
                  prefixIcon: PhosphorIcon(PhosphorIconsRegular.currencyCircleDollar),
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
                ),
                items: _cuentas.map((cuenta) {
                  return DropdownMenuItem(
                    value: cuenta,
                    child: Text(cuenta.nombre),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _cuentaSeleccionada = value);
                },
                validator: (value) {
                  if (value == null) return 'Selecciona una cuenta';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Categoría
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
              const SizedBox(height: AppSpacing.lg),

              // Botones de acción
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
