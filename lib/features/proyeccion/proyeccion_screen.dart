import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/database/database.dart';
import '../../core/utils/responsive.dart';
import 'models/proyeccion_models.dart';
import 'widgets/header_controls.dart';
import 'widgets/liberacion_banner.dart';
import 'widgets/toggle_vistas.dart';
import 'widgets/grafico_barras.dart';
import 'widgets/detalle_meses.dart';

class ProyeccionScreen extends StatefulWidget {
  final AppDatabase database;

  const ProyeccionScreen({super.key, required this.database});

  @override
  State<ProyeccionScreen> createState() => _ProyeccionScreenState();
}

class _ProyeccionScreenState extends State<ProyeccionScreen> {
  final ScrollController _scrollController = ScrollController();

  // Filtros
  bool _mostrarFiltros = true;
  late DateTime _mesInicio;
  int? _cuentaId;
  int _mesesAVer = 3;
  bool _incluirGastosFijos = false;
  double? _sueldo;
  bool _incluirPrestamos = false;
  Set<int> _prestamosSeleccionados = {};

  // Vistas
  bool _mostrarGrafico = true;
  bool _mostrarDetalle = true;
  bool _isLoading = false;

  // Resultados
  List<MesProyeccion> _mesesProyeccion = [];
  MesLiberacion? _mesLiberacion;

  @override
  void initState() {
    super.initState();
    _mesInicio = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _scrollController.addListener(_onScroll);
    _cargarDatos();
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
      final proyeccion = await _calcularProyeccion();
      if (mounted) {
        setState(() {
          _mesesProyeccion = proyeccion.meses;
          _mesLiberacion = proyeccion.liberacion;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<ProyeccionData> _calcularProyeccion() async {
    final db = widget.database;

    // 1. Total de gastos fijos activos de la DB
    double gastosFijosMensual = 0;
    if (_incluirGastosFijos) {
      gastosFijosMensual = await db.totalGastosFijosActivos();
    }

    // 2. Todas las cuotas sin pagar desde _mesInicio en adelante (con join)
    final q = db.select(db.cuotas).join([
      innerJoin(
        db.transacciones,
        db.transacciones.id.equalsExp(db.cuotas.transaccionId),
      ),
      leftOuterJoin(
        db.cuentas,
        db.cuentas.id.equalsExp(db.transacciones.cuentaId),
      ),
    ]);
    q.where(
      db.cuotas.pagada.equals(false) &
          db.cuotas.fechaVencimiento.isBiggerOrEqualValue(_mesInicio),
    );
    if (_cuentaId != null) {
      q.where(db.transacciones.cuentaId.equals(_cuentaId!));
    }
    q.orderBy([OrderingTerm.asc(db.cuotas.fechaVencimiento)]);
    final rows = await q.get();

    // 3. Deudas seleccionadas para cobro
    final deudasACobrar = <(Deuda, Persona)>[];
    if (_incluirPrestamos && _prestamosSeleccionados.isNotEmpty) {
      final dq = db.select(db.deudas).join([
        innerJoin(db.personas, db.personas.id.equalsExp(db.deudas.personaId)),
      ]);
      dq.where(db.deudas.id.isIn(_prestamosSeleccionados));
      final dRows = await dq.get();
      for (final r in dRows) {
        deudasACobrar.add((r.readTable(db.deudas), r.readTable(db.personas)));
      }
    }

    // 4. Proyección mes a mes
    final meses = <MesProyeccion>[];
    for (int i = 0; i < _mesesAVer; i++) {
      final mes = DateTime(_mesInicio.year, _mesInicio.month + i, 1);

      // Cuotas del mes
      final cuotasMes = rows
          .where((r) {
            final c = r.readTable(db.cuotas);
            return c.fechaVencimiento.year == mes.year &&
                c.fechaVencimiento.month == mes.month;
          })
          .map((r) {
            final cuota = r.readTable(db.cuotas);
            final tx = r.readTable(db.transacciones);
            final cuenta = r.readTableOrNull(db.cuentas);
            return CuotaMes(
              descripcion: tx.descripcion,
              numeroCuota: cuota.numeroCuota,
              totalCuotas: tx.cantidadCuotas ?? 1,
              monto: cuota.monto,
              fechaVencimiento: cuota.fechaVencimiento,
              nombreTarjeta: cuenta?.nombre ?? '—',
              transaccionId: cuota.transaccionId,
            );
          })
          .toList();

      final totalCuotas = cuotasMes.fold<double>(0, (s, c) => s + c.monto);

      // Préstamos a cobrar este mes
      final prestamosDelMes = deudasACobrar
          .where((t) {
            final fecha = t.$1.fechaAcordadaPago;
            return fecha != null &&
                fecha.year == mes.year &&
                fecha.month == mes.month;
          })
          .map((t) => PrestamoCobro(
                personaId: t.$1.personaId,
                nombrePersona: t.$2.nombre,
                monto: t.$1.montoPendiente,
                fechaEsperada: t.$1.fechaAcordadaPago,
              ))
          .toList();

      final totalPrestamos =
          prestamosDelMes.fold<double>(0, (s, p) => s + p.monto);
      final totalIngresos = (_sueldo ?? 0) + totalPrestamos;
      final totalEgresos = totalCuotas + gastosFijosMensual;
      final sobrante = totalIngresos - totalEgresos;

      meses.add(MesProyeccion(
        fecha: mes,
        totalCuotas: totalCuotas,
        totalGastosFijos: gastosFijosMensual,
        totalIngresos: totalIngresos,
        totalEgresos: totalEgresos,
        sobrante: sobrante,
        cuotas: cuotasMes,
        prestamosCobrar: prestamosDelMes,
      ));
    }

    // 5. Mes de liberación: primer mes tras la última cuota sin pagar
    MesLiberacion? liberacion;
    if (rows.isNotEmpty) {
      final lastRow = rows.last;
      final lastCuota = lastRow.readTable(db.cuotas);
      final lastTx = lastRow.readTable(db.transacciones);
      final lastCuenta = lastRow.readTableOrNull(db.cuentas);

      final now = DateTime.now();
      final mesLib = DateTime(
        lastCuota.fechaVencimiento.year,
        lastCuota.fechaVencimiento.month + 1,
        1,
      );
      final mesesFaltantes =
          ((mesLib.year - now.year) * 12 + mesLib.month - now.month)
              .clamp(0, 999);

      liberacion = MesLiberacion(
        fecha: mesLib,
        descripcionUltima: lastTx.descripcion,
        montoUltima: lastCuota.monto,
        tarjetaUltima: lastCuenta?.nombre ?? '—',
        mesesFaltantes: mesesFaltantes,
      );
    }

    return ProyeccionData(meses: meses, liberacion: liberacion);
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
                      sueldo: _sueldo,
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
                      onSueldoChanged: (v) {
                        setState(() => _sueldo = v);
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
                sueldo: _sueldo,
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
                sueldo: _sueldo,
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
              sueldo: _sueldo,
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
              sueldo: _sueldo,
              onMesTap: (_) {},
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PhosphorIcon(
            PhosphorIconsRegular.trendUp,
            size: 64,
            color: scheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Sin cuotas pendientes',
            style: textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega compras a crédito para ver\ntu proyección financiera',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class ProyeccionData {
  final List<MesProyeccion> meses;
  final MesLiberacion? liberacion;

  ProyeccionData({required this.meses, this.liberacion});
}
