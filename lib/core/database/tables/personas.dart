import 'package:drift/drift.dart';

/// Tabla de personas a quienes se presta dinero o realizan compras con tu tarjeta
@DataClassName('Persona')
class Personas extends Table {
  // ID autoincremental
  IntColumn get id => integer().autoIncrement()();
  
  // Nombre de la persona
  TextColumn get nombre => text().withLength(min: 1, max: 100)();
  
  // Teléfono (opcional)
  TextColumn get telefono => text().withLength(max: 20).nullable()();
  
  // Email (opcional)
  TextColumn get email => text().withLength(max: 100).nullable()();
  
  // Relación (ej: "Mamá", "Hermano", "Amigo")
  TextColumn get relacion => text().withLength(max: 50).nullable()();
  
  // Notas adicionales
  TextColumn get notas => text().nullable()();
  
  // Avatar/iniciales para UI
  TextColumn get avatar => text().withLength(max: 2).nullable()();
  
  // Color para identificar visualmente
  TextColumn get color => text().withLength(min: 7, max: 9).withDefault(const Constant('#4CAF50'))();
  
  // Si la persona está activa
  BoolColumn get activa => boolean().withDefault(const Constant(true))();
  
  // Timestamps
  DateTimeColumn get creadaEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadaEn => dateTime().withDefault(currentDateAndTime)();
}