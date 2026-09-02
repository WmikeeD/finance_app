import 'package:drift/drift.dart';
import 'cuentas.dart';

@DataClassName('IngresoRecurrente')
class IngresosRecurrentes extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Identificación y descripción
  TextColumn get supabaseId => text().nullable()(); // UUID para sync futuro
  TextColumn get descripcion => text().withLength(min: 1, max: 100)();

  // Monto y cuenta asociada
  RealColumn get monto => real()();
  IntColumn get cuentaId => integer().references(Cuentas, #id)();

  // Frecuencia y configuración de fechas
  // Valores: 'dia_fijo', 'ultimo_dia_habil', 'primer_dia_habil', 'quincenal'
  TextColumn get frecuencia => text().withLength(min: 1, max: 50)();
  IntColumn get diaMes => integer().nullable()(); // Para frecuencia 'dia_fijo' (1-31)

  // Control de vigencia temporal
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
  DateTimeColumn get fechaInicio => dateTime()(); // Inicio de vigencia del monto
  DateTimeColumn get fechaFin => dateTime().nullable()(); // Fin de vigencia si hubo cambio

  // Timestamps
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // --- Soft delete ---
  DateTimeColumn get deletedAt => dateTime().nullable()();

  // --- Campos de sincronización con Supabase ---
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get syncId => text().nullable()(); // UUID de Supabase
  DateTimeColumn get ultimaModificacion => dateTime().nullable()();

  // --- Multi-tenant ---
  TextColumn get userId => text().nullable()();
}
