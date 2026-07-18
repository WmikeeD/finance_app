import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/proyeccion_models.dart';

class LiberacionBannerDelegate extends SliverPersistentHeaderDelegate {
  final MesLiberacion mesLiberacion;
  final bool isMobile;

  LiberacionBannerDelegate({
    required this.mesLiberacion,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Color amarillo/dorado accesible para el banner
    final bannerColor = AppColors.alertCelebrate;
    final onBannerColor = scheme.onPrimaryContainer;

    return SizedBox(
      height: maxExtent,
      child: Container(
        color: bannerColor,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: 12,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: PhosphorIcon(
                PhosphorIconsRegular.confetti,
                color: scheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🎉 LIBERACIÓN: ${mesLiberacion.fecha.month}/${mesLiberacion.fecha.year}',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: onBannerColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Última: ${mesLiberacion.descripcionUltima} - ${Formatters.monedaConSimbolo(mesLiberacion.montoUltima)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: onBannerColor.withValues(alpha: 0.9),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                'Faltan ${mesLiberacion.mesesFaltantes}',
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  double get maxExtent => isMobile ? 70 : 80;

  @override
  double get minExtent => isMobile ? 70 : 80;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}
