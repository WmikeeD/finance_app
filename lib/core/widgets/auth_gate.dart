import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../database/database.dart';
import '../navigation/app_tab_controller.dart';
import '../services/sync_service.dart';
import 'app_shell.dart';

/// Auth Gate - Control de sesión en la raíz de la app
///
/// Decide qué mostrar según el estado de autenticación:
/// - Sin sesión → AuthScreen (login/registro)
/// - Con sesión → AppShell (dashboard principal)
///
/// Escucha cambios de estado de auth y actualiza automáticamente.
/// Dispara sincronización automática después del login.
class AuthGate extends StatefulWidget {
  final AppDatabase database;

  const AuthGate({
    super.key,
    required this.database,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final SyncService _syncService;
  String? _previousUserId;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _syncService = SyncService(database: widget.database);
    _previousUserId = Supabase.instance.client.auth.currentUser?.id;
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }

  /// Disparar sincronización cuando el usuario inicia sesión
  ///
  /// Si es primera sincronización (DB local vacía), espera a que termine
  /// antes de permitir navegación al Dashboard para evitar mostrar Balance $0.
  ///
  /// Incluye timeout de 30 segundos para no bloquear indefinidamente
  /// en caso de problemas de red.
  Future<void> _triggerSyncOnLogin(String userId) async {
    if (_previousUserId != userId) {
      _previousUserId = userId;

      // Detectar si es primera sincronización (DB local vacía)
      final transaccionesLocales = await widget.database
          .select(widget.database.transacciones)
          .get();

      final isFirstSync = transaccionesLocales.isEmpty;

      if (isFirstSync) {
        debugPrint('🔄 Primera sincronización detectada (DB local vacía) - Bloqueando UI hasta completar');

        // Activar estado de carga
        if (mounted) {
          setState(() => _isSyncing = true);
        }

        try {
          // Esperar sincronización con timeout de 30 segundos
          final result = await _syncService
              .syncAll(forceFullSync: true)
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () {
                  debugPrint('⚠️ Timeout en sincronización inicial - continuando offline');
                  return SyncResult(
                    success: false,
                    errorMessage: 'Timeout - sin conexión',
                    recordsPushed: 0,
                    recordsPulled: 0,
                  );
                },
              );

          if (result.success) {
            debugPrint(
              '✅ Sincronización inicial completada: '
              '${result.recordsPushed} push, ${result.recordsPulled} pull',
            );
          } else {
            debugPrint('⚠️ Sincronización falló (modo offline): ${result.errorMessage}');
          }
        } catch (e) {
          debugPrint('❌ Error en sincronización inicial: $e - continuando offline');
        } finally {
          // Desactivar estado de carga
          if (mounted) {
            setState(() => _isSyncing = false);
          }
        }
      } else {
        // Sincronización incremental en background (no bloquea UI)
        debugPrint('🔄 Sincronización incremental en background');
        _syncService.syncAll(forceFullSync: false).then((result) {
          if (mounted && result.success) {
            debugPrint(
              'Sincronización incremental completada: '
              '${result.recordsPushed} push, ${result.recordsPulled} pull',
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Estado inicial: verificar sesión actual
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        // Sesión activa → Dashboard (con bloqueo durante primera sincronización)
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          // Si está sincronizando (primera vez), mostrar pantalla de carga
          if (_isSyncing) {
            return const _SyncingScreen();
          }

          // Resetear navegación a Dashboard (índice 0) al iniciar sesión
          AppTabController.goToHome();

          // Disparar sincronización automática
          final userId = session.user.id;
          _triggerSyncOnLogin(userId);

          return AppShell(database: widget.database);
        }

        // Sin sesión → Autenticación
        // Resetear navegación para que la próxima sesión comience en Dashboard
        AppTabController.goToHome();
        _previousUserId = null;
        return const AuthScreen();
      },
    );
  }
}

/// Pantalla de carga inicial mientras se verifica la sesión
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: CircularProgressIndicator(
          color: scheme.primary,
        ),
      ),
    );
  }
}

/// Pantalla de sincronización durante la primera carga de datos
class _SyncingScreen extends StatelessWidget {
  const _SyncingScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: scheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Sincronizando tus finanzas...',
              style: textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Descargando tus datos desde la nube',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
