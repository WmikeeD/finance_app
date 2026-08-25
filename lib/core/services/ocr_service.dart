import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/ocr_result.dart';
import '../models/raw_transaction_draft.dart';

/// Servicio de OCR para escanear boletas y facturas
/// Utiliza Google ML Kit Text Recognition (o similar)
///
/// IMPORTANTE: Este es un template/stub. La implementación real requiere:
/// - Agregar google_mlkit_text_recognition al pubspec.yaml
/// - Configurar permisos de cámara en Android/iOS
/// - Implementar la lógica de reconocimiento de texto
class OcrService {
  /// Umbral mínimo de bloques de texto para considerar válida una imagen
  static const int minTextBlocks = 2;

  /// Palabras clave financieras que indican un documento válido
  static const Set<String> financialKeywords = {
    'total',
    'monto',
    'boleta',
    'factura',
    'ticket',
    'comprobante',
    'pago',
    'precio',
    'subtotal',
    'fecha',
    'rut',
    'valor',
  };

  /// Procesa una imagen y extrae información de transacción
  ///
  /// [imagePath]: Ruta a la imagen de la boleta/factura
  ///
  /// Retorna [OcrResult] con el estado del reconocimiento
  Future<OcrResult> processImage(String imagePath) async {
    try {
      // 1. Validar que el archivo existe
      final file = File(imagePath);
      if (!await file.exists()) {
        return OcrResult.error(message: 'El archivo de imagen no existe');
      }

      // 2. Validar tamaño de archivo (máx 10MB)
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        return OcrResult.error(message: 'La imagen es demasiado grande (máx 10MB)');
      }

      // 3. Realizar OCR
      // TODO: Implementar con google_mlkit_text_recognition
      final detectedBlocks = await _performOcr(file);

      // 4. Validar bloques detectados
      if (detectedBlocks.isEmpty) {
        return OcrResult.unrecognized(
          reason: 'No se detectó texto en la imagen',
          detectedBlocks: detectedBlocks,
        );
      }

      if (detectedBlocks.length < minTextBlocks) {
        return OcrResult.unrecognized(
          reason: 'Texto insuficiente (mínimo $minTextBlocks bloques)',
          detectedBlocks: detectedBlocks,
        );
      }

      // 5. Verificar palabras clave financieras
      if (!_hasFinancialKeywords(detectedBlocks)) {
        return OcrResult.unrecognized(
          reason: 'No se detectaron palabras clave financieras',
          detectedBlocks: detectedBlocks,
        );
      }

      // 6. Extraer información
      final monto = _extractAmount(detectedBlocks);
      final fecha = _extractDate(detectedBlocks);
      final descripcion = _extractDescription(detectedBlocks);

      // 7. Validar resultados
      if (monto == null && fecha == null && descripcion == null) {
        return OcrResult.unrecognized(
          reason: 'No se pudo extraer información relevante',
          detectedBlocks: detectedBlocks,
        );
      }

      // 8. Crear draft
      final draft = RawTransactionDraft.fromOcr(
        tipo: 'egreso', // Por defecto egresos (boletas de compra)
        monto: monto,
        fecha: fecha,
        descripcion: descripcion,
        rawText: detectedBlocks.join(' '),
        confidence: _calculateConfidence(monto, fecha, descripcion),
      );

      // 9. Determinar estado del resultado
      if (monto != null && fecha != null) {
        return OcrResult.success(
          draft: draft,
          detectedBlocks: detectedBlocks,
        );
      } else {
        return OcrResult.partial(
          draft: draft,
          reason: _getPartialReason(monto, fecha, descripcion),
          detectedBlocks: detectedBlocks,
        );
      }
    } catch (e) {
      return OcrResult.error(message: 'Error al procesar imagen: $e');
    }
  }

  /// Realiza el OCR sobre la imagen usando Google ML Kit
  Future<List<String>> _performOcr(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);

      // Extraer bloques de texto no vacíos
      final blocks = recognizedText.blocks
          .map((block) => block.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      return blocks;
    } finally {
      // Liberar recursos
      await textRecognizer.close();
    }
  }

  /// Verifica si hay palabras clave financieras en el texto
  bool _hasFinancialKeywords(List<String> blocks) {
    final text = blocks.join(' ').toLowerCase();
    return financialKeywords.any((keyword) => text.contains(keyword));
  }

  /// Extrae el monto total de los bloques de texto
  double? _extractAmount(List<String> blocks) {
    final text = blocks.join(' ');

    // Buscar patrones de monto
    final patterns = [
      // Total: $1.000 o Total $1000
      RegExp(r'total[:\s]*\$?\s*(\d{1,3}(?:\.\d{3})*)', caseSensitive: false),
      // Monto: $1.000
      RegExp(r'monto[:\s]*\$?\s*(\d{1,3}(?:\.\d{3})*)', caseSensitive: false),
      // Cualquier $1.000
      RegExp(r'\$\s*(\d{1,3}(?:\.\d{3})+)'),
      // Número grande sin formato (mayor a 1000)
      RegExp(r'(?:^|\s)(\d{4,})(?:\s|$)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amountStr = match.group(1)!.replaceAll('.', '');
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) {
          return amount;
        }
      }
    }

    return null;
  }

  /// Extrae la fecha de los bloques de texto
  DateTime? _extractDate(List<String> blocks) {
    final text = blocks.join(' ');

    // Patrones de fecha comunes en boletas chilenas
    final patterns = [
      // DD/MM/YYYY o DD-MM-YYYY
      RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})'),
      // DD/MM/YY
      RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          final day = int.parse(match.group(1)!);
          final month = int.parse(match.group(2)!);
          var year = int.parse(match.group(3)!);

          // Si el año es de 2 dígitos, convertir a 4
          if (year < 100) {
            year += 2000;
          }

          // Validar fecha
          if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
            return DateTime(year, month, day);
          }
        } catch (_) {
          continue;
        }
      }
    }

    return null;
  }

  /// Extrae descripción del comercio o producto
  String? _extractDescription(List<String> blocks) {
    if (blocks.isEmpty) return null;

    // La primera línea suele ser el nombre del comercio
    final firstBlock = blocks.first.trim();
    if (firstBlock.length > 3 && firstBlock.length < 100) {
      return firstBlock;
    }

    // Buscar en los primeros 3 bloques
    for (var i = 0; i < blocks.length && i < 3; i++) {
      final block = blocks[i].trim();
      if (block.length > 3 && block.length < 100) {
        // Evitar bloques que son solo números o RUT
        if (!RegExp(r'^\d+$').hasMatch(block) && !block.contains('RUT')) {
          return block;
        }
      }
    }

    return null;
  }

  /// Calcula el nivel de confianza del OCR (0.0 - 1.0)
  double _calculateConfidence(double? monto, DateTime? fecha, String? descripcion) {
    double confidence = 0.0;

    if (monto != null) confidence += 0.4; // 40% por monto
    if (fecha != null) confidence += 0.3; // 30% por fecha
    if (descripcion != null && descripcion.length > 3) confidence += 0.3; // 30% por descripción

    return confidence.clamp(0.0, 1.0);
  }

  /// Genera mensaje para reconocimiento parcial
  String _getPartialReason(double? monto, DateTime? fecha, String? descripcion) {
    final missing = <String>[];
    if (monto == null) missing.add('monto');
    if (fecha == null) missing.add('fecha');
    if (descripcion == null) missing.add('descripción');

    return 'Falta detectar: ${missing.join(', ')}';
  }

  /// Destruye recursos temporales (imagen en memoria)
  Future<void> dispose() async {
    // Los recursos de TextRecognizer se liberan en _performOcr() con finally
    // No hay recursos adicionales que liberar en esta versión
  }
}
