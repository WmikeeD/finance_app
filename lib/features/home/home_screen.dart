import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/widgets.dart';
import '../../core/navigation/app_tab_controller.dart';
import '../cuentas/cuentas_screen.dart';
import '../notificaciones/notificaciones_panel.dart';
import '../proyeccion/models/proyeccion_models.dart';
import 'widgets/liberacion_deuda_banner.dart';
import 'widgets/proyeccion_cuotas_mini.dart';
import '../transacciones/presentation/widgets/crear_transaccion_sheet.dart';

class HomeScreen extends StatefulWidget {
  final AppDatabase database;

  const HomeScreen({super.key, required this.database});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final horizontalPadding = ResponsiveHelper.getHorizontalPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          StreamBuilder<int>(
            stream: _contarAlertas(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: PhosphorIcon(PhosphorIconsRegular.bell),
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (_) => NotificacionesPanel(database: widget.database),
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Badge(
                        label: Text('$count'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: _buildResponsiveFAB(context),
      floatingActionButtonLocation: context.isTabletOrDesktop
          ? FloatingActionButtonLocation.endDocked
          : FloatingActionButtonLocation.endFloat,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: AppSpacing.base,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarjeta dominante de Estado Financiero
            _buildFinancialStatusCard(),
            const SizedBox(height: AppSpacing.xl),

            // Banner de Liberación de Deuda (condicional)
            StreamBuilder<MesLiberacion?>(
              stream: _obtenerMesLiberacion(),
              builder: (context, snapshot) {
                final liberacion = snapshot.data;
                if (liberacion == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.base),
                  child: LiberacionDeudaBanner(liberacion: liberacion),
                );
              },
            ),

            // Mini gráfico de proyección
            StreamBuilder<List<({DateTime mes, double total})>>(
              stream: _calcularProyeccionSimple(),
              builder: (context, snapshot) {
                final proyeccion = snapshot.data ?? [];
                if (proyeccion.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.base),
                  child: ProyeccionCuotasMiniCard(proyeccion: proyeccion),
                );
              },
            ),

            const SizedBox(height: AppSpacing.xl),
            _buildRecentTransactions(),
          ],
        ),
      ),
    );
  }

  /// Tarjeta dominante de Estado Financiero con jerarquía visual
  /// Diseño responsivo: tipografía y padding escalan según dispositivo
  Widget _buildFinancialStatusCard() {
    return StreamBuilder<List<Cuenta>>(
      stream: (widget.database.select(widget.database.cuentas)
            ..where((c) => c.activa.equals(true)))
          .watch(),
      builder: (context, snapshot) {
        // Mostrar loading placeholder mientras espera datos
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingBalanceCard();
        }

        final cuentas = snapshot.data ?? [];

        // Balance Total (efectivo + débito) - usa saldos recalculados
        final balanceTotal = cuentas
            .where((c) => c.tipo == 'efectivo' || c.tipo == 'debito')
            .fold(0.0, (sum, c) => sum + c.saldo);

        // Crédito disponible
        final creditoDisponible = cuentas
            .where((c) => c.tipo == 'credito')
            .fold(0.0, (sum, c) => sum + ((c.limiteCredito ?? 0) + c.saldo));

        return StreamBuilder<double>(
          stream: _calcularFlujoDelMes(),
          builder: (context, flujoSnapshot) {
            final flujoDelMes = flujoSnapshot.data ?? 0.0;

            // Color dinámico según balance (sistema de zonas)
            final colorZona = AppTheme.calcularColorDinamico(
              balanceTotal,
              100000, // minimo
              5000000, // maximo
            );
            final nombreZona = AppTheme.nombreZonaDinamica(
              balanceTotal,
              100000,
              5000000,
            );

            return _buildMainBalanceCard(
              balanceTotal: balanceTotal,
              creditoDisponible: creditoDisponible,
              flujoDelMes: flujoDelMes,
              colorZona: colorZona,
              nombreZona: nombreZona,
            );
          },
        );
      },
    );
  }

  /// Loading placeholder para la tarjeta de balance mientras carga datos
  Widget _buildLoadingBalanceCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final deviceType = ResponsiveHelper.getDeviceType(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        deviceType == DeviceType.mobile ? AppSpacing.lg : AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.xlBR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shimmer para zona de color
          Container(
            width: 120,
            height: 24,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: AppRadius.lgBR,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Shimmer para label "Balance Total"
          Container(
            width: 100,
            height: 14,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Shimmer para monto principal
          Container(
            width: 200,
            height: deviceType == DeviceType.mobile ? 36 : 48,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Shimmer para métricas secundarias
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: AppRadius.lgBR,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: AppRadius.lgBR,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainBalanceCard({
    required double balanceTotal,
    required double creditoDisponible,
    required double flujoDelMes,
    required Color colorZona,
    required String nombreZona,
  }) {
    final theme = Theme.of(context);
    final deviceType = ResponsiveHelper.getDeviceType(context);

    // Tipografía responsiva
    final displayStyle = deviceType == DeviceType.mobile
        ? theme.textTheme.displaySmall
        : theme.textTheme.displayMedium;

    final titleStyle = deviceType == DeviceType.mobile
        ? theme.textTheme.titleMedium
        : theme.textTheme.titleLarge;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        deviceType == DeviceType.mobile ? AppSpacing.lg : AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorZona,
            colorZona.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: AppRadius.xlBR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zona de color actual
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: AppRadius.lgBR,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(
                  PhosphorIconsRegular.sparkle,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  nombreZona,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Balance Total (jerárquico, dominante)
          Text(
            'Balance Total',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            Formatters.monedaConSimbolo(balanceTotal),
            style: displayStyle?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Grid de métricas secundarias (2 columnas en mobile, 3 en tablet+)
          _buildSecondaryMetrics(
            creditoDisponible: creditoDisponible,
            flujoDelMes: flujoDelMes,
            titleStyle: titleStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryMetrics({
    required double creditoDisponible,
    required double flujoDelMes,
    required TextStyle? titleStyle,
  }) {
    final isMobile = ResponsiveHelper.isMobile(context);

    final metrics = [
      _MetricData(
        icon: PhosphorIconsRegular.creditCard,
        label: 'Crédito Disponible',
        value: Formatters.monedaConSimbolo(creditoDisponible),
        onTap: () => _navigateToCuentas(),
      ),
      _MetricData(
        icon: flujoDelMes >= 0
            ? PhosphorIconsRegular.trendUp
            : PhosphorIconsRegular.trendDown,
        label: 'Flujo del Mes',
        value: Formatters.monedaConSimbolo(flujoDelMes),
        color: flujoDelMes >= 0
            ? AppColors.alertOk
            : AppColors.alertWarning,
        onTap: () => _navigateToTransacciones(),
      ),
    ];

    if (isMobile) {
      // Mobile: 2 columnas
      return Row(
        children: [
          Expanded(
            child: _buildMetricItem(metrics[0], titleStyle),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _buildMetricItem(metrics[1], titleStyle),
          ),
        ],
      );
    }

    // Tablet/Desktop: 2 columnas más espaciadas
    return Row(
      children: [
        Expanded(
          child: _buildMetricItem(metrics[0], titleStyle),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _buildMetricItem(metrics[1], titleStyle),
        ),
      ],
    );
  }

  Widget _buildMetricItem(_MetricData metric, TextStyle? titleStyle) {
    return GestureDetector(
      onTap: metric.onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: AppRadius.lgBR,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PhosphorIcon(
              metric.icon,
              color: metric.color ?? Colors.white,
              size: 20,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              metric.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              metric.value,
              style: titleStyle?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// FAB responsivo: tamaño y posición adaptativos
  Widget _buildResponsiveFAB(BuildContext context) {
    final isTabletOrDesktop = context.isTabletOrDesktop;

    if (isTabletOrDesktop) {
      // Tablet/Desktop: FAB extendido
      return FloatingActionButton.extended(
        onPressed: () => _showAddTransaccionDialog(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: PhosphorIcon(PhosphorIconsRegular.plus, color: Colors.white),
        label: const Text(
          'Nueva Transacción',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    // Mobile: FAB circular estándar
    return FloatingActionButton(
      onPressed: () => _showAddTransaccionDialog(),
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: PhosphorIcon(PhosphorIconsRegular.plus, color: Colors.white),
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Transacciones Recientes',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.tonal(
                onPressed: () => _showAddTransaccionDialog(),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 18),
                    SizedBox(width: 4),
                    Text('Nuevo'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _navigateToTransacciones(),
                child: const Text('Ver Todas →'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        StreamBuilder<List<Transaccion>>(
          stream: (widget.database.select(widget.database.transacciones)
                ..where((t) => t.deletedAt.isNull())
                ..orderBy([
                  (t) => OrderingTerm(
                        expression: t.fecha,
                        mode: OrderingMode.desc,
                      )
                ]))
              .watch()
              .map((list) => list.take(5).toList()),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final transacciones = snapshot.data ?? [];

            if (transacciones.isEmpty) {
              return AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No hay transacciones todavía',
                buttonLabel: 'Crear primera transacción',
                onAction: () => _showAddTransaccionDialog(),
              );
            }

            return Card(
              child: Column(
                children: transacciones.map((t) => _buildTransactionTile(t)).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTransactionTile(Transaccion transaccion) {
    final isIngreso = transaccion.tipo == 'ingreso';
    final color = isIngreso ? AppTheme.incomeColor(context) : AppTheme.expenseColor(context);
    final theme = Theme.of(context);

    return ListTile(
      leading: AppSemanticIcon(
        icon: isIngreso ? PhosphorIconsRegular.arrowDownLeft : PhosphorIconsRegular.arrowUpRight,
        color: color,
        size: AppIconSize.sm,
      ),
      title: Text(
        transaccion.descripcion,
        style: theme.textTheme.labelLarge,
      ),
      subtitle: Text(
        Formatters.fecha(transaccion.fecha),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      trailing: Text(
        '${isIngreso ? '+' : '-'}${Formatters.monedaConSimbolo(transaccion.montoTotal)}',
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }


  // ==========================================
  // NAVEGACIÓN Y CÁLCULOS
  // ==========================================

  Stream<int> _contarAlertas() {
    final ahora = DateTime.now();
    final en30Dias = ahora.add(const Duration(days: 30));
    return (widget.database.select(widget.database.cuotas)
          ..where(
            (c) =>
                c.pagada.equals(false) &
                c.fechaVencimiento.isBiggerOrEqualValue(ahora) &
                c.fechaVencimiento.isSmallerOrEqualValue(en30Dias),
          ))
        .watch()
        .asyncMap((cuotas) async {
      final deudas = await (widget.database.select(widget.database.deudas)
            ..where((d) => d.estado.isNotIn(['pagada'])))
          .get();
      return cuotas.length + deudas.length;
    });
  }

  void _navigateToCuentas() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ResponsiveHelper.wrapModal(
          context: context,
          child: CuentasScreen(database: widget.database),
        ),
      );

  void _navigateToTransacciones() => AppTabController.goToTransacciones();

  void _showAddTransaccionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ResponsiveHelper.wrapModal(
        context: context,
        child: CrearTransaccionSheet(database: widget.database),
      ),
    );
  }

  /// Calcula la proyección simplificada de los próximos 3 meses
  /// Incluye cuotas + gastos fijos mensuales
  Stream<List<({DateTime mes, double total})>> _calcularProyeccionSimple() {
    final ahora = DateTime.now();
    final mes1 = DateTime(ahora.year, ahora.month + 1, 1);
    final mes2 = DateTime(ahora.year, ahora.month + 2, 1);
    final mes3 = DateTime(ahora.year, ahora.month + 3, 1);
    final limite = DateTime(ahora.year, ahora.month + 4, 0, 23, 59, 59);

    return (widget.database.select(widget.database.cuotas)
          ..where((c) =>
              c.pagada.equals(false) &
              c.fechaVencimiento.isBiggerOrEqualValue(mes1) &
              c.fechaVencimiento.isSmallerOrEqualValue(limite)))
        .watch()
        .asyncMap((cuotas) async {
      // Obtener total de gastos fijos mensuales
      final gastosFijosMensual =
          await widget.database.totalGastosFijosActivos();

      // Agrupar cuotas por mes y sumar
      final Map<int, double> cuotasPorMes = {};
      for (final c in cuotas) {
        final mes = c.fechaVencimiento.month;
        cuotasPorMes[mes] = (cuotasPorMes[mes] ?? 0) + c.monto;
      }

      // Retornar lista de 3 meses con cuotas + gastos fijos
      return [
        (
          mes: mes1,
          total: (cuotasPorMes[mes1.month] ?? 0) + gastosFijosMensual
        ),
        (
          mes: mes2,
          total: (cuotasPorMes[mes2.month] ?? 0) + gastosFijosMensual
        ),
        (
          mes: mes3,
          total: (cuotasPorMes[mes3.month] ?? 0) + gastosFijosMensual
        ),
      ];
    });
  }

  /// Obtiene el mes de liberación de deudas
  /// Considera tanto cuotas de crédito como deudas de personas
  Stream<MesLiberacion?> _obtenerMesLiberacion() async* {
    // Query última cuota pendiente
    final cuotasPendientes = await (widget.database.select(widget.database.cuotas)
          ..where((c) => c.pagada.equals(false))
          ..orderBy([(c) => OrderingTerm.desc(c.fechaVencimiento)])
          ..limit(1))
        .get();

    // Query última deuda pendiente (con fecha acordada de pago)
    final deudasPendientes = await (widget.database.select(widget.database.deudas)
          ..where((d) =>
              d.estado.isNotIn(['pagada']) & d.fechaAcordadaPago.isNotNull())
          ..orderBy([(d) => OrderingTerm.desc(d.fechaAcordadaPago)])
          ..limit(1))
        .get();

    // Si no hay ni cuotas ni deudas
    if (cuotasPendientes.isEmpty && deudasPendientes.isEmpty) {
      yield null;
      return;
    }

    // Determinar cuál es la fecha más lejana
    DateTime fechaLiberacion;
    bool esDeuda;

    if (deudasPendientes.isNotEmpty && cuotasPendientes.isNotEmpty) {
      final fechaDeuda = deudasPendientes.first.fechaAcordadaPago!;
      final fechaCuota = cuotasPendientes.first.fechaVencimiento;
      esDeuda = fechaDeuda.isAfter(fechaCuota);
      fechaLiberacion = esDeuda ? fechaDeuda : fechaCuota;
    } else if (deudasPendientes.isNotEmpty) {
      esDeuda = true;
      fechaLiberacion = deudasPendientes.first.fechaAcordadaPago!;
    } else {
      esDeuda = false;
      fechaLiberacion = cuotasPendientes.first.fechaVencimiento;
    }

    // Obtener descripción
    String descripcion;
    double monto;
    if (esDeuda) {
      final deuda = deudasPendientes.first;
      final persona = await (widget.database.select(widget.database.personas)
            ..where((p) => p.id.equals(deuda.personaId)))
          .getSingle();
      descripcion = 'Deuda de ${persona.nombre}';
      monto = deuda.montoPendiente;
    } else {
      final cuota = cuotasPendientes.first;
      final tx = await (widget.database.select(widget.database.transacciones)
            ..where((t) => t.id.equals(cuota.transaccionId)))
          .getSingle();
      descripcion = tx.descripcion;
      monto = cuota.monto;
    }

    final ahora = DateTime.now();
    final mesesFaltantes = ((fechaLiberacion.year - ahora.year) * 12 +
            fechaLiberacion.month -
            ahora.month)
        .clamp(0, 999);

    yield MesLiberacion(
      fecha: fechaLiberacion,
      descripcionUltima: descripcion,
      montoUltima: monto,
      tarjetaUltima: '',
      mesesFaltantes: mesesFaltantes,
    );
  }

  Stream<double> _calcularFlujoDelMes() {
    final now = DateTime.now();
    final inicioMes = DateTime(now.year, now.month, 1);
    final finMes = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return (widget.database.select(widget.database.transacciones)
          ..where((t) => t.deletedAt.isNull()))
        .watch()
        .asyncMap((transacciones) async {
      final transaccionesDelMes = transacciones
          .where((t) =>
              t.fecha.isAfter(inicioMes.subtract(const Duration(days: 1))) &&
              t.fecha.isBefore(finMes.add(const Duration(days: 1))))
          .toList();

      final ingresos = transaccionesDelMes
          .where((t) => t.tipo == 'ingreso')
          .fold(0.0, (sum, t) => sum + t.montoTotal);

      final egresosDebito = transaccionesDelMes
          .where((t) => t.tipo == 'egreso' && t.formaPago == 'debito')
          .fold(0.0, (sum, t) => sum + t.montoTotal);

      final cuotasDelMes = await (widget.database.select(widget.database.cuotas)
            ..where((c) =>
                c.fechaVencimiento.isBiggerOrEqualValue(inicioMes) &
                c.fechaVencimiento.isSmallerOrEqualValue(finMes) &
                c.pagada.equals(false) &
                c.deletedAt.isNull()))
          .get();

      final totalCuotas = cuotasDelMes.fold(0.0, (sum, c) => sum + c.monto);
      final totalGastosFijos = await widget.database.totalGastosFijosActivos();

      return ingresos - egresosDebito - totalCuotas - totalGastosFijos;
    });
  }
}

/// Clase auxiliar para métricas secundarias del Dashboard
class _MetricData {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  final VoidCallback onTap;

  _MetricData({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    required this.onTap,
  });
}
