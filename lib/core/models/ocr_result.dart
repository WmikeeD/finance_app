import 'raw_transaction_draft.dart';

/// Resultado tipado del proceso de OCR
/// Permite manejar diferentes estados de reconocimiento
class OcrResult {
  final OcrStatus status;
  final RawTransactionDraft? draft;
  final String? errorMessage;
  final List<String> detectedBlocks; // Bloques de texto detectados
  final int totalBlocks; // Total de bloques encontrados

  const OcrResult._({
    required this.status,
    this.draft,
    this.errorMessage,
    this.detectedBlocks = const [],
    this.totalBlocks = 0,
  });

  /// OCR exitoso con datos completos o parciales
  factory OcrResult.success({
    required RawTransactionDraft draft,
    required List<String> detectedBlocks,
  }) {
    return OcrResult._(
      status: OcrStatus.success,
      draft: draft,
      detectedBlocks: detectedBlocks,
      totalBlocks: detectedBlocks.length,
    );
  }

  /// Imagen/texto no reconocido como boleta/factura
  /// - Muy pocos bloques de texto (< 2)
  /// - Sin patrones de montos
  /// - Sin palabras clave financieras
  factory OcrResult.unrecognized({
    required String reason,
    List<String> detectedBlocks = const [],
  }) {
    return OcrResult._(
      status: OcrStatus.unrecognized,
      errorMessage: reason,
      detectedBlocks: detectedBlocks,
      totalBlocks: detectedBlocks.length,
    );
  }

  /// Reconocimiento parcial (algunos campos detectados)
  factory OcrResult.partial({
    required RawTransactionDraft draft,
    required String reason,
    required List<String> detectedBlocks,
  }) {
    return OcrResult._(
      status: OcrStatus.partial,
      draft: draft,
      errorMessage: reason,
      detectedBlocks: detectedBlocks,
      totalBlocks: detectedBlocks.length,
    );
  }

  /// Error durante el procesamiento
  factory OcrResult.error({required String message}) {
    return OcrResult._(
      status: OcrStatus.error,
      errorMessage: message,
    );
  }

  bool get isSuccess => status == OcrStatus.success;
  bool get isPartial => status == OcrStatus.partial;
  bool get isUnrecognized => status == OcrStatus.unrecognized;
  bool get isError => status == OcrStatus.error;

  /// Indica si hay un draft disponible (success o partial)
  bool get hasDraft => draft != null;

  @override
  String toString() {
    return 'OcrResult(status: $status, blocks: $totalBlocks, '
        'hasDraft: $hasDraft, error: $errorMessage)';
  }
}

/// Estados posibles del OCR
enum OcrStatus {
  success, // Reconocimiento exitoso
  partial, // Reconocimiento parcial (algunos campos)
  unrecognized, // No reconocido como documento financiero
  error, // Error durante procesamiento
}

extension OcrStatusExtension on OcrStatus {
  String get label {
    switch (this) {
      case OcrStatus.success:
        return 'Reconocido';
      case OcrStatus.partial:
        return 'Parcial';
      case OcrStatus.unrecognized:
        return 'No reconocido';
      case OcrStatus.error:
        return 'Error';
    }
  }

  /// Mensaje para usuario según el estado
  String getUserMessage(OcrResult result) {
    switch (this) {
      case OcrStatus.success:
        return 'Boleta reconocida exitosamente. Revisa los datos antes de guardar.';
      case OcrStatus.partial:
        return 'Reconocimiento parcial. ${result.errorMessage ?? "Completa los campos faltantes."}';
      case OcrStatus.unrecognized:
        return 'No se pudo reconocer como boleta o factura. ${result.errorMessage ?? "Intenta con otra imagen."}';
      case OcrStatus.error:
        return 'Error al procesar imagen: ${result.errorMessage ?? "Intenta nuevamente."}';
    }
  }
}
