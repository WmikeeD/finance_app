import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import 'models/proyeccion_models.dart';
import 'models/simulacion_models.dart';
import 'data/proyeccion_repository.dart';
import 'widgets/header_controls.dart';
import 'widgets/liberacion_banner.dart';
import 'widgets/toggle_vistas.dart';
import 'widgets/grafico_barras.dart';
import 'widgets/detalle_meses.dart';
import 'widgets/simulador_compra_sheet.dart';

class ProyeccionScreen extends StatefulWidget {
  final AppDatabase database;

  const ProyeccionScreen({super.key, required this.database});

  @override
  State<ProyeccionScreen> createState() => _ProyeccionScreenState();
}

class _ProyeccionScreenState extends State<ProyeccionScreen> {
  final ScrollController _scrollController = ScrollController();
  late final ProyeccionRepository _repository;

  // Filtros
  bool _mostrarFiltros = true;
  late DateTime _mesInicio;
  int? _cuentaId;
  int _mesesAVer = 3;
  bool _incluirGastosFijos = false;
  double? _sueldoTemporal; // Temporal para el input, se guarda en DB al cambiar
  bool _incluirPrestamos = false;
  Set<int> _prestamosSeleccionados = {};

  // Vistas
  bool _mostrarGrafico = true;
  bool _mostrarDetalle = true;
  bool _isLoading = false;

  // Simulación
  CompraSimulada? _compraSimulada;
  ImpactoSimulacion? _impactoSimulacion;

  // Resultados
  List<MesProyeccion> _mesesProyeccion = [];
  MesLiberacion? _mesLiberacion;

  @override
  void initState() {
    super.initState();
    _repository = ProyeccionRepository(widget.database);
    _mesInicio = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _scrollController.addListener(_onScroll);
    _cargarDatos();
    _cargarSueldoDesdeDB();
  }

  /// Cargar el sueldo (ingreso recurrente) desde la DB al iniciar
  Future<void> _cargarSueldoDesdeDB() async {
    final ingresos = await _repository.getIngresosRecurrentesActivos();
    if (ingresos.isNotEmpty && mounted) {
      setState(() {
        _sueldoTemporal = ingresos.first.monto;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 100 && _mostrarFiltros) {
      setState(() => _mostrarFiltros = false);
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final proyeccion = await _repository.calcularProyeccion(
        mesInicio: _mesInicio,
        mesesAVer: _mesesAVer,
        cuentaId: _cuentaId,
        incluirGastosFijos: _incluirGastosFijos,
        incluirPrestamos: _incluirPrestamos,
        prestamosSeleccionados: _prestamosSeleccionados,
        compraSimulada: _compraSimulada,
      );

      // Si hay simulación activa, calcular su impacto
      ImpactoSimulacion? impacto;
      if (_compraSimulada != null) {
        impacto = await _repository.calcularImpactoSimulacion(
          compra: _compraSimulada!,
          mesInicio: _mesInicio,
          mesesAVer: _mesesAVer,
          cuentaId: _cuentaId,
          incluirGastosFijos: _incluirGastosFijos,
          incluirPrestamos: _incluirPrestamos,
          prestamosSeleccionados: _prestamosSeleccionados,
        );
      }

      if (mounted) {
        setState(() {
          _mesesProyeccion = proyeccion.meses;
          _mesLiberacion = proyeccion.liberacion;
          _impactoSimulacion = impacto;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _abrirSimulador() async {
    final result = await showModalBottomSheet<CompraSimulada?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SimuladorCompraSheet(
        compraActual: _compraSimulada,
        mesInicioProyeccion: _mesInicio,
      ),
    );

    if (result != null) {
      setState(() => _compraSimulada = result);
      _cargarDatos();
    } else if (result == null && _compraSimulada != null) {
      // Usuario presionó "Limpiar"
      setState(() {
        _compraSimulada = null;
        _impactoSimulacion = null;
      });
      _cargarDatos();
    }
  }

  /// Guardar sueldo en la base de datos como ingreso recurrente
  Future<void> _guardarSueldoEnDB(double? sueldo) async {
    if (sueldo == null || sueldo <= 0) {
      // Si se elimina el sueldo, eliminar todos los ingresos recurrentes activos
      final ingresos = await _repository.getIngresosRecurrentesActivos();
      for (final ingreso in ingresos) {
        await _repository.eliminarIngresoRecurrente(ingreso.id);
      }
      return;
    }

    // Verificar si ya existe un ingreso recurrente activo
    final ingresosExistentes = await _repository.getIngresosRecurrentesActivos();

    if (ingresosExistentes.isEmpty) {
      // Crear nuevo ingreso recurrente
      // Por defecto, usar la primera cuenta líquida disponible o la primera cuenta
      final cuentas = await (widget.database.select(widget.database.cuentas)
            ..where((c) => c.activa.equals(true)))
          .get();
      final cuentaDefecto = cuentas.firstWhere(
        (c) => c.tipo == 'efectivo' || c.tipo == 'debito',
        orElse: () => cuentas.first,
      );

      await _repository.guardarIngresoRecurrente(
        descripcion: 'Sueldo Principal',
        monto: sueldo,
        cuentaId: cuentaDefecto.id,
        frecuencia: 'ultimo_dia_habil',
        activo: true,
      );
    } else {
      // Actualizar el monto del ingreso existente
      final ingresoExistente = ingresosExistentes.first;
      await _repository.guardarIngresoRecurrente(
        id: ingresoExistente.id,
        descripcion: ingresoExistente.descripcion,
        monto: sueldo,
        cuentaId: ingresoExistente.cuentaId,
        frecuencia: ingresoExistente.frecuencia,
        diaMes: ingresoExistente.diaMes,
        activo: true,
        fechaInicio: ingresoExistente.fechaInicio,
      );
    }
  }

  void _toggleFiltros() => setState(() => _mostrarFiltros = !_mostrarFiltros);

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveHelper.getDeviceType(context);
    final isMobile = deviceType == DeviceType.mobile;

    // SliverAppBar altura adaptativa: más espacio en tablets/desktop
    final expandedHeight = _mostrarFiltros
        ? (isMobile ? 200.0 : 240.0)
        : 60.0;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: expandedHeight,
            title: const Text('Proyección de Cuotas'),
            actions: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              // ✨ Botón de simulador
              IconButton(
                icon: PhosphorIcon(
                  _compraSimulada != null
                      ? PhosphorIconsFill.calculator
                      : PhosphorIconsRegular.calculator,
                  color: _compraSimulada != null
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                onPressed: _abrirSimulador,
                tooltip: 'Simular compra en cuotas',
              ),
              IconButton(
                icon: PhosphorIcon(
                  _mostrarFiltros
                      ? PhosphorIconsRegular.caretUp
                      : PhosphorIconsRegular.faders,
                ),
                onPressed: _toggleFiltros,
                tooltip: 'Mostrar/ocultar filtros',
              ),
            ],
            flexibleSpace: _mostrarFiltros
                ? FlexibleSpaceBar(
                    background: HeaderControls(
                      mesInicio: _mesInicio,
                      cuentaId: _cuentaId,
                      mesesAVer: _mesesAVer,
                      incluirGastosFijos: _incluirGastosFijos,
                      sueldo: _sueldoTemporal,
                      incluirPrestamos: _incluirPrestamos,
                      prestamosSeleccionados: _prestamosSeleccionados,
                      database: widget.database,
                      onMesInicioChanged: (v) {
                        setState(
                            () => _mesInicio = DateTime(v.year, v.month, 1));
                        _cargarDatos();
                      },
                      onCuentaChanged: (v) {
                        setState(() => _cuentaId = v);
                        _cargarDatos();
                      },
                      onMesesChanged: (v) {
                        setState(() => _mesesAVer = v);
                        _cargarDatos();
                      },
                      onGastosFijosChanged: (v) {
                        setState(() => _incluirGastosFijos = v);
                        _cargarDatos();
                      },
                      onSueldoChanged: (v) async {
                        setState(() => _sueldoTemporal = v);
                        await _guardarSueldoEnDB(v);
                        _cargarDatos();
                      },
                      onPrestamosChanged: (v) {
                        setState(() {
                          _incluirPrestamos = v.$1;
                          _prestamosSeleccionados = v.$2;
                        });
                        _cargarDatos();
                      },
                    ),
                  )
                : null,
          ),

          if (_mesLiberacion != null)
            SliverPersistentHeader(
              pinned: true,
              delegate: LiberacionBannerDelegate(
                mesLiberacion: _mesLiberacion!,
                isMobile: isMobile,
              ),
            ),

          // ✨ Banner de simulación activa
          if (_compraSimulada != null && _impactoSimulacion != null)
            SliverToBoxAdapter(
              child: _buildBannerSimulacion(),
            ),

          SliverToBoxAdapter(
            child: ToggleVistas(
              mostrarGrafico: _mostrarGrafico,
              mostrarDetalle: _mostrarDetalle,
              onGraficoChanged: (v) => setState(() => _mostrarGrafico = v),
              onDetalleChanged: (v) => setState(() => _mostrarDetalle = v),
              onPantallaCompleta: () {},
            ),
          ),

          SliverFillRemaining(
            hasScrollBody: true,
            child: _mesesProyeccion.isEmpty && !_isLoading
                ? _buildEmptyState()
                : _buildResponsiveContent(isMobile),
          ),
        ],
      ),
    );
  }

  /// Layout responsivo: Column en mobile, Row en tablet/desktop
  Widget _buildResponsiveContent(bool isMobile) {
    if (isMobile) {
      // Mobile: Layout vertical tradicional
      return Column(
        children: [
          if (_mostrarGrafico)
            Expanded(
              flex: _mostrarDetalle ? 1 : 2,
              child: GraficoBarras(
                meses: _mesesProyeccion,
                sueldo: _sueldoTemporal,
                incluirGastosFijos: _incluirGastosFijos,
                onMesSeleccionado: (_) {},
              ),
            ),
          if (_mostrarGrafico && _mostrarDetalle)
            const Divider(height: 1, thickness: 2),
          if (_mostrarDetalle)
            Expanded(
              flex: _mostrarGrafico ? 1 : 2,
              child: DetalleMeses(
                meses: _mesesProyeccion,
                incluirGastosFijos: _incluirGastosFijos,
                sueldo: _sueldoTemporal,
                onMesTap: (_) {},
              ),
            ),
        ],
      );
    }

    // Tablet/Desktop: Layout horizontal 50/50
    return Row(
      children: [
        // Columna izquierda: Gráfico de barras (50%)
        if (_mostrarGrafico)
          Expanded(
            flex: _mostrarDetalle ? 1 : 2,
            child: GraficoBarras(
              meses: _mesesProyeccion,
              sueldo: _sueldoTemporal,
              incluirGastosFijos: _incluirGastosFijos,
              onMesSeleccionado: (_) {},
            ),
          ),

        // Divider vertical entre columnas
        if (_mostrarGrafico && _mostrarDetalle)
          const VerticalDivider(width: 1, thickness: 2),

        // Columna derecha: Detalle mensual con scroll independiente (50%)
        if (_mostrarDetalle)
          Expanded(
            flex: _mostrarGrafico ? 1 : 2,
            child: DetalleMeses(
              meses: _mesesProyeccion,
              incluirGastosFijos: _incluirGastosFijos,
              sueldo: _sueldoTemporal,
              onMesTap: (_) {},
            ),
          ),
      ],
    );
  }

  Widget _buildBannerSimulacion() {
    final textTheme = Theme.of(context).textTheme;
    final impacto = _impactoSimulacion!;

    Color bannerColor;
    Color textColor;
    IconData icono;

    switch (impacto.nivelAlerta) {
      case AlertLevel.ok:
        bannerColor = AppTheme.incomeColor(context).withValues(alpha: 0.15);
        textColor = AppTheme.incomeColor(context);
        icono = PhosphorIconsRegular.checkCircle;
        break;
      case AlertLevel.warning:
        bannerColor = AppColors.alertWarning.withValues(alpha: 0.15);
        textColor = AppColors.alertWarning;
        icono = PhosphorIconsRegular.warning;
        break;
      case AlertLevel.danger:
        bannerColor = AppTheme.expenseColor(context).withValues(alpha: 0.15);
        textColor = AppTheme.expenseColor(context);
        icono = PhosphorIconsRegular.warningCircle;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: AppRadius.xlBR,
        border: Border.all(
          color: textColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(
                icono,
                color: textColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SIMULACIÓN ACTIVA',
                      style: textTheme.labelSmall?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _compraSimulada!.toString(),
                      style: textTheme.titleSmall?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: PhosphorIcon(
                  PhosphorIconsRegular.x,
                  color: textColor,
                ),
                onPressed: () {
                  setState(() {
                    _compraSimulada = null;
                    _impactoSimulacion = null;
                  });
                  _cargarDatos();
                },
                tooltip: 'Limpiar simulación',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            impacto.mensajeImpacto,
            style: textTheme.bodyMedium?.copyWith(
              color: textColor.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PhosphorIcon(
            PhosphorIconsRegular.trendUp,
            size: 64,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Sin cuotas pendientes',
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega compras a crédito para ver\ntu proyección financiera',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

