import 'package:drift/drift.dart';

/// Tabla de mapeo entre IDs locales (INTEGER) y IDs de Supabase (UUID)
/// Permite rastrear la equivalencia entre registros locales y remotos
@DataClassName('SyncMapping')
class SyncMappings extends Table {
  // Nombre de la tabla (ej: 'transacciones', 'cuentas')
  TextColumn get tabla => text().withLength(min: 1, max: 50)();

  // ID local (INTEGER autoincremental)
  IntColumn get localId => integer()();

  // ID remoto en Supabase (UUID)
  TextColumn get supabaseId => text().withLength(min: 36, max: 36)();

  // Timestamp de sincronización
  DateTimeColumn get syncedAt => dateTime().withDefault(currentDateAndTime)();

  // Versión de sincronización (para conflict detection)
  IntColumn get syncVersion => integer().withDefault(const Constant(1))();

  // Primary key compuesta: tabla + supabaseId
  // Permite que múltiples UUIDs remotos apunten al mismo localId sin sobrescritura
  @override
  Set<Column> get primaryKey => {tabla, supabaseId};
}
