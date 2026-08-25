import 'package:drift/drift.dart';
import 'categorias.dart';

@DataClassName('GastoFijo')
class GastosFijos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text().withLength(min: 1, max: 100)();
  RealColumn get monto => real()();
  IntColumn get diaVencimiento => integer().nullable()();
  IntColumn get categoriaId =>
      integer().nullable().references(Categorias, #id)();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();

  // --- Campos de sincronización con Supabase (v10) ---
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get syncId => text().nullable()(); // UUID de Supabase
  DateTimeColumn get ultimaModificacion => dateTime().withDefault(currentDateAndTime)();

  // --- Multi-tenant (v12) ---
  TextColumn get userId => text().nullable()();
}