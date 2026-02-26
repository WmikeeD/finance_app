import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../../core/database/database.dart';
import '../../core/utils/formatters.dart';
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
  // Controllers
  final ScrollController _scrollController = ScrollController();
  
  // Estado de filtros
  bool _mostrarFiltros = true;
  late DateTime _mesInicio = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int? _cuentaId;
  int _mesesAVer = 3;
  double? _gastosFijos;
  double? _sueldo;
  bool _incluirPrestamos = false;
  Set<int> _prestamosSeleccionados = {};
  bool get incluirGastosFijos => _gastosFijos != null;
  bool get incluirSueldo => _sueldo != null;
  // Estado de vistas
  bool _mostrarGrafico = true;
  bool _mostrarDetalle = true;
  
  // Datos calculados
  List<MesProyeccion> _mesesProyeccion = [];
  MesLiberacion? _mesLiberacion;
  
  @override
  void initState() {
    super.initState();
    _mesInicio = DateTime(DateTime.now().year, DateTime.now().month, 1); // ✅
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
    // Ocultar filtros cuando se hace scroll hacia abajo
    if (_scrollController.offset > 100 && _mostrarFiltros) {
      setState(() => _mostrarFiltros = false);
    }
  }

  Future<void> _cargarDatos() async {
    // Calcular proyección
    final proyeccion = await _calcularProyeccion();
    
    setState(() {
      _mesesProyeccion = proyeccion.meses;
      _mesLiberacion = proyeccion.liberacion;
    });
  }

  Future<ProyeccionData> _calcularProyeccion() async {
    // Implementar lógica de cálculo
    // ...
    return ProyeccionData(meses: [], liberacion: null);
  }

  void _toggleFiltros() {
    setState(() => _mostrarFiltros = !_mostrarFiltros);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // SliverAppBar con título y botón de filtros
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: _mostrarFiltros ? 200 : 60,
            title: const Text('Proyección de Cuotas'),
            actions: [
              IconButton(
                icon: Icon(_mostrarFiltros ? Icons.expand_less : Icons.tune),
                onPressed: _toggleFiltros,
                tooltip: 'Mostrar/ocultar filtros',
              ),
            ],
            flexibleSpace: _mostrarFiltros ? FlexibleSpaceBar(
              background: HeaderControls(
                mesInicio: _mesInicio,
                cuentaId: _cuentaId,
                mesesAVer: _mesesAVer,
                incluirGastosFijos: incluirGastosFijos,
                sueldo: _sueldo,
                incluirPrestamos: _incluirPrestamos,
                prestamosSeleccionados: _prestamosSeleccionados,
                onMesInicioChanged: (v) => setState(() { _mesInicio = DateTime(v.year, v.month, 1); }),
                onCuentaChanged: (v) => setState(() => _cuentaId = v),
                onMesesChanged: (v) => setState(() => _mesesAVer = v),
                onGastosFijosChanged: (v) => setState(() => _gastosFijos = v),
                onSueldoChanged: (v) => setState(() => _sueldo = v),
                onPrestamosChanged: (v) => setState(() {
                  _incluirPrestamos = v.$1;
                  _prestamosSeleccionados = v.$2;
                }),
                database: widget.database,
                gastosFijos: _gastosFijos,
              ),
            ) : null,
          ),

          // Banner de liberación (sticky)
          if (_mesLiberacion != null)
            SliverPersistentHeader(
              pinned: true,
              delegate: LiberacionBannerDelegate(
                mesLiberacion: _mesLiberacion!,
              ),
            ),

          // Toggle de vistas
          SliverToBoxAdapter(
            child: ToggleVistas(
              mostrarGrafico: _mostrarGrafico,
              mostrarDetalle: _mostrarDetalle,
              onGraficoChanged: (v) => setState(() => _mostrarGrafico = v),
              onDetalleChanged: (v) => setState(() => _mostrarDetalle = v),
              onPantallaCompleta: () {
                // Implementar pantalla completa
              },
            ),
          ),

          // Contenido principal (Gráfico + Detalle)
          SliverFillRemaining(
            hasScrollBody: true,
            child: Column(
              children: [
                // Gráfico (expandible)
                if (_mostrarGrafico)
                  Expanded(
                    flex: _mostrarDetalle ? 1 : 2,
                    child: GraficoBarras(
                      meses: _mesesProyeccion,
                      sueldo: _sueldo,
                      incluirGastosFijos: incluirGastosFijos,
                      onMesSeleccionado: (mes) {
                        // Scroll detalle a mes
                      },
                    ),
                  ),

                // Divisor
                if (_mostrarGrafico && _mostrarDetalle)
                  const Divider(height: 1, thickness: 2),

                // Detalle (expandible)
                if (_mostrarDetalle)
                  Expanded(
                    flex: _mostrarGrafico ? 1 : 2,
                    child: DetalleMeses(
                      meses: _mesesProyeccion,
                      incluirGastosFijos: incluirGastosFijos,
                      sueldo: _sueldo,
                      onMesTap: (mes) {
                        // Highlight en gráfico
                      },
                    ),
                  ),
              ],
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