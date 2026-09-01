import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuración de Supabase
///
/// Las credenciales se cargan desde el archivo .env
/// que NO debe ser commiteado a Git.
class SupabaseConfig {
  /// URL base del proyecto Supabase (sin /rest/v1 al final)
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? _throwMissingEnv('SUPABASE_URL');

  /// Publishable Key (antes Anon Key) del proyecto Supabase
  static String get supabasePublishableKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? _throwMissingEnv('SUPABASE_ANON_KEY');

  /// Getter auxiliar de compatibilidad
  static String get supabaseAnonKey => supabasePublishableKey;

  /// Validación de configuración
  static bool get isConfigured {
    return dotenv.env.containsKey('SUPABASE_URL') &&
        dotenv.env.containsKey('SUPABASE_ANON_KEY') &&
        supabaseUrl.isNotEmpty &&
        supabasePublishableKey.isNotEmpty;
  }

  /// Lanza excepción si falta una variable de entorno crítica
  static String _throwMissingEnv(String key) {
    throw Exception(
      'Variable de entorno $key no encontrada. '
      'Asegúrate de tener un archivo .env en la raíz del proyecto '
      'con las credenciales de Supabase (copia .env.example como plantilla).',
    );
  }
}