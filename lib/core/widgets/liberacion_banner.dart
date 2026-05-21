import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
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
