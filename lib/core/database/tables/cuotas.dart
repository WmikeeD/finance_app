import 'package:drift/drift.dart';
import 'transacciones.dart';

/// Tabla de cuotas para compras a crédito
@DataClassName('Cuota')
class Cuotas extends Table {
  // ID autoincremental
  IntColumn get id => integer().autoIncrement()();
  
  // Transacción padre (obligatoria)
  IntColumn get transaccionId => integer().references(Transacciones, #id, onDelete: KeyAction.cascade)();
  
  // Número de cuota (1, 2, 3, ...)
  IntColumn get numeroCuota => integer()();
  
  // Monto de la cuota
  RealColumn get monto => real()();
  
  // Fecha de vencimiento de la cuota
  DateTimeColumn get fechaVencimiento => dateTime()();
  
  // Si la cuota ya fue pagada
  BoolColumn get pagada => boolean().withDefault(const Constant(false))();
  
  // Fecha en que se pagó (null si no se ha pagado)
  DateTimeColumn get fechaPago => dateTime().nullable()();
  
  // --- Desglose opcional (si el banco lo muestra) ---
  
  // Monto que va a capital
  RealColumn get montoCapital => real().nullable()();
  
  // Monto que va a intereses
  RealColumn get montoInteres => real().nullable()();
  
  // --- Metadata ---
  
  // Notas sobre el pago de esta cuota
  TextColumn get notas => text().nullable()();
  
  // Timestamps
  DateTimeColumn get creadaEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadaEn => dateTime().withDefault(currentDateAndTime)();

  // --- Campos de sincronización con Supabase (v10) ---
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  TextColumn get syncId => text().nullable()(); // UUID de Supabase
  DateTimeColumn get ultimaModificacion => dateTime().withDefault(currentDateAndTime)();

  // --- Soft delete (v11) ---
  DateTimeColumn get deletedAt => dateTime().nullable()();

  // --- Multi-tenant (v12) ---
  TextColumn get userId => text().nullable()();

  // Índice compuesto para búsquedas rápidas
  @override
  List<Set<Column>> get uniqueKeys => [
    {transaccionId, numeroCuota}, // No puede haber cuotas duplicadas
  ];
}