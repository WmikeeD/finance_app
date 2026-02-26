import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/database/database.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/proyeccion/proyeccion_screen.dart';

void main() {
  runApp(const FinanceApp());
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final database = AppDatabase();
    
    return MyApp(database: database);
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
    _cargarColorPerfil();
  }

  /// Cargar el color guardado en el perfil
  Future<void> _cargarColorPerfil() async {
    final perfil = await widget.database.obtenerPerfil();
    if (perfil != null && perfil.colorPrimario.isNotEmpty) {
      setState(() {
        AppTheme.setColorFromHex(perfil.colorPrimario);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Perfil?>(
      stream: widget.database.select(widget.database.perfiles).watch().map(
        (perfiles) => perfiles.isEmpty ? null : perfiles.first,
      ),
      builder: (context, snapshot) {
        // Si el color cambió, actualizar el tema
        if (snapshot.hasData && snapshot.data != null) {
          final nuevoColor = snapshot.data!.colorPrimario;
          AppTheme.setColorFromHex(nuevoColor);
        }
        
        return MaterialApp(
          title: 'Finance App',
          debugShowCheckedModeBanner: false,
          
          // Localización en español
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
          themeMode: ThemeMode.light,
          routes: {
            //'/': (context) => HomeScreen(database: widget.database),
            //'/home': (context) => HomeScreen(database: widget.database),
            '/proyeccion': (context) => ProyeccionScreen(database: widget.database),
          },
          home: HomeScreen(database: widget.database),
        );
      },
    );
  }
}