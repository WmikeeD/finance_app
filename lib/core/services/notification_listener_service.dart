import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import '../models/bank_notification.dart';
import '../models/raw_transaction_draft.dart';
import '../config/bank_config.dart';
import '../utils/transaction_deduplicator.dart';
import '../database/database.dart';
import 'bank_regex_parser.dart';

/// Servicio de escucha de notificaciones bancarias
///
/// IMPORTANTE: Este es un stub/template. La implementación completa requiere:
///
/// 1. Permisos en Android (AndroidManifest.xml):
///    ```xml
///    <uses-permission android:name="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"/>
///    ```
///
/// 2. Plugin nativo o package:
///    - notification_listener_service (Android)
///    - flutter_notification_listener
///    - O implementación custom con MethodChannel
///
/// 3. Solicitar permiso al usuario en tiempo de ejecución
///
/// 4. Implementar NotificationListenerService en Android (Kotlin/Java)
class NotificationListenerService {
  final AppDatabase database;
  final TransactionDeduplicator deduplicator;

  /// Stream de transacciones detectadas automáticamente
  final _transactionController = StreamController<RawTransactionDraft>.broadcast();

  /// Stream público de transacciones
  Stream<RawTransactionDraft> get transactionStream => _transactionController.stream;

  /// Estado del servicio
  bool _isListening = false;

  /// Suscripción al stream de notificaciones
  StreamSubscription<dynamic>? _notificationSubscription;

  NotificationListenerService({
    required this.database,
    TransactionDeduplicator? deduplicator,
  }) : deduplicator = deduplicator ?? TransactionDeduplicator(database);

  /// Verifica si el servicio tiene permisos
  ///
  /// Solo disponible en Android
  Future<bool> hasPermission() async {
    // Platform guard: solo Android soporta NotificationListener
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }

    try {
      return await NotificationsListener.isRunning ?? false;
    } catch (e) {
      // Capturar MissingPluginException u otros errores de plataforma
      return false;
    }
  }

  /// Solicita permisos al usuario
  ///
  /// Abre la configuración del sistema para que el usuario habilite el listener
  /// Solo disponible en Android
  Future<bool> requestPermission() async {
    // Platform guard: solo Android soporta NotificationListener
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }

    try {
      final isRunning = await NotificationsListener.isRunning ?? false;
      if (!isRunning) {
        // Abre la configuración del sistema para habilitar el listener
        await NotificationsListener.openPermissionSettings();
        return false; // El usuario debe habilitarlo manualmente
      }
      return true;
    } catch (e) {
      // Capturar MissingPluginException u otros errores de plataforma
      return false;
    }
  }

  /// Inicia la escucha de notificaciones
  ///
  /// Solo disponible en Android
  Future<void> startListening() async {
    if (_isListening) return;

    // Platform guard: solo Android soporta NotificationListener
    if (kIsWeb || !Platform.isAndroid) {
      throw UnsupportedError(
        'NotificationListener solo está disponible en Android',
      );
    }

    try {
      // Verificar permisos
      final hasPerms = await hasPermission();
      if (!hasPerms) {
        throw Exception('Permisos de notificación no concedidos. Usa requestPermission() primero.');
      }

      _isListening = true;

      // Iniciar el servicio de notificaciones
      await NotificationsListener.startService(
        foreground: true,
        title: 'Finance App',
        description: 'Detectando transacciones bancarias automáticamente',
      );

      // Suscribirse al stream de notificaciones usando receivePort
      final receivePort = NotificationsListener.receivePort;
      if (receivePort != null) {
        _notificationSubscription = receivePort.listen(
          (dynamic event) {
            if (event is NotificationEvent) {
              _handleNotificationEvent(event);
            }
          },
          onError: (error) {
            // ignore: avoid_print
            print('Error en stream de notificaciones: $error');
          },
        );
      } else {
        _isListening = false;
        throw Exception('No se pudo iniciar el stream de notificaciones');
      }
    } catch (e) {
      _isListening = false;
      rethrow;
    }
  }

  /// Detiene la escucha de notificaciones
  ///
  /// Solo disponible en Android
  Future<void> stopListening() async {
    _isListening = false;
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;

    // Platform guard: solo Android soporta NotificationListener
    if (kIsWeb || !Platform.isAndroid) {
      return; // No-op en plataformas no compatibles
    }

    try {
      await NotificationsListener.stopService();
    } catch (e) {
      // Capturar MissingPluginException u otros errores de plataforma
      // No hacer nada, el servicio ya está detenido localmente
    }
  }

  /// Procesa un evento de notificación desde el plugin
  Future<void> _handleNotificationEvent(NotificationEvent event) async {
    await _handleNotification({
      'packageName': event.packageName ?? '',
      'title': event.title ?? '',
      'body': event.text ?? '',
      'timestamp': event.createAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'id': event.id?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    });
  }

  /// Procesa una notificación del sistema
  ///
  /// Este método SÍ está completamente implementado y listo para uso
  Future<void> _handleNotification(Map<String, dynamic> notificationData) async {
    try {
      // 1. Crear modelo de notificación
      final notification = BankNotification.fromSystem(
        packageName: notificationData['packageName'] ?? '',
        title: notificationData['title'] ?? '',
        body: notificationData['body'] ?? '',
        timestamp: notificationData['timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(notificationData['timestamp'])
            : null,
        id: notificationData['id']?.toString(),
      );

      // 2. Validar que sea de un paquete autorizado
      if (!BankConfig.isAuthorized(notification.packageName)) {
        return; // Ignorar notificaciones no bancarias
      }

      // 3. Verificar si ya fue procesada (deduplicación de reemisiones)
      if (notification.notificationId != null) {
        if (deduplicator.isNotificationProcessed(notification.notificationId!)) {
          return; // Ya procesada
        }
      }

      // 4. Validar que sea relevante
      if (!BankRegexParser.isRelevantNotification(notification.title, notification.body)) {
        return; // No es una transacción relevante
      }

      // 5. Parsear notificación
      final parseResult = BankRegexParser.parse(notification);
      if (!parseResult.success || !parseResult.isValid) {
        return; // No se pudo parsear
      }

      // 6. Verificar duplicados en base de datos
      final isDuplicate = await deduplicator.isDuplicate(
        monto: parseResult.monto!,
        fecha: notification.timestamp,
        descripcion: parseResult.descripcion,
      );

      // 7. Crear draft de transacción
      final draft = RawTransactionDraft.fromNotification(
        tipo: parseResult.tipo!,
        monto: parseResult.monto!,
        descripcion: parseResult.descripcion ?? 'Transacción bancaria',
        fecha: notification.timestamp,
        cuenta: parseResult.cuenta,
        isDuplicate: isDuplicate,
        rawText: '${notification.title}\n${notification.body}',
        confidence: BankRegexParser.getConfidence(parseResult),
      );

      // 8. Marcar notificación como procesada
      if (notification.notificationId != null) {
        deduplicator.markNotificationAsProcessed(notification.notificationId!);
      }

      // 9. Emitir draft al stream para que la UI lo procese
      _transactionController.add(draft);
    } catch (e) {
      // Log error pero no lanzar excepción
      // ignore: avoid_print
      print('Error procesando notificación bancaria: $e');
    }
  }

  /// Procesa manualmente una notificación (para testing)
  Future<void> processTestNotification({
    required String packageName,
    required String title,
    required String body,
  }) async {
    await _handleNotification({
      'packageName': packageName,
      'title': title,
      'body': body,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
    });
  }

  /// Estado del listener
  bool get isListening => _isListening;

  /// Verifica si la plataforma actual soporta NotificationListener
  static bool get isPlatformSupported {
    return !kIsWeb && Platform.isAndroid;
  }

  /// Cierra el servicio y libera recursos
  Future<void> dispose() async {
    await stopListening();
    await _transactionController.close();
  }

  /// Obtiene estadísticas del servicio (para debugging)
  Map<String, dynamic> getStats() {
    return {
      'isListening': _isListening,
      'authorizedPackages': BankConfig.authorizedPackages.length,
      'cacheStats': TransactionDeduplicator.getCacheStats(),
    };
  }
}
