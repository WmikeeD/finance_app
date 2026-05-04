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
import 'tables/deudas.dart';
import 'tables/pagos_deuda.dart';
import 'tables/gastos_fijos.dart';

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
  Deudas,  
  PagosDeuda, 
  GastosFijos,
])
class AppDatabase extends _$AppDatabase {
  // Constructor
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 8;

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
          
          // Migración v2 → v3: agregar campo meta a Cuentas
          if (from < 3) {
            await migrator.addColumn(cuentas, cuentas.meta);
          }

          // Migración v3 → v4: agregar tabla Deudas y PagosDeuda
          if (from < 4) {
            await migrator.createTable(deudas);
            await migrator.createTable(pagosDeuda);
          }

          // Migración v4 → v5: agregar tabla GastosFijos
          if (from < 5) {
            await migrator.createTable(gastosFijos);
          }

          // Migración v5 → v6: agregar campo temaOscuro al perfil
          if (from < 6) {
            await migrator.addColumn(perfiles, perfiles.temaOscuro);
          }

          // Migración v6 → v7: color dinámico y límites de balance
          if (from < 7) {
            await migrator.addColumn(perfiles, perfiles.colorDinamico);
            await migrator.addColumn(perfiles, perfiles.balanceMinimo);
            await migrator.addColumn(perfiles, perfiles.balanceMaximo);
          }

          // Migración v7 → v8: preferencias de notificaciones
          if (from < 8) {
            await migrator.addColumn(perfiles, perfiles.notifCuotas);
            await migrator.addColumn(perfiles, perfiles.notifDiasAntes);
            await migrator.addColumn(perfiles, perfiles.notifGastosFijos);
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

  // =============================================
  // MÉTODOS DE GASTOS FIJOS
  // =============================================

  Stream<List<GastoFijo>> watchGastosFijos({bool? soloActivos}) {
    final query = select(gastosFijos)
      ..orderBy([(g) => OrderingTerm.asc(g.diaVencimiento)]);
    if (soloActivos == true) {
      query.where((g) => g.activo.equals(true));
    }
    return query.watch();
  }

  Future<void> insertarGastoFijo(GastosFijosCompanion gasto) async {
    await into(gastosFijos).insert(gasto);
  }

  Future<void> actualizarGastoFijo(GastosFijosCompanion gasto) async {
    await (update(gastosFijos)..where((g) => g.id.equals(gasto.id.value)))
        .write(gasto);
  }

  Future<void> eliminarGastoFijo(int id) async {
    await (delete(gastosFijos)..where((g) => g.id.equals(id))).go();
  }

  Future<double> totalGastosFijosActivos() async {
    final activos = await (select(gastosFijos)
          ..where((g) => g.activo.equals(true)))
        .get();
    return activos.fold<double>(0.0, (sum, g) => sum + g.monto);
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