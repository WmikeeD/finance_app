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

        // Color dinámico deshabilitado en M3 (el tema es estático)

        // Color estático ya no soportado en M3 - el color es fijo
        return _buildApp(themeMode);
      },
    );
  }

  Widget _buildApp(ThemeMode themeMode) {
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
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routes: {
        '/proyeccion': (context) =>
            ProyeccionScreen(database: widget.database),
      },
      home: AuthGate(database: widget.database),
    );
  }
}
