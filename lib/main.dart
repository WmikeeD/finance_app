import 'package:flutter/material.dart';
import 'core/database/database.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

void main() {
  // Inicializar la base de datos
  final database = AppDatabase();
  
  runApp(MyApp(database: database));
}

class MyApp extends StatelessWidget {
  final AppDatabase database;
  
  const MyApp({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: HomeScreen(database: database),
    );
  }
}