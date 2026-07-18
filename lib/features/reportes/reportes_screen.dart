import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:fl_chart/fl_chart.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/database/database.dart';
import '../../core/services/exportacion_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/widgets.dart';

class ReportesScreen extends StatefulWidget {
  final AppDatabase database;

  const ReportesScreen({super.key, required this.database});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  late DateTime _mesSeleccionado;
  int? _sectorTocado;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _mesSeleccionado = DateTime(now.year, now.month, 1);
  }

  DateTime get _inicioMes => _mesSeleccionado;
  DateTime get _finMes =>
      DateTime(_mesSeleccionado.year, _mesSeleccionado.month + 1, 0, 23, 59, 59);

  void _mesAnterior() =>
      setState(() => _mesSeleccionado =
          DateTime(_mesSeleccionado.year, _mesSeleccionado.month - 1, 1));

  void _mesSiguiente() {
    final ahora = DateTime.now();
    final siguiente =
        DateTime(_mesSeleccionado.year, _mesSeleccionado.month + 1, 1);
    if (siguiente.isBefore(DateTime(ahora.year, ahora.month + 1, 1))) {
      setState(() => _mesSeleccionado = siguiente);
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = ResponsiveHelper.getHorizontalPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          PopupMenuButton<String>(
            icon: PhosphorIcon(PhosphorIconsRegular.export),
            tooltip: 'Exportar reporte',
            onSelected: (fmt) => _exportarReporte(fmt),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Text('Exportar PDF')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: AppSpacing.base,
        ),
        children: [
          _buildSelectorMes(),
          const SizedBox(height: AppSpacing.base),
          _buildResumenMes(),
          const SizedBox(height: AppSpacing.lg),
          _buildGastosPorCategoria(),
          const SizedBox(height: AppSpacing.lg),
          _buildEvolucionHistorica(),
        ],
      ),
    );
  }

  // ── Selector de mes ───────────────────────────────────────────────────────

  Widget _buildSelectorMes() {
    final nombre = _nombreMesAnio(_mesSeleccionado);
    final esActual = _mesSeleccionado.year == DateTime.now().year &&
        _mesSeleccionado.month == DateTime.now().month;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: PhosphorIcon(PhosphorIconsRegular.caretLeft),
          onPressed: _mesAnterior,
        ),
        Text(
          nombre,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        IconButton(
          icon: PhosphorIcon(PhosphorIconsRegular.caretRight),
          onPressed: esActual ? null : _mesSiguiente,
        ),
      ],
    );
  }

  // ── Resumen del mes ───────────────────────────────────────────────────────

  Widget _buildResumenMes() {
    return FutureBuilder<_ResumenMes>(
      future: _calcularResumen(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final r = snap.data!;
        return Row(
          children: [
            Expanded(
              child: _buildResumenCard(
                'Ingresos',
                r.ingresos,
                PhosphorIconsRegular.arrowDownLeft,
                AppTheme.incomeColor(context),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildResumenCard(
                'Egresos',
                r.egresos,
                PhosphorIconsRegular.arrowUpRight,
                AppTheme.expenseColor(context),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildResumenCard(
                'Balance',
                r.ingresos - r.egresos,
                PhosphorIconsRegular.scales,
                r.ingresos >= r.egresos ? AppTheme.incomeColor(context) : AppTheme.expenseColor(context),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResumenCard(
      String titulo, double monto, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            AppSemanticIcon(icon: icon, color: color, size: AppIconSize.sm),
            const SizedBox(height: AppSpacing.sm),
            Text(titulo,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                Formatters.monedaConSimbolo(monto.abs()),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: monto < 0 ? AppTheme.expenseColor(context) : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Gastos por categoría ──────────────────────────────────────────────────

  Widget _buildGastosPorCategoria() {
    return FutureBuilder<List<_CategoriaGasto>>(
      future: _calcularGastosPorCategoria(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final gastos = snap.data!;
        final scheme = Theme.of(context).colorScheme;

        if (gastos.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Sin egresos en este mes',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          );
        }

        final total = gastos.fold<double>(0, (s, g) => s + g.total);
        final deviceType = ResponsiveHelper.getDeviceType(context);
        final isMobile = deviceType == DeviceType.mobile;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSectionHeader(title: 'Gastos por Categoría'),
                const SizedBox(height: AppSpacing.base),
                _buildChartLayout(gastos, total, isMobile, scheme),
                const Divider(height: 24),
                Text(
                  'TOP CATEGORÍAS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.outline,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                ...gastos.take(5).map((g) => _buildCategoriaRow(g, total)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Layout responsivo: Column en mobile, Row en tablet/desktop
  Widget _buildChartLayout(
    List<_CategoriaGasto> gastos,
    double total,
    bool isMobile,
    ColorScheme scheme,
  ) {
    final chartHeight = ResponsiveHelper.getChartHeight(context);
    final pieChart = _buildPieChart(gastos, total, scheme);

    if (isMobile) {
      // Mobile: Gráfico arriba, lista abajo
      return Column(
        children: [
          SizedBox(height: chartHeight, child: pieChart),
          const SizedBox(height: AppSpacing.md),
          _buildCategoryLegend(gastos, total, scheme),
        ],
      );
    }

    // Tablet/Desktop: Gráfico izquierda (40%), lista derecha (60%)
    return SizedBox(
      height: chartHeight,
      child: Row(
        children: [
          Expanded(flex: 40, child: pieChart),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            flex: 60,
            child: _buildCategoryLegend(gastos, total, scheme),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(
    List<_CategoriaGasto> gastos,
    double total,
    ColorScheme scheme,
  ) {
    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  response == null ||
                  response.touchedSection == null) {
                _sectorTocado = -1;
                return;
              }
              _sectorTocado = response.touchedSection!.touchedSectionIndex;
            });
          },
        ),
        sections: gastos.asMap().entries.map((e) {
          final isTouched = e.key == _sectorTocado;
          return PieChartSectionData(
            value: e.value.total,
            color: e.value.color,
            radius: isTouched ? 90 : 75,
            title: isTouched
                ? '${(e.value.total / total * 100).toStringAsFixed(1)}%'
                : '',
            titleStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: scheme.onPrimary,
            ),
          );
        }).toList(),
        centerSpaceRadius: 30,
        sectionsSpace: 2,
      ),
    );
  }

  Widget _buildCategoryLegend(
    List<_CategoriaGasto> gastos,
    double total,
    ColorScheme scheme,
  ) {
    return ListView(
      shrinkWrap: true,
      children: gastos.take(6).map((g) {
        final pct = (g.total / total * 100);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: g.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  g.nombre,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoriaRow(_CategoriaGasto g, double total) {
    final pct = g.total / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: g.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(g.nombre, style: const TextStyle(fontSize: 13)),
                ],
              ),
              Text(
                Formatters.monedaConSimbolo(g.total),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(g.color),
            ),
          ),
        ],
      ),
    );
  }

  // ── Evolución histórica ───────────────────────────────────────────────────

  Widget _buildEvolucionHistorica() {
    return FutureBuilder<List<_MesHistorico>>(
      future: _calcularHistorico(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final meses = snap.data!;
        if (meses.isEmpty) return const SizedBox.shrink();

        final scheme = Theme.of(context).colorScheme;
        final chartHeight = ResponsiveHelper.getChartHeight(context);
        final maxVal = meses
            .expand((m) => [m.ingresos, m.egresos])
            .fold<double>(0, (a, b) => a > b ? a : b);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Evolución últimos 6 meses',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    _buildLeyenda('Ingresos', AppTheme.incomeColor(context)),
                    const SizedBox(width: AppSpacing.md),
                    _buildLeyenda('Egresos', AppTheme.expenseColor(context)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: chartHeight,
                  child: BarChart(
                    BarChartData(
                      maxY: maxVal == 0 ? 1 : maxVal * 1.2,
                      barGroups: meses.asMap().entries.map((e) {
                        final i = e.key;
                        final m = e.value;
                        return BarChartGroupData(
                          x: i,
                          barsSpace: 4,
                          barRods: [
                            BarChartRodData(
                              toY: m.ingresos,
                              color: AppTheme.incomeColor(context),
                              width: 10,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(AppRadius.sm)),
                            ),
                            BarChartRodData(
                              toY: m.egresos,
                              color: AppTheme.expenseColor(context),
                              width: 10,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(AppRadius.sm)),
                            ),
                          ],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx < 0 || idx >= meses.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  meses[idx].nombreCorto,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeyenda(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: AppRadius.smBR),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  // ── Exportación ───────────────────────────────────────────────────────────

  Future<void> _exportarReporte(String formato) async {
    try {
      final resumen = await _calcularResumen();
      final cats = await _calcularGastosPorCategoria();
      final hist = await _calcularHistorico();

      final catsMapa = cats
          .map((c) => {'nombre': c.nombre, 'monto': c.total})
          .toList();

      final histMapa = hist
          .map((m) => {
                'mes': m.nombreCorto,
                'ingresos': m.ingresos,
                'egresos': m.egresos,
              })
          .toList();

      await ExportacionService.exportarReportePDF(
        periodoLabel: _nombreMesAnio(_mesSeleccionado),
        ingresos: resumen.ingresos,
        egresos: resumen.egresos,
        categorias: catsMapa,
        historico: histMapa,
      );
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

  // ── Cálculos de datos ─────────────────────────────────────────────────────

  Future<_ResumenMes> _calcularResumen() async {
    final db = widget.database;
    final txs = await (db.select(db.transacciones)
          ..where((t) =>
              t.fecha.isBiggerOrEqualValue(_inicioMes) &
              t.fecha.isSmallerOrEqualValue(_finMes)))
        .get();

    final cuotas = await (db.select(db.cuotas)
          ..where((c) =>
              c.fechaVencimiento.isBiggerOrEqualValue(_inicioMes) &
              c.fechaVencimiento.isSmallerOrEqualValue(_finMes) &
              c.pagada.equals(false)))
        .get();

    final ingresos = txs
        .where((t) => t.tipo == 'ingreso')
        .fold<double>(0, (s, t) => s + t.montoTotal);
    final egresosDebito = txs
        .where((t) => t.tipo == 'egreso' && t.formaPago == 'debito')
        .fold<double>(0, (s, t) => s + t.montoTotal);
    final totalCuotas = cuotas.fold<double>(0, (s, c) => s + c.monto);

    return _ResumenMes(
      ingresos: ingresos,
      egresos: egresosDebito + totalCuotas,
    );
  }

  Future<List<_CategoriaGasto>> _calcularGastosPorCategoria() async {
    final db = widget.database;

    final q = db.select(db.transacciones).join([
      leftOuterJoin(
          db.categorias, db.categorias.id.equalsExp(db.transacciones.categoriaId)),
    ]);
    q.where(db.transacciones.tipo.equals('egreso') &
        db.transacciones.fecha.isBiggerOrEqualValue(_inicioMes) &
        db.transacciones.fecha.isSmallerOrEqualValue(_finMes));

    final rows = await q.get();

    final Map<String, _CategoriaGasto> mapa = {};
    for (final r in rows) {
      final tx = r.readTable(db.transacciones);
      final cat = r.readTableOrNull(db.categorias);
      final nombre = cat?.nombre ?? 'Sin categoría';
      final color = cat != null
          ? Color(int.parse(cat.color.replaceFirst('#', '0xFF')))
          : Colors.grey;

      if (mapa.containsKey(nombre)) {
        mapa[nombre] = _CategoriaGasto(
          nombre: nombre,
          total: mapa[nombre]!.total + tx.montoTotal,
          color: color,
        );
      } else {
        mapa[nombre] = _CategoriaGasto(
          nombre: nombre,
          total: tx.montoTotal,
          color: color,
        );
      }
    }

    final lista = mapa.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return lista;
  }

  Future<List<_MesHistorico>> _calcularHistorico() async {
    final db = widget.database;
    final ahora = DateTime.now();
    final resultado = <_MesHistorico>[];

    for (int i = 5; i >= 0; i--) {
      final mes = DateTime(ahora.year, ahora.month - i, 1);
      final fin = DateTime(mes.year, mes.month + 1, 0, 23, 59, 59);

      final txs = await (db.select(db.transacciones)
            ..where((t) =>
                t.fecha.isBiggerOrEqualValue(mes) &
                t.fecha.isSmallerOrEqualValue(fin)))
          .get();

      final ingresos = txs
          .where((t) => t.tipo == 'ingreso')
          .fold<double>(0, (s, t) => s + t.montoTotal);
      final egresos = txs
          .where((t) => t.tipo == 'egreso')
          .fold<double>(0, (s, t) => s + t.montoTotal);

      resultado.add(_MesHistorico(fecha: mes, ingresos: ingresos, egresos: egresos));
    }

    return resultado;
  }

  // ── Utilidades ────────────────────────────────────────────────────────────

  String _nombreMesAnio(DateTime fecha) {
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${meses[fecha.month - 1]} ${fecha.year}';
  }
}

// ── Modelos locales ───────────────────────────────────────────────────────────

class _ResumenMes {
  final double ingresos;
  final double egresos;
  const _ResumenMes({required this.ingresos, required this.egresos});
}

class _CategoriaGasto {
  final String nombre;
  final double total;
  final Color color;
  const _CategoriaGasto(
      {required this.nombre, required this.total, required this.color});
}

class _MesHistorico {
  final DateTime fecha;
  final double ingresos;
  final double egresos;

  const _MesHistorico(
      {required this.fecha, required this.ingresos, required this.egresos});

  String get nombreCorto {
    const m = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return m[fecha.month - 1];
  }
}
