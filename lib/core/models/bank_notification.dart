/// Modelo de notificación bancaria parseada
class BankNotification {
  final String packageName; // ej: cl.bancochile.mobilebanking
  final String title;
  final String body;
  final DateTime timestamp;
  final String? notificationId; // Para deduplicación

  const BankNotification({
    required this.packageName,
    required this.title,
    required this.body,
    required this.timestamp,
    this.notificationId,
  });

  /// Constructor desde datos de sistema
  factory BankNotification.fromSystem({
    required String packageName,
    required String title,
    required String body,
    DateTime? timestamp,
    String? id,
  }) {
    return BankNotification(
      packageName: packageName,
      title: title,
      body: body,
      timestamp: timestamp ?? DateTime.now(),
      notificationId: id,
    );
  }

  /// Genera un hash único para deduplicación
  String get uniqueHash {
    return '$packageName-${timestamp.millisecondsSinceEpoch}-${body.hashCode}';
  }

  @override
  String toString() {
    return 'BankNotification(pkg: $packageName, title: $title, '
        'time: $timestamp, id: $notificationId)';
  }
}

/// Resultado del parseo de notificación bancaria
class BankNotificationParseResult {
  final bool success;
  final String? tipo; // 'ingreso' o 'egreso'
  final double? monto;
  final String? descripcion;
  final String? cuenta; // Últimos 4 dígitos de tarjeta/cuenta
  final BankType? bankType;
  final String? errorMessage;

  const BankNotificationParseResult({
    required this.success,
    this.tipo,
    this.monto,
    this.descripcion,
    this.cuenta,
    this.bankType,
    this.errorMessage,
  });

  factory BankNotificationParseResult.success({
    required String tipo,
    required double monto,
    required String descripcion,
    String? cuenta,
    BankType? bankType,
  }) {
    return BankNotificationParseResult(
      success: true,
      tipo: tipo,
      monto: monto,
      descripcion: descripcion,
      cuenta: cuenta,
      bankType: bankType,
    );
  }

  factory BankNotificationParseResult.failed(String reason) {
    return BankNotificationParseResult(
      success: false,
      errorMessage: reason,
    );
  }

  bool get isValid => success && monto != null && monto! > 0;

  @override
  String toString() {
    return 'ParseResult(success: $success, tipo: $tipo, monto: $monto, '
        'desc: $descripcion, cuenta: $cuenta)';
  }
}

/// Tipos de bancos/instituciones financieras
enum BankType {
  bancoEstado,
  santander,
  bci,
  bancoDeChile,
  scotiabank,
  itau,
  mach,
  tenpo,
  mercadoPago,
  falabella,
  ripley,
  other,
}

extension BankTypeExtension on BankType {
  String get displayName {
    switch (this) {
      case BankType.bancoEstado:
        return 'BancoEstado';
      case BankType.santander:
        return 'Santander';
      case BankType.bci:
        return 'BCI';
      case BankType.bancoDeChile:
        return 'Banco de Chile';
      case BankType.scotiabank:
        return 'Scotiabank';
      case BankType.itau:
        return 'Itaú';
      case BankType.mach:
        return 'MACH';
      case BankType.tenpo:
        return 'Tenpo';
      case BankType.mercadoPago:
        return 'Mercado Pago';
      case BankType.falabella:
        return 'Falabella';
      case BankType.ripley:
        return 'Ripley';
      case BankType.other:
        return 'Otro';
    }
  }
}
