// finance_app — widgets_m3.dart
// Widgets modulares rediseñados con Material Design 3
// Coloca estos widgets en: lib/core/widgets/
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../theme/app_theme.dart'; // ajusta el import según tu estructura

// ═════════════════════════════════════════════════════════════════════════════
//  1.  FinanceHeroCard — Balance principal del Dashboard
// ═════════════════════════════════════════════════════════════════════════════
/// Tarjeta principal del dashboard que muestra el balance total del usuario
/// con tres métricas secundarias: ingresos del mes, egresos del mes y crédito.
///
/// Uso:
/// ```dart
/// FinanceHeroCard(
///   balance: 204738,
///   incomeMonth: 69990,
///   expenseMonth: 85250,
///   creditAvailable: 1641858,
/// )
/// ```
class FinanceHeroCard extends StatelessWidget {
  const FinanceHeroCard({
    super.key,
    required this.balance,
    required this.incomeMonth,
    required this.expenseMonth,
    required this.creditAvailable,
    this.balanceLabel = 'Balance total',
    this.balanceSubLabel = 'Dinero real disponible',
    this.formatter,
  });

  final double balance;
  final double incomeMonth;
  final double expenseMonth;
  final double creditAvailable;
  final String balanceLabel;
  final String balanceSubLabel;

  /// Función opcional para formatear montos (usa intl.NumberFormat en tu app).
  /// Si es null, usa formato básico.
  final String Function(double)? formatter;

  String _fmt(double amount) {
    if (formatter != null) return formatter!(amount);
    // Formato básico: $1.234.567
    final str = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    final chars = str.replaceAll('-', '').split('').reversed.toList();
    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write('.');
      buffer.write(chars[i]);
    }
    final formatted = buffer.toString().split('').reversed.join();
    return amount < 0 ? '-\$$formatted' : '\$$formatted';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.base, AppSpacing.base, AppSpacing.base, 0,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label ──
          Text(
            balanceLabel.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),

          // ── Monto principal ──
          Text(
            _fmt(balance),
            style: textTheme.displaySmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w300,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            balanceSubLabel,
            style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.base),

          // ── Divisor ──
          Divider(color: scheme.outlineVariant, thickness: 0.5, height: 0),
          const SizedBox(height: AppSpacing.base),

          // ── Stats row ──
          IntrinsicHeight(
            child: Row(
              children: [
                _StatPill(
                  label: 'Ingresos mes',
                  value: '+${_fmt(incomeMonth)}',
                  valueColor: AppTheme.incomeColor(context),
                  scheme: scheme,
                  textTheme: textTheme,
                ),
                _VerticalDivider(scheme: scheme),
                _StatPill(
                  label: 'Egresos mes',
                  value: '-${_fmt(expenseMonth)}',
                  valueColor: AppTheme.expenseColor(context),
                  scheme: scheme,
                  textTheme: textTheme,
                ),
                _VerticalDivider(scheme: scheme),
                _StatPill(
                  label: 'Crédito disp.',
                  value: _fmt(creditAvailable),
                  valueColor: AppTheme.creditColor(context),
                  scheme: scheme,
                  textTheme: textTheme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.scheme,
    required this.textTheme,
  });

  final String label;
  final String value;
  final Color valueColor;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: textTheme.labelMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      height: double.infinity,
      color: scheme.outlineVariant,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  2.  TransactionListItem — Ítem de transacción con soporte M3
// ═════════════════════════════════════════════════════════════════════════════
enum TransactionType { income, expense, credit }

/// Ítem de lista para transacciones. Soporta ingresos, egresos y cuotas.
/// Toca el ítem para abrir el detalle via `onTap`.
///
/// Uso:
/// ```dart
/// TransactionListItem(
///   type: TransactionType.expense,
///   description: 'Pago zapatillas',
///   category: 'Alimentación',
///   date: DateTime.now(),
///   amount: -5000,
///   installmentInfo: '1 cuota',  // opcional
///   onTap: () => _openDetail(txn),
/// )
/// ```
class TransactionListItem extends StatelessWidget {
  const TransactionListItem({
    super.key,
    required this.type,
    required this.description,
    required this.category,
    required this.date,
    required this.amount,
    this.installmentInfo,
    this.onTap,
    this.formatter,
  });

  final TransactionType type;
  final String description;
  final String category;
  final DateTime date;
  final double amount;
  final String? installmentInfo;
  final VoidCallback? onTap;
  final String Function(double)? formatter;

  String _fmt(double v) {
    if (formatter != null) return formatter!(v);
    final abs = v.abs().toStringAsFixed(0);
    final buffer = StringBuffer();
    final chars = abs.split('').reversed.toList();
    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write('.');
      buffer.write(chars[i]);
    }
    final formatted = buffer.toString().split('').reversed.join();
    return v < 0 ? '-\$$formatted' : '+\$$formatted';
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (iconData, iconBg, iconFg, amountColor) = switch (type) {
      TransactionType.income => (
          Icons.arrow_downward_rounded,
          AppTheme.incomeColor(context).withValues(alpha: 0.12),
          AppTheme.incomeColor(context),
          AppTheme.incomeColor(context),
        ),
      TransactionType.expense => (
          Icons.arrow_upward_rounded,
          AppTheme.expenseColor(context).withValues(alpha: 0.12),
          AppTheme.expenseColor(context),
          AppTheme.expenseColor(context),
        ),
      TransactionType.credit => (
          Icons.credit_card_rounded,
          AppTheme.creditColor(context).withValues(alpha: 0.12),
          AppTheme.creditColor(context),
          AppTheme.creditColor(context),
        ),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Colors.transparent, width: 0.5),
        ),
        child: Row(
          children: [
            // ── Ícono semántico ──
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(iconData, color: iconFg, size: 18),
            ),
            const SizedBox(width: AppSpacing.md),

            // ── Descripción + meta ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      _formatDate(date),
                      category,
                      if (installmentInfo != null) installmentInfo!,
                    ].join(' · '),
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // ── Monto ──
            Text(
              _fmt(amount),
              style: textTheme.titleSmall?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  3.  LiberacionBanner — Banner de mes de liberación de deuda
// ═════════════════════════════════════════════════════════════════════════════
/// Banner que muestra el mes en que el usuario queda libre de cuotas.
/// Se muestra en el Dashboard y se mantiene visible al scroll en Proyección.
///
/// Uso:
/// ```dart
/// LiberacionBanner(
///   releaseMonth: DateTime(2027, 3),
///   monthsRemaining: 10,
///   lastInstallmentDescription: 'Compra ropa Bea Ripley',
///   lastInstallmentAmount: 1484,
///   onTap: () => AppTabController.goToProyeccion(),
/// )
/// ```
class LiberacionBanner extends StatelessWidget {
  const LiberacionBanner({
    super.key,
    required this.releaseMonth,
    required this.monthsRemaining,
    required this.lastInstallmentDescription,
    required this.lastInstallmentAmount,
    this.onTap,
  });

  final DateTime releaseMonth;
  final int monthsRemaining;
  final String lastInstallmentDescription;
  final double lastInstallmentAmount;
  final VoidCallback? onTap;

  static const _months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final monthLabel = '${_months[releaseMonth.month - 1]} ${releaseMonth.year}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.base),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.base,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.8),
              scheme.primaryContainer,
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            // ── Ícono ──
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: const Center(
                child: Text('🎉', style: TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // ── Texto ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LIBERACIÓN DE DEUDA',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    monthLabel,
                    style: textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Última: $lastInstallmentDescription · \$${lastInstallmentAmount.toStringAsFixed(0)}',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // ── Badge de meses ──
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$monthsRemaining',
                    style: textTheme.headlineSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  Text(
                    'meses',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  4.  AppSemanticIcon — Ícono con fondo de color semántico (M3)
// ═════════════════════════════════════════════════════════════════════════════
/// Ícono con contenedor de color semántico, compatible con Surface Tint M3.
/// Reemplaza los fondos de color fijo de la versión anterior.
///
/// Uso:
/// ```dart
/// AppSemanticIcon(
///   icon: Icons.restaurant,
///   semanticColor: SemanticColor.expense,
///   size: 40,
/// )
/// ```
enum SemanticColor { income, expense, credit, savings, warning, neutral }

class AppSemanticIcon extends StatelessWidget {
  const AppSemanticIcon({
    super.key,
    required this.icon,
    this.semanticColor = SemanticColor.neutral,
    this.size = 40,
    this.iconSize,
    this.borderRadius,
    this.customColor,
  });

  final IconData icon;
  final SemanticColor semanticColor;
  final double size;
  final double? iconSize;
  final double? borderRadius;

  /// Override: usa un color personalizado en lugar del semántico.
  final Color? customColor;

  @override
  Widget build(BuildContext context) {
    final Color base = customColor ?? _resolveColor(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(borderRadius ?? AppRadius.md),
      ),
      child: Icon(
        icon,
        color: base,
        size: iconSize ?? (size * 0.45),
      ),
    );
  }

  Color _resolveColor(BuildContext context) {
    return switch (semanticColor) {
      SemanticColor.income => AppTheme.incomeColor(context),
      SemanticColor.expense => AppTheme.expenseColor(context),
      SemanticColor.credit => AppTheme.creditColor(context),
      SemanticColor.savings => AppTheme.savingsColor(context),
      SemanticColor.warning => AppColors.warning,
      SemanticColor.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  5.  AppSectionHeader — Encabezado de sección con acción opcional
// ═════════════════════════════════════════════════════════════════════════════
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: padding ??
          const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.sm,
          ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(color: scheme.onSurface),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: textTheme.labelMedium?.copyWith(color: scheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  6.  AppInfoBanner — Banner informativo semántico
// ═════════════════════════════════════════════════════════════════════════════
enum BannerVariant { info, warning, danger, success }

class AppInfoBanner extends StatelessWidget {
  const AppInfoBanner({
    super.key,
    required this.message,
    this.variant = BannerVariant.info,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final BannerVariant variant;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final (bg, fg, defaultIcon) = switch (variant) {
      BannerVariant.info => (
          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
          Theme.of(context).colorScheme.primary,
          Icons.info_outline_rounded,
        ),
      BannerVariant.warning => (
          AppColors.warning.withValues(alpha: 0.12),
          AppColors.warning,
          Icons.warning_amber_rounded,
        ),
      BannerVariant.danger => (
          AppColors.expense.withValues(alpha: 0.12),
          AppColors.expense,
          Icons.error_outline_rounded,
        ),
      BannerVariant.success => (
          AppColors.income.withValues(alpha: 0.12),
          AppColors.income,
          Icons.check_circle_outline_rounded,
        ),
    };

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, color: fg, size: 18),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: textTheme.bodySmall?.copyWith(color: fg),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  GestureDetector(
                    onTap: onAction,
                    child: Text(
                      actionLabel!,
                      style: textTheme.labelSmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: fg,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
