import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_tab_controller.dart';
import '../../../core/utils/formatters.dart';

class ProyeccionCuotasMiniCard extends StatelessWidget {
  final List<({DateTime mes, double total})> proyeccion;

  const ProyeccionCuotasMiniCard({
    super.key,
    required this.proyeccion,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (proyeccion.isEmpty || proyeccion.length < 3) {
      return const SizedBox.shrink();
    }

    // Encontrar el mes con mayor monto
    final maxMonto = proyeccion.map((p) => p.total).reduce(math.max);
    final indexMaxMonto =
        proyeccion.indexWhere((p) => p.total == maxMonto);

    // Nombres de meses cortos
    final mesesCortos = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic'
    ];

    return GestureDetector(
      onTap: () => AppTabController.goToProyeccion(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: AppRadius.xlBR,
          border: Border.all(
            color: scheme.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con título y mes destacado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Proyección cuotas',
                  style: textTheme.titleMedium,
                ),
                Text(
                  '${mesesCortos[proyeccion[indexMaxMonto].mes.month - 1]}: ${Formatters.monedaConSimbolo(maxMonto)}',
                  style: textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Mini gráfico de barras
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(proyeccion.length, (index) {
                final mes = proyeccion[index];
                final esMaximo = index == indexMaxMonto;
                final alturaRelativa = maxMonto > 0 ? mes.total / maxMonto : 0.0;
                final alturaBarra = (alturaRelativa * 80).clamp(8.0, 80.0);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Barra
                        Container(
                          height: alturaBarra,
                          decoration: BoxDecoration(
                            color: esMaximo
                                ? scheme.primary
                                : scheme.primary.withValues(alpha: 0.3),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppRadius.sm),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        // Label del mes
                        Text(
                          mesesCortos[mes.mes.month - 1],
                          style: textTheme.labelSmall?.copyWith(
                            color: esMaximo
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            fontWeight:
                                esMaximo ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
