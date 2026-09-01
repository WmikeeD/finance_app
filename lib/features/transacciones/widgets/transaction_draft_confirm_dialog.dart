import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/models/raw_transaction_draft.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/database/database.dart';
import '../presentation/widgets/crear_transaccion_sheet.dart';

/// Modal de confirmación para borradores de transacciones
/// detectados automáticamente (OCR o Notificaciones bancarias)
class TransactionDraftConfirmDialog extends StatelessWidget {
  final RawTransactionDraft draft;
  final AppDatabase database;

  const TransactionDraftConfirmDialog({
    super.key,
    required this.draft,
    required this.database,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Colores según tipo de transacción
    final isIngreso = draft.tipo == 'ingreso';
    final accentColor = isIngreso
        ? AppTheme.incomeColor(context)
        : AppTheme.expenseColor(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Badge de origen
            _buildSourceBadge(scheme, textTheme),
            const SizedBox(height: AppSpacing.lg),

            // Monto destacado
            Text(
              draft.monto != null
                  ? Formatters.monedaConSimbolo(draft.monto!)
                  : 'Monto no detectado',
              style: textTheme.displaySmall?.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),

            // Tipo de transacción
            Text(
              isIngreso ? 'Ingreso' : 'Egreso',
              style: textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Descripción
            if (draft.descripcion != null) ...[
              _buildInfoRow(
                scheme,
                textTheme,
                PhosphorIconsRegular.textT,
                'Descripción',
                draft.descripcion!,
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Fecha
            if (draft.fecha != null) ...[
              _buildInfoRow(
                scheme,
                textTheme,
                PhosphorIconsRegular.calendar,
                'Fecha',
                Formatters.fecha(draft.fecha!),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Cuenta
            if (draft.cuenta != null) ...[
              _buildInfoRow(
                scheme,
                textTheme,
                PhosphorIconsRegular.creditCard,
                'Cuenta',
                '**** ${draft.cuenta}',
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Alerta de duplicado
            if (draft.isDuplicate) ...[
              const SizedBox(height: AppSpacing.md),
              _buildDuplicateAlert(scheme, textTheme),
            ],

            // Nivel de confianza
            const SizedBox(height: AppSpacing.lg),
            _buildConfidenceIndicator(scheme, textTheme),

            const SizedBox(height: AppSpacing.xl),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Descartar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context, true);
                      _abrirFormularioEdicion(context);
                    },
                    icon: PhosphorIcon(PhosphorIconsRegular.pencilSimple, size: 18),
                    label: const Text('Editar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceBadge(ColorScheme scheme, TextTheme textTheme) {
    final icon = draft.source == TransactionSource.ocr
        ? PhosphorIconsRegular.scan
        : PhosphorIconsRegular.bellRinging;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PhosphorIcon(
            icon,
            size: 16,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            draft.source.label,
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    ColorScheme scheme,
    TextTheme textTheme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        PhosphorIcon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDuplicateAlert(ColorScheme scheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: scheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          PhosphorIcon(
            PhosphorIconsRegular.warning,
            color: scheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Posible duplicado detectado',
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceIndicator(ColorScheme scheme, TextTheme textTheme) {
    final percentage = (draft.confidence * 100).toInt();
    final confidenceColor = draft.confidence >= 0.7
        ? AppColors.alertOk
        : draft.confidence >= 0.4
            ? AppColors.alertWarning
            : AppColors.alertDanger;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PhosphorIcon(
          PhosphorIconsRegular.chartBar,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'Confianza: $percentage%',
          style: textTheme.labelSmall?.copyWith(
            color: confidenceColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _abrirFormularioEdicion(BuildContext context) {
    // TODO: Implementar apertura del formulario con datos pre-llenados
    // Por ahora solo abre el formulario estándar
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CrearTransaccionSheet(database: database),
    );
  }
}
