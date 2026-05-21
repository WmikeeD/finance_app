import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../core/navigation/app_tab_controller.dart';
import '../cuentas/cuentas_screen.dart';
import '../personas/personas_screen.dart';
import '../gastos_fijos/gastos_fijos_screen.dart';
import '../categorias/categorias_screen.dart';
import '../notificaciones/notificaciones_panel.dart';

class HomeScreen extends StatefulWidget {
  final AppDatabase database;

  const HomeScreen({super.key, required this.database});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(database: widget.database, currentRoute: '/home'),
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
                    icon: const Icon(Icons.notifications_outlined),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: AppSpacing.xl),
            _buildThreeCards(),
            const SizedBox(height: AppSpacing.base),
            _buildAhorroProgress(),
            const SizedBox(height: AppSpacing.base),
            _buildGastosFijosCard(),
            _buildAlertasCuotas(),
            const SizedBox(height: AppSpacing.xl),
            _buildRecentTransactions(),
            const SizedBox(height: AppSpacing.xl),
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.65),
          ],
        ),
        borderRadius: AppRadius.xlBR,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¡Bienvenido!',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Gestiona tus finanzas de manera inteligente',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.90),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeCards() {
    return StreamBuilder<List<Cuenta>>(
      stream: widget.database.select(widget.database.cuentas).watch(),
      builder: (context, snapshot) {
        final cuentas = snapshot.data ?? [];

        final balanceDisponible = cuentas
            .where((c) => c.tipo == 'efectivo' || c.tipo == 'debito')
            .fold(0.0, (sum, c) => sum + c.saldo);

        final creditoDisponible = cuentas
            .where((c) => c.tipo == 'credito')
            .fold(0.0, (sum, c) => sum + ((c.limiteCredito ?? 0) + c.saldo));

        return StreamBuilder<double>(
          stream: _calcularFlujoDelMes(),
          builder: (context, flujoSnapshot) {
            final flujoDelMes = flujoSnapshot.data ?? 0.0;

            return Row(
              children: [
                Expanded(
                  child: _buildBalanceCard(
                    'Balance',
                    balanceDisponible,
                    'Dinero real',
                    Icons.account_balance_wallet,
                    AppTheme.incomeColor(context),
                    () => _navigateToCuentas(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildBalanceCard(
                    'Crédito',
                    creditoDisponible,
                    'Disponible',
                    Icons.credit_card,
                    AppTheme.savingsColor(context),
                    () => _navigateToCuentas(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildBalanceCard(
                    'Flujo Mes',
                    flujoDelMes,
                    'Cuotas + Fijos',
                    Icons.trending_down,
                    flujoDelMes >= 0 ? AppTheme.incomeColor(context) : AppTheme.expenseColor(context),
                    () => _navigateToTransacciones(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBalanceCard(
    String title,
    double amount,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSemanticIcon(icon: icon, color: color, size: AppIconSize.sm),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                Formatters.monedaConSimbolo(amount),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: amount < 0 ? AppTheme.expenseColor(context) : null,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAhorroProgress() {
    return StreamBuilder<List<Cuenta>>(
      stream: widget.database
          .select(widget.database.cuentas)
          .watch()
          .map((cuentas) => cuentas.where((c) => c.tipo == 'ahorro').toList()),
      builder: (context, snapshot) {
        final cuentasAhorro = snapshot.data ?? [];
        if (cuentasAhorro.isEmpty) return const SizedBox.shrink();

        final totalAhorrado = cuentasAhorro.fold(0.0, (sum, c) => sum + c.saldo);
        final totalMeta = cuentasAhorro.fold(0.0, (sum, c) => sum + (c.meta ?? 0));
        if (totalMeta == 0) return const SizedBox.shrink();

        final progreso = (totalAhorrado / totalMeta).clamp(0.0, 1.0);
        final porcentaje = (progreso * 100).toStringAsFixed(1);
        final theme = Theme.of(context);

        return GestureDetector(
          onTap: () => _navigateToCuentas(),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppSemanticIcon(
                        icon: Icons.savings,
                        color: AppColors.alertCaution,
                        size: AppIconSize.sm,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ahorro',
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              '${Formatters.monedaConSimbolo(totalAhorrado)} / ${Formatters.monedaConSimbolo(totalMeta)} ($porcentaje%)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: AppRadius.mdBR,
                    child: LinearProgressIndicator(
                      value: progreso,
                      minHeight: 10,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progreso >= 1.0 ? AppColors.alertCelebrate : AppColors.alertCaution,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGastosFijosCard() {
    final theme = Theme.of(context);
    return StreamBuilder<List<GastoFijo>>(
      stream: widget.database.watchGastosFijos(soloActivos: true),
      builder: (context, snapshot) {
        final gastos = snapshot.data ?? [];
        if (gastos.isEmpty) return const SizedBox.shrink();

        final total = gastos.fold(0.0, (sum, g) => sum + g.monto);

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GastosFijosScreen(database: widget.database),
            ),
          ),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Row(
                children: [
                  AppSemanticIcon(
                    icon: Icons.repeat,
                    color: AppTheme.expenseColor(context),
                    size: AppIconSize.sm,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gastos Fijos Mensuales',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          '${gastos.length} gastos activos',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Formatters.monedaConSimbolo(total),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.expenseColor(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlertasCuotas() {
    final ahora = DateTime.now();
    final en7Dias = ahora.add(const Duration(days: 7));
    return StreamBuilder<List<Cuota>>(
      stream: (widget.database.select(widget.database.cuotas)
            ..where(
              (c) =>
                  c.pagada.equals(false) &
                  c.fechaVencimiento.isBiggerOrEqualValue(ahora) &
                  c.fechaVencimiento.isSmallerOrEqualValue(en7Dias),
            )
            ..orderBy([(c) => OrderingTerm.asc(c.fechaVencimiento)]))
          .watch(),
      builder: (context, snapshot) {
        final cuotas = snapshot.data ?? [];
        if (cuotas.isEmpty) return const SizedBox.shrink();

        final totalPendiente = cuotas.fold(0.0, (sum, c) => sum + c.monto);
        return AppInfoBanner(
          type: AppBannerType.warning,
          title: '${cuotas.length} cuota${cuotas.length == 1 ? '' : 's'} vence${cuotas.length == 1 ? '' : 'n'} en 7 días',
          subtitle: 'Total: ${Formatters.monedaConSimbolo(totalPendiente)}',
          onTap: () => AppTabController.goToProyeccion(),
        );
      },
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
              TextButton.icon(
                onPressed: () => _showAddTransaccionDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo'),
              ),
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
        icon: isIngreso ? Icons.arrow_downward : Icons.arrow_upward,
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

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: 'Acciones Rápidas'),
        const SizedBox(height: AppSpacing.md),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.1,
          children: [
            _buildActionCard(
              'Cuentas',
              Icons.account_balance_wallet,
              AppTheme.savingsColor(context),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CuentasScreen(database: widget.database)),
              ),
            ),
            _buildActionCard(
              'Reportes',
              Icons.bar_chart,
              AppTheme.creditColor(context),
              () => AppTabController.goToReportes(),
            ),
            _buildActionCard(
              'Proyección',
              Icons.trending_up,
              AppColors.alertOk,
              () => AppTabController.goToProyeccion(),
            ),
            _buildActionCard(
              'Personas',
              Icons.people,
              AppColors.alertCaution,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PersonasScreen(database: widget.database)),
              ),
            ),
            _buildActionCard(
              'Categorías',
              Icons.category,
              AppTheme.incomeColor(context),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CategoriasScreen(database: widget.database)),
              ),
            ),
            _buildActionCard(
              'Gastos Fijos',
              Icons.repeat,
              AppTheme.expenseColor(context),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GastosFijosScreen(database: widget.database)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgBR,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppSemanticIcon(icon: icon, color: color, size: AppIconSize.md),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
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

  void _navigateToCuentas() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CuentasScreen(database: widget.database)),
      );

  void _navigateToTransacciones() => AppTabController.goToTransacciones();

  void _showAddTransaccionDialog() => AppTabController.goToTransacciones();

  Stream<double> _calcularFlujoDelMes() {
    final now = DateTime.now();
    final inicioMes = DateTime(now.year, now.month, 1);
    final finMes = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return widget.database
        .select(widget.database.transacciones)
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
                c.pagada.equals(false)))
          .get();

      final totalCuotas = cuotasDelMes.fold(0.0, (sum, c) => sum + c.monto);
      final totalGastosFijos = await widget.database.totalGastosFijosActivos();

      return ingresos - egresosDebito - totalCuotas - totalGastosFijos;
    });
  }
}
