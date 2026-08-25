/// DTO para transacciones pre-confirmadas desde OCR o notificaciones bancarias
/// El usuario debe confirmar siempre antes de guardar en la base de datos
class RawTransactionDraft {
  final String tipo; // 'ingreso' o 'egreso'
  final double? monto;
  final String? descripcion;
  final DateTime? fecha;
  final String? categoria;
  final String? cuenta;
  final bool isDuplicate; // true si el deduplicator detectó posible duplicado
  final TransactionSource source; // OCR o Notificación
  final String? rawText; // Texto original (para debugging)
  final double confidence; // 0.0 - 1.0 (confianza del parser)

  const RawTransactionDraft({
    required this.tipo,
    this.monto,
    this.descripcion,
    this.fecha,
    this.categoria,
    this.cuenta,
    this.isDuplicate = false,
    required this.source,
    this.rawText,
    this.confidence = 0.0,
  });

  /// Constructor para OCR
  factory RawTransactionDraft.fromOcr({
    required String tipo,
    double? monto,
    String? descripcion,
    DateTime? fecha,
    bool isDuplicate = false,
    String? rawText,
    double confidence = 0.0,
  }) {
    return RawTransactionDraft(
      tipo: tipo,
      monto: monto,
      descripcion: descripcion,
      fecha: fecha,
      isDuplicate: isDuplicate,
      source: TransactionSource.ocr,
      rawText: rawText,
      confidence: confidence,
    );
  }

  /// Constructor para Notificaciones Bancarias
  factory RawTransactionDraft.fromNotification({
    required String tipo,
    required double monto,
    required String descripcion,
    required DateTime fecha,
    String? cuenta,
    bool isDuplicate = false,
    String? rawText,
    double confidence = 0.0,
  }) {
    return RawTransactionDraft(
      tipo: tipo,
      monto: monto,
      descripcion: descripcion,
      fecha: fecha,
      cuenta: cuenta,
      isDuplicate: isDuplicate,
      source: TransactionSource.notification,
      rawText: rawText,
      confidence: confidence,
    );
  }

  /// Indica si el draft tiene datos suficientes para ser procesado
  bool get isValid => monto != null && monto! > 0;

  /// Indica si el draft es parcial (reconocimiento incompleto)
  bool get isPartial => monto == null || descripcion == null || fecha == null;

  RawTransactionDraft copyWith({
    String? tipo,
    double? monto,
    String? descripcion,
    DateTime? fecha,
    String? categoria,
    String? cuenta,
    bool? isDuplicate,
    TransactionSource? source,
    String? rawText,
    double? confidence,
  }) {
    return RawTransactionDraft(
      tipo: tipo ?? this.tipo,
      monto: monto ?? this.monto,
      descripcion: descripcion ?? this.descripcion,
      fecha: fecha ?? this.fecha,
      categoria: categoria ?? this.categoria,
      cuenta: cuenta ?? this.cuenta,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      source: source ?? this.source,
      rawText: rawText ?? this.rawText,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  String toString() {
    return 'RawTransactionDraft(tipo: $tipo, monto: $monto, desc: $descripcion, '
        'fecha: $fecha, duplicate: $isDuplicate, source: $source, confidence: $confidence)';
  }
}

/// Origen de la transacción automatizada
enum TransactionSource {
  ocr, // Escaneada desde imagen/boleta
  notification, // Capturada desde notificación bancaria
}

/// Extension para obtener label legible
extension TransactionSourceExtension on TransactionSource {
  String get label {
    switch (this) {
      case TransactionSource.ocr:
        return 'Escaneada (OCR)';
      case TransactionSource.notification:
        return 'Notificación Bancaria';
    }
  }

  String get icon {
    switch (this) {
      case TransactionSource.ocr:
        return '📷'; // Camera/Scan
      case TransactionSource.notification:
        return '🔔'; // Bell/Notification
    }
  }
}
