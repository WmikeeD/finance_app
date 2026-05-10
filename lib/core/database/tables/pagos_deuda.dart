import 'package:drift/drift.dart';
import 'deudas.dart';
import 'transacciones.dart';

/// Registro de pagos parciales o totales de una deuda
@DataClassName('PagoDeuda')
class PagosDeuda extends Table {
  IntColumn get id => integer().autoIncrement()();
  
  // Deuda asociada
  IntColumn get deudaId => integer().references(Deudas, #id, onDelete: KeyAction.cascade)();
  
  // Monto pagado en este abono
  RealColumn get monto => real()();
  
  // Fecha del pago
  DateTimeColumn get fechaPago => dateTime().withDefault(currentDateAndTime)();
  
  // Método de pago: 'efectivo', 'transferencia', 'debito', etc.
  TextColumn get metodoPago => text().withDefault(const Constant('efectivo'))();
  
  // Notas
  TextColumn get notas => text().nullable()();

  // Transacción de ingreso generada al cobrar esta deuda (nullable)
  IntColumn get transaccionId => integer().nullable().references(Transacciones, #id, onDelete: KeyAction.setNull)();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
}