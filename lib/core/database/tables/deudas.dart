import 'package:drift/drift.dart';
import 'personas.dart';
import 'transacciones.dart';

/// Tabla de deudas de personas hacia ti
/// Relacionada con transacciones de préstamo
@DataClassName('Deuda')
class Deudas extends Table {
  // ID autoincremental
  IntColumn get id => integer().autoIncrement()();
  
  // Persona que debe (obligatorio)
  IntColumn get personaId => integer().references(Personas, #id, onDelete: KeyAction.cascade)();
  
  // Transacción original que generó la deuda (obligatorio)
  IntColumn get transaccionId => integer().references(Transacciones, #id, onDelete: KeyAction.cascade)();
  
  // Tipo de deuda: 'simple' (efectivo/debito) o 'cuotas' (credito)
  TextColumn get tipo => text().withLength(min: 1, max: 10)();
  
  // Monto total que debe la persona
  RealColumn get montoTotal => real()();
  
  // Monto pendiente por pagar
  RealColumn get montoPendiente => real()();
  
  // Monto pagado hasta ahora
  RealColumn get montoPagado => real().withDefault(const Constant(0.0))();
  
  // Para deudas simples: fecha acordada de pago (opcional)
  DateTimeColumn get fechaAcordadaPago => dateTime().nullable()();
  
  // Estado: 'pendiente', 'parcial', 'pagada', 'vencida'
  TextColumn get estado => text().withDefault(const Constant('pendiente'))();
  
  // Notas sobre la deuda
  TextColumn get notas => text().nullable()();
  
  // Timestamps
  DateTimeColumn get creadaEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadaEn => dateTime().withDefault(currentDateAndTime)();
  
  @override
  List<Set<Column>> get uniqueKeys => [
    // Una persona no puede tener dos deudas por la misma transacción
    {transaccionId},
  ];
}