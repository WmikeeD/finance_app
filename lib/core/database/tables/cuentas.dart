import 'package:drift/drift.dart';

/// Tabla de cuentas bancarias, tarjetas de crédito, efectivo, etc.
@DataClassName('Cuenta')
class Cuentas extends Table {
  // ID autoincremental
  IntColumn get id => integer().autoIncrement()();
  
  // Nombre de la cuenta (ej: "Tarjeta Visa", "Cuenta Corriente Banco X")
  TextColumn get nombre => text().withLength(min: 1, max: 100)();
  
  // Tipo de cuenta: 'credito', 'debito', 'efectivo', 'ahorro'
  TextColumn get tipo => text().withLength(min: 1, max: 20)();
  
  // Saldo actual de la cuenta
  RealColumn get saldo => real().withDefault(const Constant(0.0))();
  
  // Límite de crédito (solo para tarjetas de crédito)
  RealColumn get limiteCredito => real().nullable()();
  
  // Día de cierre de tarjeta (1-31, solo para crédito)
  IntColumn get diaCierre => integer().nullable()();
  
  // Día de pago de tarjeta (1-31, solo para crédito)
  IntColumn get diaPago => integer().nullable()();
  
  // Color hex para identificar visualmente (ej: "#FF5733")
  TextColumn get color => text().withLength(min: 7, max: 9).withDefault(const Constant('#2196F3'))();
  
  // Icono (nombre del icono de Material Icons)
  TextColumn get icono => text().withLength(max: 50).withDefault(const Constant('credit_card'))();
  
  // Si la cuenta está activa o archivada
  BoolColumn get activa => boolean().withDefault(const Constant(true))();
  
  // Timestamps
  DateTimeColumn get creadaEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadaEn => dateTime().withDefault(currentDateAndTime)();
}