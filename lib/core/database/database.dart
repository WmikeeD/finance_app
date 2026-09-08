import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// Importar todas las tablas
import 'tables/cuentas.dart';
import 'tables/categorias.dart';
import 'tables/personas.dart';
import 'tables/transacciones.dart';
import 'tables/cuotas.dart';
import 'tables/perfil.dart';
import 'tables/deudas.dart';
import 'tables/pagos_deuda.dart';
import 'tables/gastos_fijos.dart';
import 'tables/sync_mappings.dart';
import 'tables/ingresos_recurrentes.dart';

// Este archivo será generado por build_runner
part 'database.g.dart';

/// Base de datos principal de la aplicación
@DriftDatabase(tables: [
  Cuentas,
  Categorias,
  Personas,
  Transacciones,
  Cuotas,
  Perfiles,
  Deudas,
  PagosDeuda,
  GastosFijos,
  SyncMappings,
  IngresosRecurrentes,
])
class AppDatabase extends _$AppDatabase {
  // Constructor
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 14;

  // Estrategia de migración
  @override
  MigrationStrategy get migration => MigrationStrategy(
        // Ejecutar antes de crear las tablas
        beforeOpen: (details) async {
          // Habilitar foreign keys (importante para las relaciones)
          await customStatement('PRAGMA foreign_keys = ON');
          
          // Si es la primera vez que se abre la base de datos
          if (details.wasCreated) {
            // Aquí puedes insertar datos iniciales (seed data)
            await _insertSeedData();
          }
        },
        
        // Migración cuando se actualiza la versión
        onUpgrade: (migrator, from, to) async {
          // Migración v1 → v2: agregar tabla Perfiles
          if (from < 2) {
            await migrator.createTable(perfiles);
          }
          
          // Migración v2 → v3: agregar campo meta a Cuentas
          if (from < 3) {
            await migrator.addColumn(cuentas, cuentas.meta);
          }

          // Migración v3 → v4: agregar tabla Deudas y PagosDeuda
          if (from < 4) {
            await migrator.createTable(deudas);
            await migrator.createTable(pagosDeuda);
          }

          // Migración v4 → v5: agregar tabla GastosFijos
          if (from < 5) {
            await migrator.createTable(gastosFijos);
          }

          // Migración v5 → v6: agregar campo temaOscuro al perfil
          if (from < 6) {
            await migrator.addColumn(perfiles, perfiles.temaOscuro);
          }

          // Migración v6 → v7: color dinámico y límites de balance
          if (from < 7) {
            await migrator.addColumn(perfiles, perfiles.colorDinamico);
            await migrator.addColumn(perfiles, perfiles.balanceMinimo);
            await migrator.addColumn(perfiles, perfiles.balanceMaximo);
          }

          // Migración v7 → v8: preferencias de notificaciones
          if (from < 8) {
            await migrator.addColumn(perfiles, perfiles.notifCuotas);
            await migrator.addColumn(perfiles, perfiles.notifDiasAntes);
            await migrator.addColumn(perfiles, perfiles.notifGastosFijos);
          }

          // Migración v8 → v9: columna transaccionId en PagosDeuda + categoría de cobro
          if (from < 9) {
            await migrator.addColumn(pagosDeuda, pagosDeuda.transaccionId);
            final existe = await (select(categorias)
                  ..where((c) =>
                      c.nombre.equals('Cobro de Préstamo') &
                      c.tipo.equals('ingreso')))
                .getSingleOrNull();
            if (existe == null) {
              await into(categorias).insert(
                CategoriasCompanion.insert(
                  nombre: 'Cobro de Préstamo',
                  tipo: 'ingreso',
                  icono: const Value('people_alt'),
                  color: const Value('#4CAF50'),
                ),
              );
            }
          }

          // Migración v9 → v10: campos de sincronización a TODAS las tablas
          if (from < 10) {
            // Categorias
            await migrator.addColumn(categorias, categorias.sincronizado);
            await migrator.addColumn(categorias, categorias.syncId);
            await migrator.addColumn(categorias, categorias.ultimaModificacion);

            // Cuentas
            await migrator.addColumn(cuentas, cuentas.sincronizado);
            await migrator.addColumn(cuentas, cuentas.syncId);
            await migrator.addColumn(cuentas, cuentas.ultimaModificacion);

            // Personas
            await migrator.addColumn(personas, personas.sincronizado);
            await migrator.addColumn(personas, personas.syncId);
            await migrator.addColumn(personas, personas.ultimaModificacion);

            // Cuotas
            await migrator.addColumn(cuotas, cuotas.sincronizado);
            await migrator.addColumn(cuotas, cuotas.syncId);
            await migrator.addColumn(cuotas, cuotas.ultimaModificacion);

            // Deudas
            await migrator.addColumn(deudas, deudas.sincronizado);
            await migrator.addColumn(deudas, deudas.syncId);
            await migrator.addColumn(deudas, deudas.ultimaModificacion);

            // PagosDeuda
            await migrator.addColumn(pagosDeuda, pagosDeuda.sincronizado);
            await migrator.addColumn(pagosDeuda, pagosDeuda.syncId);
            await migrator.addColumn(pagosDeuda, pagosDeuda.ultimaModificacion);

            // GastosFijos
            await migrator.addColumn(gastosFijos, gastosFijos.sincronizado);
            await migrator.addColumn(gastosFijos, gastosFijos.syncId);
            await migrator.addColumn(gastosFijos, gastosFijos.ultimaModificacion);

            // Perfiles
            await migrator.addColumn(perfiles, perfiles.sincronizado);
            await migrator.addColumn(perfiles, perfiles.syncId);
            await migrator.addColumn(perfiles, perfiles.ultimaModificacion);

            // Crear tabla SyncMappings
            await migrator.createTable(syncMappings);
          }

          // Migración v10 → v11: soft delete en tablas críticas
          if (from < 11) {
            await migrator.addColumn(transacciones, transacciones.deletedAt);
            await migrator.addColumn(cuotas, cuotas.deletedAt);
            await migrator.addColumn(deudas, deudas.deletedAt);
            await migrator.addColumn(pagosDeuda, pagosDeuda.deletedAt);
          }

          // Migración v11 → v12: campo userId para multi-tenant
          if (from < 12) {
            // Añadir userId a todas las tablas
            await migrator.addColumn(categorias, categorias.userId);
            await migrator.addColumn(cuentas, cuentas.userId);
            await migrator.addColumn(personas, personas.userId);
            await migrator.addColumn(transacciones, transacciones.userId);
            await migrator.addColumn(cuotas, cuotas.userId);
            await migrator.addColumn(deudas, deudas.userId);
            await migrator.addColumn(pagosDeuda, pagosDeuda.userId);
            await migrator.addColumn(gastosFijos, gastosFijos.userId);
            await migrator.addColumn(perfiles, perfiles.userId);

            // Nota: Los valores quedan NULL por ahora. En una futura migración,
            // cuando se implemente autenticación, se llenará con el UUID del usuario.
          }

          // Migración v12 → v13: campos para transferencias entre cuentas
          if (from < 13) {
            await migrator.addColumn(transacciones, transacciones.cuentaDestinoId);
            await migrator.addColumn(transacciones, transacciones.transferenciaId);

            // Crear categoría por defecto para transferencias
            final existeTransferencia = await (select(categorias)
                  ..where((c) =>
                      c.nombre.equals('Transferencia') &
                      c.tipo.equals('ingreso')))
                .getSingleOrNull();
            if (existeTransferencia == null) {
              await into(categorias).insert(
                CategoriasCompanion.insert(
                  nombre: 'Transferencia',
                  tipo: 'ingreso',
                  icono: const Value('swap_horiz'),
                  color: const Value('#2196F3'),
                ),
              );
            }
          }

          // Migración v13 → v14: tabla de ingresos recurrentes
          if (from < 14) {
            await migrator.createTable(ingresosRecurrentes);
          }
        },
      );

  /// Insertar datos iniciales cuando se crea la base de datos
  Future<void> _insertSeedData() async {
    // Categorías de EGRESOS por defecto
    final categoriasEgreso = [
      CategoriasCompanion.insert(
        nombre: 'Alimentación',
        tipo: 'egreso',
        icono: const Value('restaurant'),
        color: const Value('#FF5722'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Transporte',
        tipo: 'egreso',
        icono: const Value('directions_car'),
        color: const Value('#2196F3'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Vivienda',
        tipo: 'egreso',
        icono: const Value('home'),
        color: const Value('#4CAF50'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Salud',
        tipo: 'egreso',
        icono: const Value('medical_services'),
        color: const Value('#F44336'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Entretenimiento',
        tipo: 'egreso',
        icono: const Value('sports_esports'),
        color: const Value('#9C27B0'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Educación',
        tipo: 'egreso',
        icono: const Value('school'),
        color: const Value('#FF9800'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Servicios',
        tipo: 'egreso',
        icono: const Value('receipt'),
        color: const Value('#607D8B'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Préstamos',
        tipo: 'egreso',
        icono: const Value('people'),
        color: const Value('#795548'),
      ),
    ];

    for (final categoria in categoriasEgreso) {
      await into(categorias).insert(categoria);
    }

    // Categorías de INGRESOS por defecto
    final categoriasIngreso = [
      CategoriasCompanion.insert(
        nombre: 'Salario',
        tipo: 'ingreso',
        icono: const Value('attach_money'),
        color: const Value('#4CAF50'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Freelance',
        tipo: 'ingreso',
        icono: const Value('work'),
        color: const Value('#2196F3'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Inversiones',
        tipo: 'ingreso',
        icono: const Value('trending_up'),
        color: const Value('#FF9800'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Otros ingresos',
        tipo: 'ingreso',
        icono: const Value('account_balance_wallet'),
        color: const Value('#9C27B0'),
      ),
      CategoriasCompanion.insert(
        nombre: 'Cobro de Préstamo',
        tipo: 'ingreso',
        icono: const Value('people_alt'),
        color: const Value('#4CAF50'),
      ),
    ];

    for (final categoria in categoriasIngreso) {
      await into(categorias).insert(categoria);
    }

    // Cuenta por defecto
    await into(cuentas).insert(
      CuentasCompanion.insert(
        nombre: 'Efectivo',
        tipo: 'efectivo',
        saldo: const Value(0.0),
        icono: const Value('payments'),
        color: const Value('#4CAF50'),
      ),
    );

    // Perfil por defecto
    await into(perfiles).insert(
      PerfilesCompanion.insert(
        id: const Value(1),
      ),
    );
  }

  // =============================================
  // MÉTODOS DE PERFIL
  // =============================================

  /// Obtener el perfil del usuario (siempre id = 1)
  Future<Perfil?> obtenerPerfil() async {
    return await (select(perfiles)..where((p) => p.id.equals(1)))
        .getSingleOrNull();
  }

  /// Guardar/actualizar el perfil
  Future<void> guardarPerfil(PerfilesCompanion perfil) async {
    final existe = await obtenerPerfil();
    if (existe == null) {
      await into(perfiles).insert(perfil.copyWith(id: const Value(1)));
    } else {
      await (update(perfiles)..where((p) => p.id.equals(1))).write(perfil);
    }
  }

  // =============================================
  // MÉTODOS DE GASTOS FIJOS
  // =============================================

  Stream<List<Transaccion>> watchTransaccionesPaginadas(int limite) {
    return (select(transacciones)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.fecha)])
          ..limit(limite))
        .watch();
  }

  Stream<List<GastoFijo>> watchGastosFijos({bool? soloActivos}) {
    final query = select(gastosFijos)
      ..where((g) => g.deletedAt.isNull())
      ..orderBy([(g) => OrderingTerm.asc(g.diaVencimiento)]);
    if (soloActivos == true) {
      query.where((g) => g.activo.equals(true));
    }
    return query.watch();
  }

  Future<void> insertarGastoFijo(GastosFijosCompanion gasto) async {
    await into(gastosFijos).insert(gasto);
  }

  Future<void> actualizarGastoFijo(GastosFijosCompanion gasto) async {
    await (update(gastosFijos)..where((g) => g.id.equals(gasto.id.value)))
        .write(gasto);
  }

  Future<void> eliminarGastoFijo(int id) async {
    // Soft-delete: marcar como eliminado en lugar de borrar
    await (update(gastosFijos)..where((g) => g.id.equals(id))).write(
      GastosFijosCompanion(
        deletedAt: Value(DateTime.now()),
        sincronizado: const Value(false),
        ultimaModificacion: Value(DateTime.now()),
      ),
    );
  }

  Future<double> totalGastosFijosActivos() async {
    final activos = await (select(gastosFijos)
          ..where((g) => g.activo.equals(true) & g.deletedAt.isNull()))
        .get();
    return activos.fold<double>(0.0, (sum, g) => sum + g.monto);
  }

  // =============================================
  // RECÁLCULO DE SALDOS
  // =============================================

  /// Recalcular el saldo real de una cuenta basado en transacciones activas
  ///
  /// Lógica diferenciada por tipo de cuenta:
  /// - Efectivo/Débito: saldo = SUM(ingresos) - SUM(egresos efectivo/débito) + SUM(transferencias entrantes) - SUM(transferencias salientes)
  /// - Crédito: saldo = - SUM(egresos a crédito) + SUM(ingresos/pagos) + SUM(transferencias entrantes)
  /// Solo considera transacciones activas (deletedAt IS NULL)
  Future<void> recalcularSaldoCuenta(int cuentaId) async {
    try {
      final cuenta = await (select(cuentas)
            ..where((c) => c.id.equals(cuentaId)))
          .getSingle();

      // Obtener transacciones donde esta cuenta es origen (cuentaId)
      final transaccionesOrigen = await (select(transacciones)
            ..where((t) =>
                t.cuentaId.equals(cuentaId) & t.deletedAt.isNull()))
          .get();

      // Obtener transferencias donde esta cuenta es destino (cuentaDestinoId)
      final transferenciasEntrantes = await (select(transacciones)
            ..where((t) =>
                t.cuentaDestinoId.equals(cuentaId) &
                t.tipo.equals('transferencia') &
                t.deletedAt.isNull()))
          .get();

      double saldoCalculado = 0.0;

      if (cuenta.tipo == 'credito') {
        // CUENTAS DE CRÉDITO: saldo = - SUM(egresos a crédito) + SUM(ingresos/pagos) + SUM(transferencias entrantes)
        // Ej: compra $300.000 → saldo = -300.000 (deuda)
        //     pago $100.000   → saldo = -200.000 (deuda restante)
        //     transferencia entrante $250.000 → saldo = +50.000 (saldo a favor)
        for (final tx in transaccionesOrigen) {
          if (tx.tipo == 'transferencia') {
            // Transferencias salientes desde tarjeta de crédito (casos raros, pero posibles)
            saldoCalculado -= tx.montoTotal;
          } else if (tx.tipo == 'ingreso') {
            // Ingresos = pagos/abonos a la tarjeta (reducen deuda)
            saldoCalculado += tx.montoTotal;
          } else if (tx.tipo == 'egreso' && tx.formaPago == 'credito') {
            // Egresos a crédito = compras con esta tarjeta (aumentan deuda)
            saldoCalculado -= tx.montoTotal;
          }
        }

        // Sumar transferencias entrantes (pagos desde otras cuentas)
        for (final tx in transferenciasEntrantes) {
          saldoCalculado += tx.montoTotal;
        }
      } else {
        // CUENTAS DE EFECTIVO/DÉBITO: saldo = SUM(ingresos) - SUM(egresos efectivo/débito) + SUM(transferencias entrantes) - SUM(transferencias salientes)
        for (final tx in transaccionesOrigen) {
          if (tx.tipo == 'transferencia') {
            // Transferencia saliente (dinero que sale de esta cuenta)
            saldoCalculado -= tx.montoTotal;
          } else if (tx.formaPago == 'credito') {
            // Las transacciones a crédito no afectan saldos de cuentas efectivo/débito
            continue;
          } else if (tx.tipo == 'ingreso') {
            saldoCalculado += tx.montoTotal;
          } else if (tx.tipo == 'egreso') {
            saldoCalculado -= tx.montoTotal;
          }
        }

        // Sumar transferencias entrantes (dinero que entra a esta cuenta)
        for (final tx in transferenciasEntrantes) {
          saldoCalculado += tx.montoTotal;
        }
      }

      // Actualizar el saldo de la cuenta
      await (update(cuentas)..where((c) => c.id.equals(cuentaId)))
          .write(CuentasCompanion(
        saldo: Value(saldoCalculado),
      ));

      debugPrint('Saldo recalculado para cuenta "${cuenta.nombre}" (${cuenta.tipo}): \$${saldoCalculado.toStringAsFixed(2)}');
    } catch (e, stack) {
      debugPrint('Error al recalcular saldo de cuenta $cuentaId: $e\n$stack');
    }
  }

  /// Recalcular saldos de todas las cuentas activas
  Future<void> recalcularTodosSaldos() async {
    try {
      final todasCuentas = await (select(cuentas)
            ..where((c) => c.activa.equals(true)))
          .get();

      for (final cuenta in todasCuentas) {
        await recalcularSaldoCuenta(cuenta.id);
      }

      debugPrint('Saldos recalculados para ${todasCuentas.length} cuentas');
    } catch (e, stack) {
      debugPrint('Error al recalcular todos los saldos: $e\n$stack');
    }
  }

  /// Sincroniza el saldo de todas las tarjetas de crédito basándose en cuotas pendientes.
  ///
  /// Este método corrige discrepancias entre `cuentas.saldo` y la deuda real calculada
  /// desde cuotas NO pagadas. Debe ejecutarse cuando:
  /// - Se detecta inconsistencia entre modal y reportes
  /// - Después de eliminar transacciones masivamente
  /// - En migraciones de datos
  Future<void> sincronizarSaldosTarjetasCredito() async {
    try {
      final tarjetas = await (select(cuentas)
            ..where((c) => c.tipo.equals('credito') & c.activa.equals(true)))
          .get();

      int corregidas = 0;

      for (final tarjeta in tarjetas) {
        // Calcular deuda real desde cuotas
        final deudaReal = await calcularDeudaRealTarjeta(tarjeta.id);

        // El saldo de una tarjeta debe ser negativo si hay deuda
        final saldoEsperado = -deudaReal;

        // Verificar si hay discrepancia
        final discrepancia = (tarjeta.saldo - saldoEsperado).abs();

        if (discrepancia > 0.01) {
          // Actualizar saldo directamente
          await (update(cuentas)..where((c) => c.id.equals(tarjeta.id)))
              .write(CuentasCompanion(
            saldo: Value(saldoEsperado),
          ));

          debugPrint(
              '✅ Sincronizado "${tarjeta.nombre}": \$${tarjeta.saldo.toStringAsFixed(0)} → \$${saldoEsperado.toStringAsFixed(0)} (diff: \$${discrepancia.toStringAsFixed(0)})');
          corregidas++;
        } else {
          debugPrint('✓ "${tarjeta.nombre}": saldo correcto (\$${tarjeta.saldo.toStringAsFixed(0)})');
        }
      }

      if (corregidas > 0) {
        debugPrint('🔧 Sincronización completada: $corregidas de ${tarjetas.length} tarjetas corregidas');
      } else {
        debugPrint('✅ Todas las tarjetas (${tarjetas.length}) tienen saldo correcto');
      }
    } catch (e, stack) {
      debugPrint('Error al sincronizar saldos de tarjetas: $e\n$stack');
    }
  }

  // =============================================
  // MÉTODOS DE COBRO DE DEUDAS
  // =============================================

  /// Vincula un pago a una deuda existente. Debe llamarse DENTRO de un bloque
  /// transaction() del caller — no abre su propia transacción.
  /// Crea el registro PagosDeuda, actualiza montoPendiente/estado de la Deuda
  /// y marca cuotas pagadas si corresponde.
  Future<void> vincularPagoConDeuda({
    required int deudaId,
    required int transaccionId,
    required double monto,
    String? notas,
  }) async {
    await into(pagosDeuda).insert(
      PagosDeudaCompanion.insert(
        deudaId: deudaId,
        monto: monto,
        transaccionId: Value(transaccionId),
        notas: Value(notas),
      ),
    );

    final deuda =
        await (select(deudas)..where((d) => d.id.equals(deudaId))).getSingle();
    final nuevoPendiente =
        (deuda.montoPendiente - monto).clamp(0.0, double.infinity);
    final nuevoPagado = deuda.montoPagado + monto;
    final nuevoEstado = nuevoPendiente <= 0 ? 'pagada' : 'parcial';

    await (update(deudas)..where((d) => d.id.equals(deudaId))).write(
      DeudasCompanion(
        montoPendiente: Value(nuevoPendiente),
        montoPagado: Value(nuevoPagado),
        estado: Value(nuevoEstado),
        actualizadaEn: Value(DateTime.now()),
      ),
    );

    if (deuda.tipo == 'cuotas') {
      final pendientes = await (select(cuotas)
            ..where((c) =>
                c.transaccionId.equals(deuda.transaccionId) &
                c.pagada.equals(false))
            ..orderBy([(c) => OrderingTerm(expression: c.numeroCuota)]))
          .get();

      double restante = monto;
      for (final cuota in pendientes) {
        if (restante <= 0) break;
        if (restante >= cuota.monto) {
          await (update(cuotas)..where((c) => c.id.equals(cuota.id))).write(
            CuotasCompanion(
              pagada: const Value(true),
              fechaPago: Value(DateTime.now()),
            ),
          );
          restante -= cuota.monto;
        }
      }
    }
  }

  /// Registra el cobro de una deuda desde PersonasScreen:
  /// crea la transacción de ingreso, actualiza el saldo de la cuenta
  /// y llama a [vincularPagoConDeuda] todo en una transacción atómica.
  Future<void> registrarPagoDeuda({
    required int deudaId,
    required int cuentaId,
    required double monto,
    required String descripcion,
    required int personaId,
    required int categoriaCobroId,
    String? notas,
  }) async {
    await transaction(() async {
      final txId = await into(transacciones).insert(
        TransaccionesCompanion.insert(
          tipo: 'ingreso',
          descripcion: descripcion,
          montoTotal: monto,
          formaPago: 'debito',
          fecha: DateTime.now(),
          cuentaId: cuentaId,
          categoriaId: categoriaCobroId,
          esPrestamo: const Value(false),
          personaId: Value(personaId),
        ),
      );

      final cuenta =
          await (select(cuentas)..where((c) => c.id.equals(cuentaId)))
              .getSingle();
      await update(cuentas).replace(cuenta.copyWith(saldo: cuenta.saldo + monto));

      await vincularPagoConDeuda(
        deudaId: deudaId,
        transaccionId: txId,
        monto: monto,
        notas: notas,
      );
    });
  }

  // =============================================
  // AMORTIZACIÓN DE CUOTAS PARA TRANSFERENCIAS
  // =============================================

  /// Amortiza cuotas de una cuenta de crédito al recibir un abono/transferencia.
  ///
  /// Busca todas las cuotas pendientes de transacciones asociadas a la cuenta de crédito,
  /// las ordena por fecha de vencimiento (más antiguas primero) y las marca como pagadas
  /// según el monto disponible.
  ///
  /// Este método debe llamarse DENTRO de un bloque transaction() del caller.
  Future<void> amortizarCuotasPorAbono(int cuentaCreditoId, double montoAbonado) async {
    // Buscar todas las cuotas pendientes de esta cuenta de crédito
    // JOIN con transacciones para filtrar por cuentaId
    final cuotasPendientes = await (select(cuotas).join([
      innerJoin(transacciones, transacciones.id.equalsExp(cuotas.transaccionId))
    ])
          ..where(transacciones.cuentaId.equals(cuentaCreditoId) &
              cuotas.pagada.equals(false) &
              transacciones.deletedAt.isNull() &
              cuotas.deletedAt.isNull())
          ..orderBy([OrderingTerm.asc(cuotas.fechaVencimiento)]))
        .get();

    double restante = montoAbonado;

    for (final row in cuotasPendientes) {
      if (restante <= 0) break;

      final cuota = row.readTable(cuotas);

      if (restante >= cuota.monto) {
        // Monto suficiente para cubrir la cuota completa
        await (update(cuotas)..where((c) => c.id.equals(cuota.id))).write(
          CuotasCompanion(
            pagada: const Value(true),
            fechaPago: Value(DateTime.now()),
            sincronizado: const Value(false),
            ultimaModificacion: Value(DateTime.now()),
          ),
        );
        restante -= cuota.monto;

        debugPrint('✅ Cuota ${cuota.numeroCuota} amortizada: \$${cuota.monto.toStringAsFixed(2)} | Restante: \$${restante.toStringAsFixed(2)}');
      } else {
        // Monto insuficiente para cubrir la cuota completa, detener amortización
        debugPrint('⚠️ Monto restante (\$${restante.toStringAsFixed(2)}) insuficiente para cuota ${cuota.numeroCuota} (\$${cuota.monto.toStringAsFixed(2)})');
        break;
      }
    }

    if (cuotasPendientes.isEmpty) {
      debugPrint('ℹ️ No hay cuotas pendientes para amortizar en cuenta $cuentaCreditoId');
    }
  }

  /// Revierte la amortización de cuotas al eliminar (soft-delete) una transferencia.
  ///
  /// Busca las cuotas que fueron pagadas después de una fecha específica y las revierte
  /// a estado pendiente.
  ///
  /// Este método debe llamarse DENTRO de un bloque transaction() del caller.
  Future<void> revertirAmortizacionCuotas(int cuentaCreditoId, DateTime fechaTransferencia) async {
    // Buscar cuotas que fueron pagadas en/después de la fecha de la transferencia
    final cuotasPagadas = await (select(cuotas).join([
      innerJoin(transacciones, transacciones.id.equalsExp(cuotas.transaccionId))
    ])
          ..where(transacciones.cuentaId.equals(cuentaCreditoId) &
              cuotas.pagada.equals(true) &
              cuotas.fechaPago.isBiggerOrEqualValue(fechaTransferencia) &
              transacciones.deletedAt.isNull() &
              cuotas.deletedAt.isNull())
          ..orderBy([OrderingTerm.desc(cuotas.fechaVencimiento)]))
        .get();

    for (final row in cuotasPagadas) {
      final cuota = row.readTable(cuotas);

      await (update(cuotas)..where((c) => c.id.equals(cuota.id))).write(
        CuotasCompanion(
          pagada: const Value(false),
          fechaPago: const Value(null),
          sincronizado: const Value(false),
          ultimaModificacion: Value(DateTime.now()),
        ),
      );

      debugPrint('↩️ Cuota ${cuota.numeroCuota} revertida a pendiente');
    }
  }

  /// Calcula la deuda real de una tarjeta de crédito basándose en cuotas pendientes.
  ///
  /// A diferencia de `cuentas.saldo` (que se basa en transacciones), este método
  /// suma únicamente las cuotas NO pagadas de transacciones activas, reflejando
  /// la deuda exigible real.
  ///
  /// Retorna:
  /// - Monto positivo = deuda pendiente
  /// - 0.0 = sin deuda
  Future<double> calcularDeudaRealTarjeta(int cuentaCreditoId) async {
    try {
      // Verificar que sea una cuenta de crédito
      final cuenta = await (select(cuentas)
            ..where((c) => c.id.equals(cuentaCreditoId)))
          .getSingleOrNull();

      if (cuenta == null || cuenta.tipo != 'credito') {
        debugPrint('⚠️ calcularDeudaRealTarjeta: cuenta $cuentaCreditoId no es de crédito');
        return 0.0;
      }

      // Obtener todas las cuotas pendientes (no pagadas) de transacciones activas
      final cuotasPendientes = await (select(cuotas).join([
        innerJoin(transacciones, transacciones.id.equalsExp(cuotas.transaccionId))
      ])
            ..where(transacciones.cuentaId.equals(cuentaCreditoId) &
                cuotas.pagada.equals(false) &
                cuotas.deletedAt.isNull() &
                transacciones.deletedAt.isNull()))
          .get();

      // Sumar el monto de todas las cuotas pendientes
      final deudaTotal = cuotasPendientes.fold<double>(0.0, (sum, row) {
        final cuota = row.readTable(cuotas);
        return sum + cuota.monto;
      });

      debugPrint('💳 Deuda real de "${cuenta.nombre}": \$${deudaTotal.toStringAsFixed(2)} (${cuotasPendientes.length} cuotas pendientes)');
      return deudaTotal;
    } catch (e, stack) {
      debugPrint('Error al calcular deuda real de tarjeta $cuentaCreditoId: $e\n$stack');
      return 0.0;
    }
  }

  /// Elimina (soft-delete) una transacción y revierte cuotas si es transferencia a crédito.
  ///
  /// Si la transacción es una transferencia hacia una cuenta de crédito,
  /// revierte las cuotas amortizadas antes de marcarla como eliminada.
  Future<void> eliminarTransaccion(int transaccionId) async {
    await transaction(() async {
      // Obtener la transacción
      final tx = await (select(transacciones)
            ..where((t) => t.id.equals(transaccionId)))
          .getSingle();

      // Si es transferencia a tarjeta de crédito, revertir cuotas
      if (tx.tipo == 'transferencia' && tx.cuentaDestinoId != null) {
        final cuentaDestino = await (select(cuentas)
              ..where((c) => c.id.equals(tx.cuentaDestinoId!)))
            .getSingleOrNull();

        if (cuentaDestino?.tipo == 'credito') {
          await revertirAmortizacionCuotas(
            cuentaDestino!.id,
            tx.fecha,
          );
        }
      }

      // Soft-delete: marcar cuotas asociadas como eliminadas (si las tiene)
      if (tx.formaPago == 'credito' || tx.cantidadCuotas != null) {
        await (update(cuotas)..where((c) => c.transaccionId.equals(transaccionId)))
            .write(CuotasCompanion(
          deletedAt: Value(DateTime.now()),
          sincronizado: const Value(false),
          ultimaModificacion: Value(DateTime.now()),
        ));
      }

      // Marcar transacción como eliminada
      await (update(transacciones)..where((t) => t.id.equals(transaccionId)))
          .write(TransaccionesCompanion(
        deletedAt: Value(DateTime.now()),
        sincronizado: const Value(false),
        ultimaModificacion: Value(DateTime.now()),
      ));

      // Recalcular saldos de las cuentas afectadas
      await recalcularSaldoCuenta(tx.cuentaId);
      if (tx.cuentaDestinoId != null) {
        await recalcularSaldoCuenta(tx.cuentaDestinoId!);
      }

      debugPrint('🗑️ Transacción $transaccionId eliminada (soft-delete)');
    });
  }
}

/// Abre la conexión a la base de datos SQLite
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Obtener el directorio de documentos de la app
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'finance_app.db'));
    
    return NativeDatabase.createInBackground(file);
  });
}