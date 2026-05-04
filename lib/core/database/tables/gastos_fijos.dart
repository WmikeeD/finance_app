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
}