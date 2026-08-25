import 'package:drift/drift.dart';
import '../database/database.dart';

/// Validador de transacciones duplicadas
/// Compara monto y ventana de tiempo contra la base de datos
class TransactionDeduplicator {
  final AppDatabase database;

  /// Caché en memoria de IDs de notificaciones procesadas
  /// Previene duplicidad por reemisión del sistema
  static final Set<String> _processedNotificationIds = {};

  /// TTL del caché (tiempo de vida en memoria)
  static const Duration _cacheTtl = Duration(hours: 24);

  /// Timestamp del último cleanup del caché
  static DateTime _lastCleanup = DateTime.now();

  TransactionDeduplicator(this.database);

  /// Verifica si una transacción es posiblemente duplicada
  /// Compara monto exacto en ventana de ±10 minutos
  ///
  /// Retorna:
  /// - `true` si se encuentra posible duplicado
  /// - `false` si no hay duplicados
  Future<bool> isDuplicate({
    required double monto,
    required DateTime fecha,
    String? descripcion,
  }) async {
    // Ventana de búsqueda: ±10 minutos
    final inicio = fecha.subtract(const Duration(minutes: 10));
    final fin = fecha.add(const Duration(minutes: 10));

    // Query a base de datos
    final transacciones = await (database.select(database.transacciones)
          ..where((t) =>
              t.montoTotal.equals(monto) &
              t.fecha.isBiggerOrEqualValue(inicio) &
              t.fecha.isSmallerOrEqualValue(fin)))
        .get();

    if (transacciones.isEmpty) {
      return false;
    }

    // Si hay descripción, verificar similitud
    if (descripcion != null && descripcion.isNotEmpty) {
      for (final tx in transacciones) {
        if (_areSimilar(tx.descripcion, descripcion)) {
          return true;
        }
      }
      return false;
    }

    // Sin descripción, solo monto en ventana → posible duplicado
    return true;
  }

  /// Verifica si un ID de notificación ya fue procesado
  /// Usa caché en memoria para prevenir duplicidad por reemisión
  bool isNotificationProcessed(String notificationId) {
    _cleanupCacheIfNeeded();
    return _processedNotificationIds.contains(notificationId);
  }

  /// Marca un ID de notificación como procesado
  void markNotificationAsProcessed(String notificationId) {
    _cleanupCacheIfNeeded();
    _processedNotificationIds.add(notificationId);
  }

  /// Limpia el caché si ha pasado el TTL
  void _cleanupCacheIfNeeded() {
    final now = DateTime.now();
    if (now.difference(_lastCleanup) > _cacheTtl) {
      _processedNotificationIds.clear();
      _lastCleanup = now;
    }
  }

  /// Verifica si dos descripciones son similares
  /// Usa Levenshtein distance simplificada o coincidencia de palabras clave
  bool _areSimilar(String a, String b) {
    final aLower = a.toLowerCase().trim();
    final bLower = b.toLowerCase().trim();

    // Exacta
    if (aLower == bLower) return true;

    // Una contiene a la otra
    if (aLower.contains(bLower) || bLower.contains(aLower)) return true;

    // Palabras clave en común (al menos 2)
    final aWords = aLower.split(RegExp(r'\s+'));
    final bWords = bLower.split(RegExp(r'\s+'));
    final commonWords = aWords.where((word) => bWords.contains(word)).length;

    return commonWords >= 2;
  }

  /// Obtiene detalles de posibles duplicados para mostrar al usuario
  Future<List<Transaccion>> getPossibleDuplicates({
    required double monto,
    required DateTime fecha,
  }) async {
    final inicio = fecha.subtract(const Duration(minutes: 10));
    final fin = fecha.add(const Duration(minutes: 10));

    return await (database.select(database.transacciones)
          ..where((t) =>
              t.montoTotal.equals(monto) &
              t.fecha.isBiggerOrEqualValue(inicio) &
              t.fecha.isSmallerOrEqualValue(fin))
          ..orderBy([(t) => OrderingTerm(expression: t.fecha, mode: OrderingMode.desc)])
          ..limit(3))
        .get();
  }

  /// Limpia manualmente el caché de notificaciones procesadas
  static void clearCache() {
    _processedNotificationIds.clear();
    _lastCleanup = DateTime.now();
  }

  /// Obtiene estadísticas del caché (para debugging)
  static Map<String, dynamic> getCacheStats() {
    return {
      'cachedIds': _processedNotificationIds.length,
      'lastCleanup': _lastCleanup.toIso8601String(),
      'ttl': _cacheTtl.inHours,
    };
  }
}
