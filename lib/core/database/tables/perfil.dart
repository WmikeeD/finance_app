import 'package:drift/drift.dart';

/// Tabla de perfil del usuario.
/// Solo tendrá UN solo registro (id siempre será 1).
@DataClassName('Perfil')
class Perfiles extends Table {
  // ID fijo (siempre será 1, solo hay un perfil local)
  IntColumn get id => integer().withDefault(const Constant(1))();

  // Datos del usuario
  TextColumn get nombre => text().withLength(min: 1, max: 100).nullable()();
  DateTimeColumn get fechaNacimiento => dateTime().nullable()();

  // Preferencias de la app
  TextColumn get colorPrimario =>
      text().withLength(min: 7, max: 9).withDefault(const Constant('#6C63FF'))();

  // null = sistema, true = oscuro, false = claro
  BoolColumn get temaOscuro => boolean().nullable()();

  // Color dinámico según balance disponible
  BoolColumn get colorDinamico =>
      boolean().withDefault(const Constant(false))();
  RealColumn get balanceMinimo =>
      real().withDefault(const Constant(100000.0))();
  RealColumn get balanceMaximo =>
      real().withDefault(const Constant(50000000.0))();

  // Notificaciones
  BoolColumn get notifCuotas =>
      boolean().withDefault(const Constant(true))();
  IntColumn get notifDiasAntes =>
      integer().withDefault(const Constant(3))();
  BoolColumn get notifGastosFijos =>
      boolean().withDefault(const Constant(true))();

  // --- Campos de sincronización con Supabase (v10) ---
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get syncId => text().nullable()(); // UUID de Supabase
  DateTimeColumn get ultimaModificacion => dateTime().nullable()();

  // --- Multi-tenant (v12) ---
  // En Supabase, el perfil será 1:1 con auth.users(id)
  TextColumn get userId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}