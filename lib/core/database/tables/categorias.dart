import 'package:drift/drift.dart';

/// Tabla de categorías con soporte para subcategorías (auto-referencial)
@DataClassName('Categoria')
class Categorias extends Table {
  // ID autoincremental
  IntColumn get id => integer().autoIncrement()();
  
  // Nombre de la categoría (ej: "Alimentación", "Transporte")
  TextColumn get nombre => text().withLength(min: 1, max: 100)();
  
  // Tipo: 'ingreso' o 'egreso'
  TextColumn get tipo => text().withLength(min: 1, max: 10)();
  
  // Categoría padre (NULL si es categoría principal)
  // Ejemplo: "Combustible" tiene categoria_padre_id = ID de "Auto"
  IntColumn get categoriaPadreId => integer().nullable().references(Categorias, #id, onDelete: KeyAction.cascade)();
  
  // Color hex para visualización (ej: "#FF5733")
  TextColumn get color => text().withLength(min: 7, max: 9).withDefault(const Constant('#9C27B0'))();
  
  // Icono (nombre del icono de Material Icons)
  TextColumn get icono => text().withLength(max: 50).withDefault(const Constant('category'))();
  
  // Orden para mostrar en listas
  IntColumn get orden => integer().withDefault(const Constant(0))();
  
  // Si la categoría está activa
  BoolColumn get activa => boolean().withDefault(const Constant(true))();
  
  // Timestamps
  DateTimeColumn get creadaEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadaEn => dateTime().withDefault(currentDateAndTime)();
}