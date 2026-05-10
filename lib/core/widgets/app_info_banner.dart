import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppBannerType { info, warning, danger, success }

class AppInfoBanner extends StatelessWidget {
  const AppInfoBanner({
    super.key,
    required this.type,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final AppBannerType type;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  Color get _color => switch (type) {
        AppBannerType.info    => AppTheme.savingsColor,
        AppBannerType.warning => AppTheme.alertWarning,
        AppBannerType.danger  => AppTheme.alertDanger,
        AppBannerType.success => AppTheme.alertCelebrate,
      };

  IconData get _icon => switch (type) {
        AppBannerType.info    => Icons.info_outline,
        AppBannerType.warning => Icons.warning_amber_rounded,
        AppBannerType.danger  => Icons.error_outline,
        AppBannerType.success => Icons.celebration_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: AppRadius.lgBR,
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Icon(_icon, color: color, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(color: color),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (onTap != null)
              Icon(Icons.chevron_right, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}
