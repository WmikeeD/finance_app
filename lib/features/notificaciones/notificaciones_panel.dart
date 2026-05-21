import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';

class NotificacionesPanel extends StatelessWidget {
  final AppDatabase database;

  const NotificacionesPanel({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          _buildHeader(context, theme),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildCuotasSection(context, theme),
                _buildGastosFijosSection(context, theme),
                _buildDeudasSection(context, theme),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.notifications, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Text(
                'Notificaciones',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCuotasSection(BuildContext context, ThemeData theme) {
    final ahora = DateTime.now();
    final en30Dias = ahora.add(const Duration(days: 30));

    return StreamBuilder<List<Cuota>>(
      stream: (database.select(database.cuotas)
            ..where(
              (c) =>
                  c.pagada.equals(false) &
                  c.fechaVencimiento.isBiggerOrEqualValue(ahora) &
                  c.fechaVencimiento.isSmallerOrEqualValue(en30Dias),
            )
            ..orderBy([(c) => OrderingTerm.asc(c.fechaVencimiento)]))
          .watch(),
      builder: (context, snapshot) {
        final cuotas = snapshot.data ?? [];
        if (cuotas.isEmpty) return const SizedBox.shrink();

        return _buildSection(
          context,
          theme,
          title: 'Cuotas próximas (30 días)',
          icon: Icons.credit_card,
          color: AppColors.alertWarning,
          items: cuotas.map((c) => _buildCuotaTile(context, theme, c)).toList(),
        );
      },
    );
  }

  Widget _buildCuotaTile(BuildContext context, ThemeData theme, Cuota cuota) {
    final diasRestantes = cuota.fechaVencimiento.difference(DateTime.now()).inDays;
    final chipColor = diasRestantes <= 3
        ? AppColors.alertDanger
        : diasRestantes <= 7
            ? AppColors.alertWarning
            : AppColors.alertCaution;

    return ListTile(
      leading: AppSemanticIcon(icon: Icons.payment, color: AppColors.alertWarning, size: AppIconSize.sm),
      title: Text(
        'Cuota #${cuota.numeroCuota}',
        style: theme.textTheme.labelLarge,
      ),
      subtitle: Text(
        Formatters.fecha(cuota.fechaVencimiento),
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Formatters.monedaConSimbolo(cuota.monto),
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              diasRestantes == 0 ? 'Hoy' : 'en $diasRestantes d.',
              style: theme.textTheme.labelSmall?.copyWith(color: chipColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGastosFijosSection(BuildContext context, ThemeData theme) {
    final hoy = DateTime.now().day;

    return StreamBuilder<List<GastoFijo>>(
      stream: database.watchGastosFijos(soloActivos: true),
      builder: (context, snapshot) {
        final todos = snapshot.data ?? [];
        final proximos = todos.where((g) {
          if (g.diaVencimiento == null) return false;
          final dia = g.diaVencimiento!;
          final diff = dia - hoy;
          return diff >= 0 && diff <= 7;
        }).toList();

        if (proximos.isEmpty) return const SizedBox.shrink();

        return _buildSection(
          context,
          theme,
          title: 'Gastos fijos próximos (7 días)',
          icon: Icons.repeat,
          color: AppTheme.expenseColor(context),
          items: proximos.map((g) => _buildGastoFijoTile(context, theme, g, hoy)).toList(),
        );
      },
    );
  }

  Widget _buildGastoFijoTile(BuildContext context, ThemeData theme, GastoFijo gasto, int hoy) {
    final diasRestantes = (gasto.diaVencimiento ?? 0) - hoy;

    return ListTile(
      leading: AppSemanticIcon(icon: Icons.repeat, color: AppTheme.expenseColor(context), size: AppIconSize.sm),
      title: Text(gasto.nombre, style: theme.textTheme.labelLarge),
      subtitle: Text(
        'Día ${gasto.diaVencimiento} de cada mes',
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Formatters.monedaConSimbolo(gasto.monto),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.expenseColor(context),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.expenseColor(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              diasRestantes == 0 ? 'Hoy' : 'en $diasRestantes d.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.expenseColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeudasSection(BuildContext context, ThemeData theme) {
    return StreamBuilder<List<Deuda>>(
      stream: (database.select(database.deudas)
            ..where((d) => d.estado.isNotIn(['pagada']))
            ..orderBy([(d) => OrderingTerm.desc(d.montoPendiente)]))
          .watch(),
      builder: (context, snapshot) {
        final deudas = snapshot.data ?? [];
        if (deudas.isEmpty) return const SizedBox.shrink();

        return _buildSection(
          context,
          theme,
          title: 'Deudas pendientes',
          icon: Icons.people,
          color: AppColors.alertDanger,
          items: deudas.map((d) => _buildDeudaTile(context, theme, d)).toList(),
        );
      },
    );
  }

  Widget _buildDeudaTile(BuildContext context, ThemeData theme, Deuda deuda) {
    final color = deuda.estado == 'vencida' ? AppColors.alertDanger : AppColors.alertWarning;

    return FutureBuilder<Persona?>(
      future: (database.select(database.personas)
            ..where((p) => p.id.equals(deuda.personaId)))
          .getSingleOrNull(),
      builder: (context, snap) {
        final nombre = snap.data?.nombre ?? 'Persona #${deuda.personaId}';
        return ListTile(
          leading: AppSemanticIcon(icon: Icons.person_outline, color: color, size: AppIconSize.sm),
          title: Text(nombre, style: theme.textTheme.labelLarge),
          subtitle: Text(
            deuda.estado[0].toUpperCase() + deuda.estado.substring(1),
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
          trailing: Text(
            Formatters.monedaConSimbolo(deuda.montoPendiente),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection(
    BuildContext context,
    ThemeData theme, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: items),
        ),
      ],
    );
  }
}
