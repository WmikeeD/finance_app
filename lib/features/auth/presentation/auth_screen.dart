import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/responsive.dart';

/// Pantalla de autenticación (Login / Registro)
///
/// Diseño Material Design 3 con:
/// - Toggle entre modos Login/Registro
/// - Validación de formulario
/// - Estados de carga
/// - Mensajes de error claros
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLogin = true; // true = login, false = registro
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _authService.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      // La navegación se maneja automáticamente por AuthGate
      // al detectar el cambio de estado de auth
    } on AuthException catch (e) {
      if (!mounted) return;

      // Mensajes de error localizados
      String errorMessage;
      switch (e.message) {
        case 'Invalid login credentials':
          errorMessage = 'Credenciales incorrectas';
          break;
        case 'Email not confirmed':
          errorMessage = 'Email no confirmado. Revisa tu bandeja de entrada.';
          break;
        case 'User already registered':
          errorMessage = 'Este email ya está registrado';
          break;
        default:
          errorMessage = e.message;
      }

      _showError(errorMessage);
    } catch (e) {
      if (!mounted) return;
      _showError('Error de conexión. Verifica tu internet.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: scheme.errorContainer,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveHelper.getHorizontalPadding(context),
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / Ícono de la app
                  PhosphorIcon(
                    PhosphorIconsRegular.wallet,
                    size: 64,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 16),

                  // Título
                  Text(
                    'Finance App',
                    style: textTheme.displaySmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtítulo
                  Text(
                    'Control de finanzas personales',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Toggle Login / Registro
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Iniciar Sesión'),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Registrarse'),
                      ),
                    ],
                    selected: {_isLogin},
                    onSelectionChanged: (Set<bool> selection) {
                      setState(() => _isLogin = selection.first);
                    },
                  ),
                  const SizedBox(height: 32),

                  // Campo Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: PhosphorIcon(
                        PhosphorIconsRegular.envelope,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa tu email';
                      }
                      if (!value.contains('@')) {
                        return 'Email inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Campo Contraseña
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    enabled: !_isLoading,
                    onFieldSubmitted: (_) => _handleSubmit(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: PhosphorIcon(
                        PhosphorIconsRegular.lock,
                        color: scheme.onSurfaceVariant,
                      ),
                      suffixIcon: IconButton(
                        icon: PhosphorIcon(
                          _obscurePassword
                              ? PhosphorIconsRegular.eye
                              : PhosphorIconsRegular.eyeSlash,
                          color: scheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa tu contraseña';
                      }
                      if (!_isLogin && value.length < 6) {
                        return 'Mínimo 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Botón principal
                  FilledButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                scheme.onPrimary,
                              ),
                            ),
                          )
                        : Text(_isLogin ? 'Iniciar Sesión' : 'Registrarse'),
                  ),
                  const SizedBox(height: 16),

                  // Mensaje informativo para registro
                  if (!_isLogin)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          PhosphorIcon(
                            PhosphorIconsRegular.info,
                            color: scheme.onPrimaryContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Recibirás un email de confirmación',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
