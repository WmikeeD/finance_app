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
import 'tables/perfil.dart';

// Este archivo será generado por build_runner
part 'database.g.dart';

/// Base de datos principal de la aplicación
@DriftDatabase(tables: [
  Cuentas,
  Categorias,
  Personas,
  Transacciones,
  Cuotas,
  Perfiles,
])
class AppDatabase extends _$AppDatabase {
  // Constructor
  AppDatabase() : super(_openConnection());

  // Versión del esquema (incrementar cuando hagas cambios)
  @override
  int get schemaVersion => 2;

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
          // Migración v1 → v2: agregar tabla Perfiles
          if (from < 2) {
            await migrator.createTable(perfiles);
          }
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

    // Perfil por defecto
    await into(perfiles).insert(
      PerfilesCompanion.insert(
        id: const Value(1),
      ),
    );
  }

  // =============================================
  // MÉTODOS DE PERFIL
  // =============================================

  /// Obtener el perfil del usuario (siempre id = 1)
  Future<Perfil?> obtenerPerfil() async {
    return await (select(perfiles)..where((p) => p.id.equals(1)))
        .getSingleOrNull();
  }

  /// Guardar/actualizar el perfil
  Future<void> guardarPerfil(PerfilesCompanion perfil) async {
    final existe = await obtenerPerfil();
    if (existe == null) {
      await into(perfiles).insert(perfil.copyWith(id: const Value(1)));
    } else {
      await (update(perfiles)..where((p) => p.id.equals(1))).write(perfil);
    }
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