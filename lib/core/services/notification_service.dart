import 'package:drift/drift.dart' hide Column;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../database/database.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ─── Inicialización ───────────────────────────────────────────────────────

  static Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Santiago'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    _initialized = true;
  }

  // ─── Permisos ─────────────────────────────────────────────────────────────

  static Future<bool> solicitarPermiso() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return false;
  }

  static Future<bool> tienePermiso() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.areNotificationsEnabled();
      return granted ?? false;
    }
    return true;
  }

  // ─── Programar notificaciones ─────────────────────────────────────────────

  static Future<void> programarNotificaciones(AppDatabase db) async {
    if (!await tienePermiso()) return;

    final perfil = await db.obtenerPerfil();
    if (perfil == null) return;

    await cancelarTodas();

    if (perfil.notifCuotas) {
      await _programarNotifCuotas(db, perfil.notifDiasAntes);
    }

    if (perfil.notifGastosFijos) {
      await _programarNotifGastosFijos(db, perfil.notifDiasAntes);
    }
  }

  static Future<void> _programarNotifCuotas(
      AppDatabase db, int diasAntes) async {
    final ahora = DateTime.now();
    final limite = DateTime(ahora.year, ahora.month + 2, 1);

    final cuotas = await (db.select(db.cuotas)
          ..where((c) =>
              c.pagada.equals(false) &
              c.fechaVencimiento.isBiggerOrEqualValue(ahora) &
              c.fechaVencimiento.isSmallerOrEqualValue(limite)))
        .get();

    for (final cuota in cuotas) {
      final fechaNotif =
          cuota.fechaVencimiento.subtract(Duration(days: diasAntes));
      if (fechaNotif.isBefore(ahora)) continue;

      final tzFecha = tz.TZDateTime.from(fechaNotif, tz.local);

      await _plugin.zonedSchedule(
        id: _idCuota(cuota.id),
        title: 'Cuota por vencer',
        body:
            'Cuota #${cuota.numeroCuota} vence el ${_formatFecha(cuota.fechaVencimiento)} — \$${cuota.monto.toStringAsFixed(0)}',
        scheduledDate: tzFecha,
        notificationDetails: _detalleNotificacion(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  static Future<void> _programarNotifGastosFijos(
      AppDatabase db, int diasAntes) async {
    final ahora = DateTime.now();
    final gastos = await (db.select(db.gastosFijos)
          ..where((g) => g.activo.equals(true)))
        .get();

    for (final gasto in gastos) {
      final diaVenc = gasto.diaVencimiento;
      if (diaVenc == null) continue;

      var fechaVenc = DateTime(ahora.year, ahora.month, diaVenc);
      if (fechaVenc.isBefore(ahora)) {
        fechaVenc = DateTime(ahora.year, ahora.month + 1, diaVenc);
      }

      final fechaNotif = fechaVenc.subtract(Duration(days: diasAntes));
      if (fechaNotif.isBefore(ahora)) continue;

      final tzFecha = tz.TZDateTime.from(fechaNotif, tz.local);

      await _plugin.zonedSchedule(
        id: _idGastoFijo(gasto.id),
        title: 'Gasto fijo próximo',
        body:
            '${gasto.nombre} vence el día $diaVenc — \$${gasto.monto.toStringAsFixed(0)}',
        scheduledDate: tzFecha,
        notificationDetails: _detalleNotificacion(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  static Future<void> cancelarTodas() async {
    await _plugin.cancelAll();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static NotificationDetails _detalleNotificacion() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'finance_app_channel',
        'Finance App',
        channelDescription: 'Recordatorios de pagos y vencimientos',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  static int _idCuota(int cuotaId) => 10000 + cuotaId;
  static int _idGastoFijo(int gastoId) => 20000 + gastoId;

  static String _formatFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }
}
