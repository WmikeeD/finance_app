import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/database/database.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/proyeccion/proyeccion_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    if (!perfil.colorDinamico) {
      AppTheme.setColorFromHex(perfil.colorPrimario);
    }
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

        // Color dinámico: observa las cuentas en tiempo real
        if (perfil?.colorDinamico == true) {
          return StreamBuilder<List<Cuenta>>(
            stream: widget.database.select(widget.database.cuentas).watch(),
            builder: (context, cuentasSnap) {
              final cuentas = cuentasSnap.data ?? [];
              final balance = cuentas
                  .where((c) => c.tipo == 'efectivo' || c.tipo == 'debito')
                  .fold<double>(0, (s, c) => s + c.saldo);

              AppTheme.setPrimaryColor(AppTheme.calcularColorDinamico(
                balance,
                perfil!.balanceMinimo,
                perfil.balanceMaximo,
              ));

              return _buildApp(themeMode);
            },
          );
        }

        // Color estático del perfil
        if (perfil != null) AppTheme.setColorFromHex(perfil.colorPrimario);
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
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routes: {
        '/proyeccion': (context) =>
            ProyeccionScreen(database: widget.database),
      },
      home: HomeScreen(database: widget.database),
    );
  }
}
