import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.error,
    this.onRetry,
  });

  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.alertDanger),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Ocurrió un error',
              style: theme.textTheme.titleMedium,
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                error.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
