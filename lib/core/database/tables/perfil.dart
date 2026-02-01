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

  @override
  Set<Column> get primaryKey => {id};
}