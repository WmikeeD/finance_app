import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_tab_controller.dart';
import '../../proyeccion/models/proyeccion_models.dart';

class LiberacionDeudaBanner extends StatelessWidget {
  final MesLiberacion liberacion;

  const LiberacionDeudaBanner({
    super.key,
    required this.liberacion,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Formato de fecha: "Marzo 2027"
    final meses = [
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
      'Diciembre'
    ];
    final nombreMes = meses[liberacion.fecha.month - 1];
    final anio = liberacion.fecha.year;

    return GestureDetector(
      onTap: () => AppTabController.goToProyeccion(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.2),
              scheme.primary.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: AppRadius.xlBR,
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Ícono de celebración
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.alertCelebrate.withValues(alpha: 0.2),
                borderRadius: AppRadius.mdBR,
              ),
              child: PhosphorIcon(
                PhosphorIconsRegular.confetti,
                color: AppColors.alertCelebrate,
                size: 32,
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Texto principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LIBERACIÓN DE DEUDA',
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$nombreMes $anio · ${liberacion.mesesFaltantes} ${liberacion.mesesFaltantes == 1 ? 'mes' : 'meses'}',
                    style: textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Ícono de navegación
            PhosphorIcon(
              PhosphorIconsRegular.caretRight,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
