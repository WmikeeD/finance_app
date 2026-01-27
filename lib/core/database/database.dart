import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// Importar todas las tablas
import 'tables/cuentas.dart';
import 'tables/categorias.dart';
import 'tables/personas.dart';
import 'tables/transacciones.dart';
import 'tables/cuotas.dart';

// Este archivo será generado por build_runner
part 'database.g.dart';

/// Base de datos principal de la aplicación
@DriftDatabase(tables: [
  Cuentas,
  Categorias,
  Personas,
  Transacciones,
  Cuotas,
])
class AppDatabase extends _$AppDatabase {
  // Constructor
  AppDatabase() : super(_openConnection());

  // Versión del esquema (incrementar cuando hagas cambios)
  @override
  int get schemaVersion => 1;

  // Estrategia de migración
  @override
  MigrationStrategy get migration => MigrationStrategy(
        // Ejecutar antes de crear las tablas
        beforeOpen: (details) async {
          // Habilitar foreign keys (importante para las relaciones)
          await customStatement('PRAGMA foreign_keys = ON');
          
          // Si es la primera vez que se abre la base de datos
          if (details.wasCreated) {
            // Aquí puedes insertar datos iniciales (seed data)
            await _insertSeedData();
          }
        },
        
        // Migración cuando se actualiza la versión
        onUpgrade: (migrator, from, to) async {
          // Ejemplo de migración de versión 1 a 2
          // if (from < 2) {
          //   await migrator.addColumn(transacciones, transacciones.sincronizado);
          // }
        },
      );

  /// Insertar datos iniciales cuando se crea la base de datos
  Future<void> _insertSeedData() async {
    // Categorías de EGRESOS por defecto
    final categoriasEgreso = [
      CategoriasCompanion.insert(
        nombre: 'Alimentación',
        tipo: 'egreso',
        icono: const Value('restaurant'),
        color: const Value('#FF5722'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Transporte',
        tipo: 'egreso',
        icono: const Value('directions_car'),
        color: const Value('#2196F3'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Vivienda',
        tipo: 'egreso',
        icono: const Value('home'),
        color: const Value('#4CAF50'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Salud',
        tipo: 'egreso',
        icono: const Value('medical_services'),
        color: const Value('#F44336'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Entretenimiento',
        tipo: 'egreso',
        icono: const Value('sports_esports'),
        color: const Value('#9C27B0'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Educación',
        tipo: 'egreso',
        icono: const Value('school'),
        color: const Value('#FF9800'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Servicios',
        tipo: 'egreso',
        icono: const Value('receipt'),
        color: const Value('#607D8B'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Préstamos',
        tipo: 'egreso',
        icono: const Value('people'),
        color: const Value('#795548'),
      ),
    ];

    for (final categoria in categoriasEgreso) {
      await into(categorias).insert(categoria);
    }

    // Categorías de INGRESOS por defecto
    final categoriasIngreso = [
      CategoriasCompanion.insert(
        nombre: 'Salario',
        tipo: 'ingreso',
        icono: const Value('attach_money'),
        color: const Value('#4CAF50'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Freelance',
        tipo: 'ingreso',
        icono: const Value('work'),
        color: const Value('#2196F3'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Inversiones',
        tipo: 'ingreso',
        icono: const Value('trending_up'),
        color: const Value('#FF9800'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Otros ingresos',
        tipo: 'ingreso',
        icono: const Value('account_balance_wallet'),
        color: const Value('#9C27B0'),
      ),
    ];

    for (final categoria in categoriasIngreso) {
      await into(categorias).insert(categoria);
    }

    // Cuenta por defecto
    await into(cuentas).insert(
      CuentasCompanion.insert(
        nombre: 'Efectivo',
        tipo: 'efectivo',
        saldo: const Value(0.0),
        icono: const Value('payments'),
        color: const Value('#4CAF50'),
      ),
    );
  }
}

/// Abre la conexión a la base de datos SQLite
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Obtener el directorio de documentos de la app
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'finance_app.db'));
    
    return NativeDatabase.createInBackground(file);
  });
}