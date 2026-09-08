import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/database/database.dart';
import '../../core/services/exportacion_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/widgets.dart';
import 'data/reportes_repository.dart';
import 'models/reporte_models.dart';

enum ReportesTab { flujoCaja, creditoCuotas, saludFinanciera }

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
  ReportesTab _tabSeleccionada = ReportesTab.flujoCaja;

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
    final mesActual = DateTime(ahora.year, ahora.month, 1);
    final siguiente =
        DateTime(_mesSeleccionado.year, _mesSeleccionado.month + 1, 1);

    // Reportes solo muestra datos históricos o del mes en curso
    // No permitir avanzar a meses futuros
    if (siguiente.isBefore(mesActual) ||
        (siguiente.year == mesActual.year && siguiente.month == mesActual.month)) {
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
          _buildTabSelector(),
          const SizedBox(height: AppSpacing.lg),
          _buildContenidoSegunTab(),
        ],
      ),
    );
  }

  // ── Selector de mes ───────────────────────────────────────────────────────

  Widget _buildSelectorMes() {
    final nombre = _nombreMesAnio(_mesSeleccionado);
    final ahora = DateTime.now();
    final mesActual = DateTime(ahora.year, ahora.month, 1);

    // Determina si estamos en el mes actual (límite de navegación hacia adelante)
    final enMesActual = _mesSeleccionado.year == mesActual.year &&
        _mesSeleccionado.month == mesActual.month;

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
        Opacity(
          opacity: enMesActual ? 0.3 : 1.0,
          child: IconButton(
            icon: PhosphorIcon(PhosphorIconsRegular.caretRight),
            onPressed: enMesActual ? null : _mesSiguiente,
          ),
        ),
      ],
    );
  }

  // ── Selector de tabs ──────────────────────────────────────────────────────

  Widget _buildTabSelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ancho disponible para el SegmentedButton
        final availableWidth = constraints.maxWidth;

        // Adaptación dinámica de etiquetas según ancho real
        final textoFlujoCaja = availableWidth >= 560 ? 'Flujo de Caja' : 'Flujo';
        final textoCredito = availableWidth >= 560 ? 'Crédito y Cuotas' : 'Crédito';
        final textoSalud = availableWidth >= 560 ? 'Salud Financiera' : 'Salud';

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 680,
              ),
              child: SegmentedButton<ReportesTab>(
                segments: [
                  ButtonSegment<ReportesTab>(
                    value: ReportesTab.flujoCaja,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        textoFlujoCaja,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    icon: PhosphorIcon(PhosphorIconsRegular.arrowsLeftRight, size: 16),
                  ),
                  ButtonSegment<ReportesTab>(
                    value: ReportesTab.creditoCuotas,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        textoCredito,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    icon: PhosphorIcon(PhosphorIconsRegular.creditCard, size: 16),
                  ),
                  ButtonSegment<ReportesTab>(
                    value: ReportesTab.saludFinanciera,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        textoSalud,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    icon: PhosphorIcon(PhosphorIconsRegular.chartDonut, size: 16),
                  ),
                ],
                selected: {_tabSeleccionada},
                onSelectionChanged: (Set<ReportesTab> newSelection) {
                  setState(() {
                    _tabSeleccionada = newSelection.first;
                  });
                },
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Contenido según tab seleccionada ──────────────────────────────────────

  Widget _buildContenidoSegunTab() {
    switch (_tabSeleccionada) {
      case ReportesTab.flujoCaja:
        return _buildVistaFlujoCaja();
      case ReportesTab.creditoCuotas:
        return _buildVistaCreditoCuotas();
      case ReportesTab.saludFinanciera:
        return _buildVistaSaludFinanciera();
    }
  }

  // ── VISTA 1: Flujo de Caja ────────────────────────────────────────────────

  Widget _buildVistaFlujoCaja() {
    return Column(
      children: [
        _buildResumenMes(),
        const SizedBox(height: AppSpacing.lg),
        _buildEvolucionHistorica(),
        const SizedBox(height: AppSpacing.lg),
        _buildGastosPorCategoria(),
      ],
    );
  }

  // ── VISTA 2: Crédito y Cuotas ─────────────────────────────────────────────

  Widget _buildVistaCreditoCuotas() {
    return Column(
      children: [
        _buildInfoCreditoCuotas(),
        const SizedBox(height: AppSpacing.lg),
        _buildSabanaFacturacion(),
      ],
    );
  }

  Widget _buildSabanaFacturacion() {
    return StreamBuilder<List<FacturacionTarjetaModel>>(
      stream: _repository.watchDetalleFacturacionTarjetas(_mesSeleccionado),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final tarjetas = snapshot.data!;

        if (tarjetas.isEmpty) {
          return _buildEstadoVacioCredito();
        }

        return Column(
          children: tarjetas.map((tarjeta) => _buildTarjetaCard(tarjeta)).toList(),
        );
      },
    );
  }

  Widget _buildEstadoVacioCredito() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: Column(
            children: [
              PhosphorIcon(
                PhosphorIconsRegular.checkCircle,
                size: 48,
                color: AppTheme.incomeColor(context),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sin Compromisos de Crédito',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No hay cuotas exigibles para este período',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTarjetaCard(FacturacionTarjetaModel tarjeta) {
    final scheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd/MM');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado de la tarjeta
            Row(
              children: [
                PhosphorIcon(
                  PhosphorIconsRegular.creditCard,
                  size: 20,
                  color: AppTheme.creditColor(context),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tarjeta.nombreTarjeta,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Cierre: ${dateFormat.format(tarjeta.fechaCierre)} • Vence: ${dateFormat.format(tarjeta.fechaVencimiento)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildBadgeEstado(tarjeta),
              ],
            ),
            const Divider(height: AppSpacing.lg),

            // Mini desglose financiero
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMontoLabel(
                  'Facturado',
                  tarjeta.totalFacturado,
                  scheme.onSurface,
                ),
                _buildMontoLabel(
                  'Abonos',
                  -tarjeta.totalAbonado,
                  AppTheme.incomeColor(context),
                ),
                _buildMontoLabel(
                  // Cambiar label según estado
                  tarjeta.enFacturacion ? 'Por Facturar' : 'Saldo a Pagar',
                  tarjeta.saldoPendiente,
                  // Color según estado
                  tarjeta.alDia
                      ? AppTheme.incomeColor(context)
                      : tarjeta.enFacturacion
                          ? scheme.onSurfaceVariant
                          : AppTheme.expenseColor(context),
                  destacado: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Lista de cuotas
            ...tarjeta.cuotas.map((cuota) => _buildCuotaItem(cuota)),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeEstado(FacturacionTarjetaModel tarjeta) {
    final scheme = Theme.of(context).colorScheme;
    Color color;
    String texto;

    if (tarjeta.alDia) {
      color = AppTheme.incomeColor(context);
      texto = 'Al Día';
    } else if (tarjeta.vencido) {
      color = AppTheme.expenseColor(context);
      texto = 'Vencido';
    } else if (tarjeta.enFacturacion) {
      // Ciclo abierto, aún no es exigible
      color = scheme.primary;
      texto = 'En Facturación';
    } else if (tarjeta.porPagar) {
      // Ciclo cerrado, dentro del plazo
      color = AppColors.warning;
      texto = 'Por Pagar';
    } else {
      color = scheme.onSurfaceVariant;
      texto = 'Desconocido';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMontoLabel(String label, double monto, Color color, {bool destacado = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          Formatters.monedaConSimbolo(monto.abs()),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: destacado ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildCuotaItem(CuotaDetalleModel cuota) {
    final scheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd/MM');

    // Color según estado: vencida (rojo), pagada (verde), pendiente (neutro)
    final color = cuota.esVencida
        ? AppTheme.expenseColor(context)
        : cuota.pagada
            ? AppTheme.incomeColor(context)
            : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cuota.descripcion,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                if (cuota.esVencida)
                  Text(
                    'Venció el ${dateFormat.format(cuota.fechaVencimiento)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.expenseColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Cuota ${cuota.etiquetaCuota}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            Formatters.monedaConSimbolo(cuota.monto),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── VISTA 3: Salud Financiera ─────────────────────────────────────────────

  Widget _buildVistaSaludFinanciera() {
    return StreamBuilder<ResumenFinanciero>(
      stream: _repository.watchResumenMes(_inicioMes, _finMes),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final r = snap.data!;
        final tasaAhorro = r.ingresos > 0
            ? ((r.ingresos - r.egresos) / r.ingresos * 100)
            : 0.0;
        final color = tasaAhorro >= 20
            ? AppTheme.incomeColor(context)
            : tasaAhorro >= 10
                ? AppColors.warning
                : AppTheme.expenseColor(context);
        final diagnostico = tasaAhorro >= 20
            ? 'Excelente'
            : tasaAhorro >= 10
                ? 'Aceptable'
                : 'Crítico';

        return Column(
          children: [
            _buildSaludCard(
              'Tasa de Ahorro',
              '${tasaAhorro.toStringAsFixed(1)}%',
              PhosphorIconsRegular.piggyBank,
              color,
              diagnostico,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildSaludCard(
              'Balance Operativo',
              Formatters.monedaConSimbolo(r.balance),
              PhosphorIconsRegular.scales,
              r.balance >= 0 ? AppTheme.incomeColor(context) : AppTheme.expenseColor(context),
              r.balance >= 0 ? 'Positivo' : 'Déficit',
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildProporcionGastos(),
          ],
        );
      },
    );
  }

  Widget _buildSaludCard(
    String titulo,
    String valor,
    IconData icon,
    Color color,
    String diagnostico,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            AppSemanticIcon(icon: icon, color: color, size: AppIconSize.md),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    valor,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Text(
                diagnostico,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProporcionGastos() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Column(
            children: [
              PhosphorIcon(
                PhosphorIconsRegular.chartPie,
                size: 48,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Gastos Fijos vs Variables',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Próximamente: análisis de gastos recurrentes',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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
