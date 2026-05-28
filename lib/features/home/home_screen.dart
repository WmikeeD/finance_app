import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
import '../proyeccion/models/proyeccion_models.dart';
import 'widgets/liberacion_deuda_banner.dart';
import 'widgets/proyeccion_cuotas_mini.dart';
import 'widgets/crear_transaccion_modal.dart';

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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransaccionDialog(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: PhosphorIcon(PhosphorIconsRegular.plus, color: Colors.white),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¡Bienvenido!',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
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
                    PhosphorIconsRegular.wallet,
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
                    PhosphorIconsRegular.creditCard,
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
                    PhosphorIconsRegular.trendDown,
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
    final scheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: AppRadius.lgBR,
          border: Border.all(
            color: scheme.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PhosphorIcon(icon, color: color, size: 28),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              Formatters.monedaConSimbolo(amount),
              style: theme.textTheme.titleMedium?.copyWith(
                color: amount < 0 ? AppTheme.expenseColor(context) : null,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.outline,
              ),
            ),
          ],
        ),
      ),
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
              PhosphorIconsRegular.wallet,
              AppTheme.savingsColor(context),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CuentasScreen(database: widget.database)),
              ),
            ),
            _buildActionCard(
              'Reportes',
              PhosphorIconsRegular.chartBar,
              AppTheme.creditColor(context),
              () => AppTabController.goToReportes(),
            ),
            _buildActionCard(
              'Proyección',
              PhosphorIconsRegular.trendUp,
              AppColors.alertOk,
              () => AppTabController.goToProyeccion(),
            ),
            _buildActionCard(
              'Personas',
              PhosphorIconsRegular.users,
              AppColors.alertCaution,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PersonasScreen(database: widget.database)),
              ),
            ),
            _buildActionCard(
              'Categorías',
              PhosphorIconsRegular.squaresFour,
              AppTheme.incomeColor(context),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CategoriasScreen(database: widget.database)),
              ),
            ),
            _buildActionCard(
              'Gastos Fijos',
              PhosphorIconsRegular.repeat,
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

  void _showAddTransaccionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CrearTransaccionModal(database: widget.database),
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
    DateTime? fechaUltimaCuota =
        cuotasPendientes.isNotEmpty ? cuotasPendientes.first.fechaVencimiento : null;
    DateTime? fechaUltimaDeuda = deudasPendientes.isNotEmpty
        ? deudasPendientes.first.fechaAcordadaPago
        : null;

    final bool esDeuda = (fechaUltimaDeuda != null && fechaUltimaCuota != null)
        ? fechaUltimaDeuda.isAfter(fechaUltimaCuota)
        : fechaUltimaDeuda != null;

    final fechaLiberacion = esDeuda ? fechaUltimaDeuda! : fechaUltimaCuota!;

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
