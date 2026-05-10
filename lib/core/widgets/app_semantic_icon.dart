import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppIconSize { sm, md, lg }

class AppSemanticIcon extends StatelessWidget {
  const AppSemanticIcon({
    super.key,
    required this.icon,
    required this.color,
    this.iconSize = 20,
    this.size = AppIconSize.md,
  });

  final IconData icon;
  final Color color;
  final double iconSize;
  final AppIconSize size;

  double get _padding => switch (size) {
        AppIconSize.sm => AppSpacing.sm,
        AppIconSize.md => AppSpacing.md,
        AppIconSize.lg => AppSpacing.base,
      };

  double get _radius => switch (size) {
        AppIconSize.sm => AppRadius.md,
        AppIconSize.md => AppRadius.lg,
        AppIconSize.lg => AppRadius.xl,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}
