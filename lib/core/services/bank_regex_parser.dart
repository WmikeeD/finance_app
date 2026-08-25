import '../models/bank_notification.dart';
import '../config/bank_config.dart';

/// Parser de notificaciones bancarias usando expresiones regulares
/// Soporta bancos tradicionales y fintechs chilenas
class BankRegexParser {
  /// Parsea el contenido de una notificación bancaria
  static BankNotificationParseResult parse(BankNotification notification) {
    final text = '${notification.title} ${notification.body}'.toLowerCase();
    final bankType = BankConfig.getBankType(notification.packageName);

    // 1. Detectar tipo de transacción (ingreso/egreso)
    final tipo = _detectTransactionType(text);
    if (tipo == null) {
      return BankNotificationParseResult.failed(
        'No se detectó tipo de transacción (compra/abono)',
      );
    }

    // 2. Extraer monto
    final monto = _extractAmount(text);
    if (monto == null) {
      return BankNotificationParseResult.failed('No se detectó monto en la notificación');
    }

    // 3. Extraer descripción
    final descripcion = _extractDescription(notification.title, notification.body, tipo);

    // 4. Extraer últimos 4 dígitos de cuenta/tarjeta
    final cuenta = _extractAccountDigits(text);

    return BankNotificationParseResult.success(
      tipo: tipo,
      monto: monto,
      descripcion: descripcion,
      cuenta: cuenta,
      bankType: bankType,
    );
  }

  /// Detecta el tipo de transacción basado en palabras clave
  static String? _detectTransactionType(String text) {
    // Verificar palabras clave de egreso
    for (final keyword in BankConfig.egresoKeywords) {
      if (text.contains(keyword)) {
        return 'egreso';
      }
    }

    // Verificar palabras clave de ingreso
    for (final keyword in BankConfig.ingresoKeywords) {
      if (text.contains(keyword)) {
        return 'ingreso';
      }
    }

    return null;
  }

  /// Extrae el monto de la notificación
  /// Soporta formatos: $1.000, $1000, 1.000, 1000, $1.000.000
  static double? _extractAmount(String text) {
    // Patrones de monto más comunes en notificaciones bancarias
    final patterns = [
      // $1.000 o $1.000.000
      RegExp(r'\$\s*(\d{1,3}(?:\.\d{3})+)'),
      // $1000 (sin puntos)
      RegExp(r'\$\s*(\d+)'),
      // 1.000 o 1.000.000 (sin símbolo $)
      RegExp(r'(?:^|\s)(\d{1,3}(?:\.\d{3})+)(?:\s|$)'),
      // Número sin formato: 1000
      RegExp(r'(?:^|\s)(\d{4,})(?:\s|$)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amountStr = match.group(1)!.replaceAll('.', ''); // Remover puntos
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) {
          return amount;
        }
      }
    }

    return null;
  }

  /// Extrae descripción de la transacción
  static String _extractDescription(String title, String body, String tipo) {
    // Priorizar el cuerpo de la notificación para descripción
    final fullText = body.isNotEmpty ? body : title;

    // Limpiar texto común de notificaciones bancarias
    var cleaned = fullText
        .replaceAll(RegExp(r'\$\s*\d+(?:\.\d{3})*'), '') // Remover montos
        .replaceAll(RegExp(r'\d{4}'), '') // Remover últimos 4 dígitos
        .replaceAll(RegExp(r'[*]{4}'), '') // Remover asteriscos
        .trim();

    // Si está vacío después de limpiar, usar el título
    if (cleaned.isEmpty) {
      cleaned = title;
    }

    // Limitar longitud
    if (cleaned.length > 100) {
      cleaned = '${cleaned.substring(0, 97)}...';
    }

    return cleaned.isNotEmpty ? cleaned : 'Transacción ${tipo == 'ingreso' ? 'recibida' : 'realizada'}';
  }

  /// Extrae los últimos 4 dígitos de cuenta/tarjeta
  /// Formatos: **** 1234, **1234, T-1234, Cta 1234
  static String? _extractAccountDigits(String text) {
    final patterns = [
      RegExp(r'\*{4}\s*(\d{4})'), // **** 1234
      RegExp(r'\*{2,}(\d{4})'), // **1234
      RegExp(r'[tT]-(\d{4})'), // T-1234
      RegExp(r'[cC]ta\.?\s*(\d{4})'), // Cta 1234 o Cta. 1234
      RegExp(r'tarjeta\s+(\d{4})'), // tarjeta 1234
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Valida que el contenido de la notificación sea relevante
  static bool isRelevantNotification(String title, String body) {
    final text = '$title $body'.toLowerCase();

    // Debe contener al menos un keyword financiero
    final hasFinancialKeyword = BankConfig.egresoKeywords.any((k) => text.contains(k)) ||
        BankConfig.ingresoKeywords.any((k) => text.contains(k));

    // Debe contener un monto
    final hasAmount = _extractAmount(text) != null;

    return hasFinancialKeyword || hasAmount;
  }

  /// Obtiene nivel de confianza del parseo (0.0 - 1.0)
  static double getConfidence(BankNotificationParseResult result) {
    if (!result.success) return 0.0;

    double confidence = 0.0;

    // Tiene monto válido: +40%
    if (result.monto != null && result.monto! > 0) {
      confidence += 0.4;
    }

    // Tiene tipo detectado: +30%
    if (result.tipo != null) {
      confidence += 0.3;
    }

    // Tiene descripción: +15%
    if (result.descripcion != null && result.descripcion!.length > 5) {
      confidence += 0.15;
    }

    // Tiene cuenta/tarjeta: +15%
    if (result.cuenta != null) {
      confidence += 0.15;
    }

    return confidence.clamp(0.0, 1.0);
  }
}
