import 'package:drift/drift.dart';
import 'cuentas.dart';
import 'categorias.dart';
import 'personas.dart';

/// Tabla principal de transacciones (ingresos y egresos)
@DataClassName('Transaccion')
class Transacciones extends Table {
  // ID autoincremental
  IntColumn get id => integer().autoIncrement()();
  
  // Tipo de transacción: 'ingreso' o 'egreso'
  TextColumn get tipo => text().withLength(min: 1, max: 10)();
  
  // Descripción/concepto de la transacción
  TextColumn get descripcion => text().withLength(min: 1, max: 255)();
  
  // Monto original de la compra/transacción (sin intereses)
  RealColumn get montoTotal => real()();
  
  // Forma de pago: 'debito' (inmediato) o 'credito' (cuotas)
  TextColumn get formaPago => text().withLength(min: 1, max: 10)();
  
  // Es un préstamo a terceros (true) o gasto propio (false)
  BoolColumn get esPrestamo => boolean().withDefault(const Constant(false))();
  
  // Estado: 'pendiente', 'completado', 'cancelado'
  TextColumn get estado => text().withDefault(const Constant('pendiente'))();
  
  // Fecha de la transacción
  DateTimeColumn get fecha => dateTime()();
  
  // --- Relaciones ---
  
  // Cuenta asociada (obligatoria)
  IntColumn get cuentaId => integer().references(Cuentas, #id, onDelete: KeyAction.cascade)();
  
  // Categoría asociada (obligatoria)
  IntColumn get categoriaId => integer().references(Categorias, #id, onDelete: KeyAction.restrict)();
  
  // Persona asociada (solo si esPrestamo = true)
  IntColumn get personaId => integer().nullable().references(Personas, #id, onDelete: KeyAction.restrict)();
  
  // --- Campos para compras a crédito ---
  
  // Cantidad de cuotas (null si es débito)
  IntColumn get cantidadCuotas => integer().nullable()();
  
  // Valor de cada cuota (lo que pagas mensualmente, puede incluir interés)
  RealColumn get valorCuota => real().nullable()();
  
  // Tasa de interés mensual (%, opcional si no se conoce)
  RealColumn get tasaInteres => real().nullable()();
  
  // Tipo de interés: 'simple', 'compuesto', 'desconocido'
  TextColumn get tipoInteres => text().nullable()();
  
  // Monto total a pagar (valor_cuota * cantidad_cuotas)
  RealColumn get montoTotalConInteres => real().nullable()();
  
  // Interés total (monto_total_con_interes - monto_total)
  RealColumn get interesTotal => real().nullable()();
  
  // --- Notas y metadata ---
  
  // Notas adicionales
  TextColumn get notas => text().nullable()();
  
  // Etiquetas separadas por comas (ej: "urgente,recurrente")
  TextColumn get etiquetas => text().nullable()();
  
  // --- Campos de sincronización (para Fase 2) ---
  
  // Si está sincronizado con el servidor
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
  
  // ID en el servidor (Supabase)
  TextColumn get syncId => text().nullable()();
  
  // Timestamps
  DateTimeColumn get creadaEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadaEn => dateTime().withDefault(currentDateAndTime)();
  
  // Última vez que se modificó (para conflict resolution)
  DateTimeColumn get ultimaModificacion => dateTime().withDefault(currentDateAndTime)();
}