import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
  final String Function(double)? formatter;

  String _fmt(double amount) {
    if (formatter != null) return formatter!(amount);
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
        AppSpacing.base,
        AppSpacing.base,
        AppSpacing.base,
        0,
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
          Text(
            balanceLabel.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
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
          Divider(color: scheme.outlineVariant, thickness: 0.5, height: 0),
          const SizedBox(height: AppSpacing.base),
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
