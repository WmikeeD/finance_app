import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/database/database.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/widgets.dart';
import 'features/proyeccion/proyeccion_screen.dart';
import 'features/ingresos_recurrentes/services/automatizacion_ingresos_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno desde .env
  await dotenv.load(fileName: ".env");

  // Inicializar Supabase con credenciales seguras
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabasePublishableKey,
  );

  await NotificationService.initialize();
  runApp(const FinanceApp());
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MyApp(database: AppDatabase());
  }
}

class MyApp extends StatefulWidget {
  final AppDatabase database;

  const MyApp({super.key, required this.database});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _cargarColorInicial();
    _iniciarNotificaciones();
    _procesarIngresosRecurrentes();
  }

  Future<void> _cargarColorInicial() async {
    final perfil = await widget.database.obtenerPerfil();
    if (perfil == null) return;
    // Color dinámico ya no está soportado en la versión M3
    // El color primario está fijo en app_theme.dart
  }

  Future<void> _iniciarNotificaciones() async {
    final tiene = await NotificationService.tienePermiso();
    if (!tiene) {
      await NotificationService.solicitarPermiso();
    }
    await NotificationService.programarNotificaciones(widget.database);
  }

  /// Procesa automáticamente los ingresos recurrentes pendientes
  ///
  /// Este método se ejecuta al iniciar la app y verifica si hay ingresos
  /// recurrentes cuya fecha de pago ya pasó pero aún no se han registrado.
  /// Si encuentra alguno, crea automáticamente la transacción correspondiente.
  Future<void> _procesarIngresosRecurrentes() async {
    try {
      final service = AutomatizacionIngresosService(widget.database);

      // Procesar ingresos pendientes desde el inicio del mes
      final transaccionesCreadas = await service.procesarIngresosPendientes();

      if (transaccionesCreadas > 0) {
        debugPrint(
          '✅ AutomatizaciónIngresos: $transaccionesCreadas transacción(es) creada(s) automáticamente',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error al procesar ingresos recurrentes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Perfil?>(
      stream: widget.database
          .select(widget.database.perfiles)
          .watch()
          .map((p) => p.isEmpty ? null : p.first),
      builder: (context, perfilSnap) {
        final perfil = perfilSnap.data;

        final temaOscuro = perfil?.temaOscuro;
        final themeMode = temaOscuro == null
            ? ThemeMode.system
            : temaOscuro
                ? ThemeMode.dark
                : ThemeMode.light;

        // Sistema de color reactivo y dinámico
        return StreamBuilder<List<Cuenta>>(
          stream: widget.database.select(widget.database.cuentas).watch(),
          builder: (context, cuentasSnap) {
            Color? primarySeedColor;

            // Prioridad 1: Color Dinámico (si está activado)
            if (perfil?.colorDinamico == true) {
              final cuentas = cuentasSnap.data ?? [];
              final balance = cuentas
                  .where((c) => c.tipo == 'efectivo' || c.tipo == 'debito')
                  .fold<double>(0, (sum, cuenta) => sum + cuenta.saldo);

              primarySeedColor = AppTheme.calcularColorDinamico(
                balance,
                perfil?.balanceMinimo ?? 100000,
                perfil?.balanceMaximo ?? 50000000,
              );
            }
            // Prioridad 2: Color Principal manual
            else if (perfil?.colorPrimario != null) {
              final colorHex = perfil!.colorPrimario;
              try {
                primarySeedColor = Color(
                  int.parse(colorHex.replaceFirst('#', '0xFF')),
                );
              } catch (e) {
                // Si el parsing falla, usar color por defecto
                primarySeedColor = null;
              }
            }
            // Prioridad 3: Color por defecto (null = AppTheme usa su default)

            return _buildApp(themeMode, primarySeedColor);
          },
        );
      },
    );
  }

  Widget _buildApp(ThemeMode themeMode, Color? primarySeedColor) {
    return MaterialApp(
      title: 'Finance App',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      locale: const Locale('es', 'ES'),
      theme: AppTheme.light(primarySeedColor: primarySeedColor),
      darkTheme: AppTheme.dark(primarySeedColor: primarySeedColor),
      themeMode: themeMode,
      routes: {
        '/proyeccion': (context) =>
            ProyeccionScreen(database: widget.database),
      },
      home: AuthGate(database: widget.database),
    );
  }
}
