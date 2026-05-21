import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum TransactionType { income, expense, credit }

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
