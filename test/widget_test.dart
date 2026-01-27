import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_app/main.dart';
import 'package:finance_app/core/database/database.dart';

void main() {
  testWidgets('App debe mostrar pantalla de bienvenida', (WidgetTester tester) async {
    // Crear instancia de la base de datos para testing
    final database = AppDatabase();

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(database: database));

    // Verificar que el título aparece
    expect(find.text('¡Bienvenido a Finance App!'), findsOneWidget);
    
    // Verificar que el botón de verificar existe
    expect(find.text('Verificar Base de Datos'), findsOneWidget);
    
    // Verificar que el FAB existe
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // Cerrar la base de datos después del test
    await database.close();
  });

  testWidgets('Botón verificar base de datos funciona', (WidgetTester tester) async {
    final database = AppDatabase();

    await tester.pumpWidget(MyApp(database: database));

    // Encontrar y presionar el botón
    final button = find.text('Verificar Base de Datos');
    await tester.tap(button);
    await tester.pumpAndSettle();

    // Verificar que aparece el SnackBar
    expect(find.byType(SnackBar), findsOneWidget);

    await database.close();
  });
}