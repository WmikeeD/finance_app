import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio de autenticación con Supabase
///
/// Encapsula todas las operaciones de auth: registro, login, logout,
/// y stream de cambios de estado de sesión.
class AuthService {
  final SupabaseClient _supabase;

  AuthService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  /// Usuario actual autenticado (null si no hay sesión)
  User? get currentUser => _supabase.auth.currentUser;

  /// UUID del usuario actual (null si no hay sesión)
  String? get currentUserId => currentUser?.id;

  /// Stream de cambios de estado de autenticación
  /// Emite eventos cuando el usuario inicia/cierra sesión
  Stream<AuthState> get onAuthStateChange =>
      _supabase.auth.onAuthStateChange;

  /// Registra un nuevo usuario con email y contraseña
  ///
  /// Lanza [AuthException] si:
  /// - El email ya está registrado
  /// - La contraseña es muy débil (< 6 caracteres)
  /// - Hay problemas de red
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Inicia sesión con email y contraseña
  ///
  /// Lanza [AuthException] si:
  /// - Las credenciales son incorrectas
  /// - El usuario no existe
  /// - Hay problemas de red
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Cierra la sesión actual
  ///
  /// Limpia el token de sesión local y notifica al stream
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Verifica si hay una sesión activa
  bool get hasActiveSession => _supabase.auth.currentSession != null;
}
