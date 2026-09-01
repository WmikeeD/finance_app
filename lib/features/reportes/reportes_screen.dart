import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/database/database.dart';
import '../../core/services/exportacion_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/widgets.dart';
import 'data/reportes_repository.dart';
import 'models/reporte_models.dart';

class ReportesScreen extends StatefulWidget {
  final AppDatabase database;

  const ReportesScreen({super.key, required this.database});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  late DateTime _mesSeleccionado;
  late ReportesRepository _repository;
  int? _sectorTocado;
  String? _filtroGastosCategoria; // 'debito', 'credito', o null (consolidado)

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _mesSeleccionado = DateTime(now.year, now.month, 1);
    _repository = ReportesRepository(widget.database);
    _filtroGastosCategoria = 'debito'; // Por defecto: Flujo de Caja
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
    // Permitir avanzar hasta 12 meses en el futuro para proyección de cuotas
    final limitesFuturo = DateTime(ahora.year, ahora.month + 12, 1);
    if (siguiente.isBefore(limitesFuturo) ||
        siguiente.month == limitesFuturo.month && siguiente.year == limitesFuturo.year) {
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
          _buildInfoCreditoCuotas(),
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
    final ahora = DateTime.now();
    final limitesFuturo = DateTime(ahora.year, ahora.month + 12, 1);
    final enLimiteFuturo = _mesSeleccionado.year == limitesFuturo.year &&
        _mesSeleccionado.month == limitesFuturo.month;
    final esFuturo = _mesSeleccionado.isAfter(DateTime(ahora.year, ahora.month, 1));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: PhosphorIcon(PhosphorIconsRegular.caretLeft),
          onPressed: _mesAnterior,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              nombre,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (esFuturo)
              Text(
                'Proyección',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.creditColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        IconButton(
          icon: PhosphorIcon(PhosphorIconsRegular.caretRight),
          onPressed: enLimiteFuturo ? null : _mesSiguiente,
        ),
      ],
    );
  }

  // ── Resumen del mes ───────────────────────────────────────────────────────

  Widget _buildResumenMes() {
    return StreamBuilder<ResumenFinanciero>(
      stream: _repository.watchResumenMes(_inicioMes, _finMes),
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
                r.balance,
                PhosphorIconsRegular.scales,
                r.balance >= 0 ? AppTheme.incomeColor(context) : AppTheme.expenseColor(context),
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

  // ── Información de crédito y cuotas ───────────────────────────────────────

  Widget _buildInfoCreditoCuotas() {
    return StreamBuilder<double>(
      stream: _repository.watchCuotasMensuales(_inicioMes, _finMes),
      builder: (_, cuotasMesSnap) {
        return StreamBuilder<double>(
          stream: _repository.watchDeudaTotalCuotasPendientes(),
          builder: (_, deudaTotalSnap) {
            final cuotasMes = cuotasMesSnap.data ?? 0;
            final deudaTotal = deudaTotalSnap.data ?? 0;
            final scheme = Theme.of(context).colorScheme;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              PhosphorIcon(
                                PhosphorIconsRegular.creditCard,
                                size: 16,
                                color: AppTheme.creditColor(context),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'Cuotas este Mes',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            Formatters.monedaConSimbolo(cuotasMes),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.creditColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: scheme.outlineVariant,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              PhosphorIcon(
                                PhosphorIconsRegular.calendar,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'Deuda Total Futura',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            Formatters.monedaConSimbolo(deudaTotal),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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

  // ── Selector de tipo de gasto ─────────────────────────────────────────────

  Widget _buildSelectorTipoGasto() {
    return SegmentedButton<String?>(
      segments: [
        ButtonSegment<String?>(
          value: 'debito',
          label: Text(
            'Flujo de Caja',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          icon: PhosphorIcon(
            PhosphorIconsRegular.coins,
            size: 16,
          ),
        ),
        ButtonSegment<String?>(
          value: 'credito',
          label: Text(
            'Compras a Crédito',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          icon: PhosphorIcon(
            PhosphorIconsRegular.creditCard,
            size: 16,
          ),
        ),
        ButtonSegment<String?>(
          value: null,
          label: Text(
            'Consolidado',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          icon: PhosphorIcon(
            PhosphorIconsRegular.chartPie,
            size: 16,
          ),
        ),
      ],
      selected: {_filtroGastosCategoria},
      onSelectionChanged: (Set<String?> newSelection) {
        setState(() {
          _filtroGastosCategoria = newSelection.first;
        });
      },
      showSelectedIcon: false,
    );
  }

  // ── Gastos por categoría ──────────────────────────────────────────────────

  Widget _buildGastosPorCategoria() {
    return StreamBuilder<List<CategoriaGastoReporte>>(
      stream: _repository.watchGastosPorCategoria(
        _inicioMes,
        _finMes,
        filtroFormaPago: _filtroGastosCategoria,
      ),
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

        final total = gastos.fold<double>(0, (s, g) => s + g.totalGasto);
        final deviceType = ResponsiveHelper.getDeviceType(context);
        final isMobile = deviceType == DeviceType.mobile;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSectionHeader(title: 'Gastos por Categoría'),
                const SizedBox(height: AppSpacing.sm),
                _buildSelectorTipoGasto(),
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
    List<CategoriaGastoReporte> gastos,
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
    List<CategoriaGastoReporte> gastos,
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
            value: e.value.totalGasto,
            color: e.value.colorFlutter,
            radius: isTouched ? 90 : 75,
            title: isTouched
                ? '${e.value.porcentajeTotal.toStringAsFixed(1)}%'
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
    List<CategoriaGastoReporte> gastos,
    double total,
    ColorScheme scheme,
  ) {
    return ListView(
      shrinkWrap: true,
      children: gastos.take(6).map((g) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: g.colorFlutter,
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
                '${g.porcentajeTotal.toStringAsFixed(0)}%',
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

  Widget _buildCategoriaRow(CategoriaGastoReporte g, double total) {
    final pct = g.totalGasto / total;
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
                      color: g.colorFlutter,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(g.nombre, style: const TextStyle(fontSize: 13)),
                ],
              ),
              Text(
                Formatters.monedaConSimbolo(g.totalGasto),
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
              valueColor: AlwaysStoppedAnimation(g.colorFlutter),
            ),
          ),
        ],
      ),
    );
  }

  // ── Evolución histórica ───────────────────────────────────────────────────

  Widget _buildEvolucionHistorica() {
    return StreamBuilder<List<MesHistoricoReporte>>(
      stream: _repository.watchHistoricoUltimosMeses(6),
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
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => scheme.inverseSurface,
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          tooltipMargin: 8,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final isIngresos = rodIndex == 0;
                            final label = isIngresos ? 'Ingresos' : 'Egresos';
                            final value = Formatters.monedaConSimbolo(rod.toY);
                            return BarTooltipItem(
                              '$label\n$value',
                              TextStyle(
                                color: scheme.onInverseSurface,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ),
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
                                  meses[idx].nombreMes,
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
      // Obtener datos del repositorio (consolidado para exportación)
      final resumen = await _repository.watchResumenMes(_inicioMes, _finMes).first;
      final cats = await _repository.watchGastosPorCategoria(
        _inicioMes,
        _finMes,
        filtroFormaPago: null, // Consolidado en exportación
      ).first;
      final hist = await _repository.getHistoricoUltimosMeses(6);

      final catsMapa = cats
          .map((c) => {'nombre': c.nombre, 'monto': c.totalGasto})
          .toList();

      final histMapa = hist
          .map((m) => {
                'mes': m.nombreMes,
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


  // ── Utilidades ────────────────────────────────────────────────────────────

  String _nombreMesAnio(DateTime fecha) {
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${meses[fecha.month - 1]} ${fecha.year}';
  }
}
