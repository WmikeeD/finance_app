import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';

/// Estados de sincronización
enum SyncStatus {
  idle,
  syncing,
  error,
  offline,
}

/// Resultado de una operación de sincronización
class SyncResult {
  final bool success;
  final String? errorMessage;
  final int recordsPushed;
  final int recordsPulled;
  final DateTime? timestamp;

  SyncResult({
    required this.success,
    this.errorMessage,
    this.recordsPushed = 0,
    this.recordsPulled = 0,
    this.timestamp,
  });

  @override
  String toString() =>
      'SyncResult(success: $success, pushed: $recordsPushed, pulled: $recordsPulled, error: $errorMessage)';
}

/// Servicio de Sincronización Bidireccional Offline-First
///
/// Sincroniza datos entre Drift (SQLite local) y Supabase (PostgreSQL remoto).
/// Arquitectura: Las operaciones locales siempre van primero a Drift,
/// la sincronización se ejecuta en background o on-demand.
class SyncService {
  final AppDatabase _database;
  final SupabaseClient _supabase;

  // Estado de sincronización reactivo
  final ValueNotifier<SyncStatus> _status =
      ValueNotifier<SyncStatus>(SyncStatus.idle);
  ValueNotifier<SyncStatus> get status => _status;

  // Clave para SharedPreferences
  static const String _lastSyncKey = 'last_sync_timestamp';

  SyncService({
    required AppDatabase database,
    SupabaseClient? supabase,
  })  : _database = database,
        _supabase = supabase ?? Supabase.instance.client;

  /// ID del usuario autenticado actual
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Verificar si hay conexión a internet (simplificado)
  Future<bool> _hasInternetConnection() async {
    try {
      // Intenta hacer un ping simple a Supabase
      await _supabase.from('perfiles').select('id').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Obtener timestamp de última sincronización exitosa
  Future<DateTime?> getLastSyncTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getString(_lastSyncKey);
      return timestamp != null ? DateTime.parse(timestamp) : null;
    } catch (e) {
      debugPrint('Error al obtener última sincronización: $e');
      return null;
    }
  }

  /// Guardar timestamp de última sincronización
  Future<void> _saveLastSyncTimestamp(DateTime timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, timestamp.toIso8601String());
    } catch (e) {
      debugPrint('Error al guardar timestamp de sincronización: $e');
    }
  }

  /// Sincronización completa: Push → Pull
  ///
  /// Primero sube cambios locales al servidor (push),
  /// luego descarga cambios remotos (pull).
  ///
  /// Si [forceFullSync] es true, ignora el lastSyncTimestamp y descarga
  /// todo el histórico desde Supabase (útil para primera sincronización
  /// o cuando la DB local está vacía).
  Future<SyncResult> syncAll({bool forceFullSync = false}) async {
    if (_currentUserId == null) {
      return SyncResult(
        success: false,
        errorMessage: 'Usuario no autenticado',
      );
    }

    // Verificar conexión
    if (!await _hasInternetConnection()) {
      _status.value = SyncStatus.offline;
      return SyncResult(
        success: false,
        errorMessage: 'Sin conexión a internet',
      );
    }

    _status.value = SyncStatus.syncing;

    try {
      if (forceFullSync) {
        debugPrint('🔄 SYNC COMPLETO FORZADO - Ignorando lastSyncTimestamp');
      }

      // 1. Push: Subir cambios locales
      final pushResult = await pushChanges();
      if (!pushResult.success) {
        _status.value = SyncStatus.error;
        return pushResult;
      }

      // 2. Pull: Descargar cambios remotos (forzar full sync si se solicita)
      final pullResult = await pullChanges(forceFullSync: forceFullSync);
      if (!pullResult.success) {
        _status.value = SyncStatus.error;
        return pullResult;
      }

      // 3. Limpieza automática de duplicados
      await limpiarCuentasDuplicadas();
      await limpiarCategoriasDuplicadas();

      // 4. Recalcular saldos de todas las cuentas
      await _recalcularTodosSaldos();

      // Guardar timestamp de sincronización exitosa
      final now = DateTime.now();
      await _saveLastSyncTimestamp(now);

      _status.value = SyncStatus.idle;

      return SyncResult(
        success: true,
        recordsPushed: pushResult.recordsPushed,
        recordsPulled: pullResult.recordsPulled,
        timestamp: now,
      );
    } catch (e, stack) {
      debugPrint('Error en syncAll: $e\n$stack');
      _status.value = SyncStatus.error;
      return SyncResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Push: Subir cambios locales no sincronizados a Supabase
  ///
  /// Respeta el orden de dependencias:
  /// 1. Cuentas, Categorías, Personas, Perfil
  /// 2. Gastos Fijos, Transacciones
  /// 3. Cuotas, Deudas
  /// 4. Pagos Deuda
  Future<SyncResult> pushChanges() async {
    if (_currentUserId == null) {
      return SyncResult(
        success: false,
        errorMessage: 'Usuario no autenticado',
      );
    }

    int totalPushed = 0;

    try {
      // Orden estricto de dependencias (base → dependientes)
      totalPushed += await _pushCuentas();
      totalPushed += await _pushCategorias();
      totalPushed += await _pushPersonas();
      totalPushed += await _pushPerfil();
      totalPushed += await _pushGastosFijos();
      totalPushed += await _pushTransacciones();
      totalPushed += await _pushCuotas();
      totalPushed += await _pushDeudas();
      totalPushed += await _pushPagosDeuda();

      return SyncResult(
        success: true,
        recordsPushed: totalPushed,
      );
    } catch (e, stack) {
      debugPrint('Error en pushChanges: $e\n$stack');
      return SyncResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Pull: Descargar cambios remotos desde Supabase
  ///
  /// Descarga registros del usuario modificados desde la última sincronización.
  /// Respeta el mismo orden de dependencias que push.
  Future<SyncResult> pullChanges({bool forceFullSync = false}) async {
    if (_currentUserId == null) {
      return SyncResult(
        success: false,
        errorMessage: 'Usuario no autenticado',
      );
    }

    int totalPulled = 0;
    final lastSync = forceFullSync ? null : await getLastSyncTimestamp();

    if (forceFullSync) {
      debugPrint('🔄 Pull completo forzado - lastSync tratado como NULL');
    }

    try {
      // Orden estricto (base → dependientes)
      totalPulled += await _pullCuentas(lastSync);
      totalPulled += await _pullCategorias(lastSync);
      totalPulled += await _pullPersonas(lastSync);
      totalPulled += await _pullPerfil(lastSync);
      totalPulled += await _pullGastosFijos(lastSync);
      totalPulled += await _pullTransacciones(lastSync);
      totalPulled += await _pullCuotas(lastSync);
      totalPulled += await _pullDeudas(lastSync);
      totalPulled += await _pullPagosDeuda(lastSync);

      return SyncResult(
        success: true,
        recordsPulled: totalPulled,
      );
    } catch (e, stack) {
      debugPrint('Error en pullChanges: $e\n$stack');
      return SyncResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUSH: Métodos específicos por tabla
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> _pushCuentas() async {
    final pendientes = await (_database.select(_database.cuentas)
          ..where((c) => c.sincronizado.equals(false) | c.syncId.isNull()))
        .get();

    int pushed = 0;

    for (final cuenta in pendientes) {
      try {
        // PREVENCIÓN DE DUPLICADOS: Si la cuenta NO tiene syncId (ej: seed local),
        // verificar si ya existe en Supabase antes de hacer upsert
        if (cuenta.syncId == null) {
          final existentes = await _supabase
              .from('cuentas')
              .select('id')
              .eq('user_id', _currentUserId!)
              .eq('nombre', cuenta.nombre)
              .eq('tipo', cuenta.tipo)
              .eq('activa', true);

          if (existentes.isNotEmpty) {
            // Ya existe en Supabase: vincular sin insertar nueva
            final remoteId = existentes.first['id'] as String;

            debugPrint('✅ Cuenta "${cuenta.nombre}" (${cuenta.tipo}) ya existe en Supabase con id=$remoteId. Vinculando sin duplicar.');

            // Actualizar syncId local
            await (_database.update(_database.cuentas)
                  ..where((c) => c.id.equals(cuenta.id)))
                .write(CuentasCompanion(
              syncId: Value(remoteId),
              sincronizado: const Value(true),
              ultimaModificacion: Value(DateTime.now()),
            ));

            // Crear mapping
            await _database.into(_database.syncMappings).insertOnConflictUpdate(
                  SyncMappingsCompanion.insert(
                    tabla: 'cuentas',
                    localId: cuenta.id,
                    supabaseId: remoteId,
                    syncedAt: Value(DateTime.now()),
                  ),
                );

            pushed++;
            continue; // No hacer upsert, ya existe
          }
        }

        // Preparar datos para Supabase
        final data = {
          'user_id': _currentUserId,
          'nombre': cuenta.nombre,
          'tipo': cuenta.tipo,
          'saldo': cuenta.saldo,
          'limite_credito': cuenta.limiteCredito,
          'dia_cierre': cuenta.diaCierre,
          'dia_pago': cuenta.diaPago,
          'meta': cuenta.meta,
          'color': cuenta.color,
          'icono': cuenta.icono,
          'activa': cuenta.activa,
          'created_at': cuenta.creadaEn.toIso8601String(),
          'updated_at': cuenta.actualizadaEn.toIso8601String(),
        };

        // Si tiene syncId, actualizar; si no, insertar
        if (cuenta.syncId != null) {
          data['id'] = cuenta.syncId;
        }

        final response = await _supabase
            .from('cuentas')
            .upsert(data, onConflict: 'id')
            .select()
            .single();

        final supabaseId = response['id'] as String;

        // Actualizar registro local con syncId y marcar como sincronizado
        await (_database.update(_database.cuentas)
              ..where((c) => c.id.equals(cuenta.id)))
            .write(CuentasCompanion(
          syncId: Value(supabaseId),
          sincronizado: const Value(true),
          ultimaModificacion: Value(DateTime.now()),
        ));

        // Crear/actualizar mapeo en SyncMappings
        await _database.into(_database.syncMappings).insertOnConflictUpdate(
              SyncMappingsCompanion.insert(
                tabla: 'cuentas',
                localId: cuenta.id,
                supabaseId: supabaseId,
                syncedAt: Value(DateTime.now()),
              ),
            );

        pushed++;
      } catch (e) {
        debugPrint('Error al sincronizar cuenta ${cuenta.id}: $e');
      }
    }

    return pushed;
  }

  Future<int> _pushCategorias() async {
    final pendientes = await (_database.select(_database.categorias)
          ..where((c) => c.sincronizado.equals(false) | c.syncId.isNull()))
        .get();

    int pushed = 0;

    for (final categoria in pendientes) {
      try {
        // PREVENCIÓN DE DUPLICADOS: Si la categoría NO tiene syncId (ej: seed local),
        // verificar si ya existe en Supabase antes de hacer upsert
        if (categoria.syncId == null) {
          final existentes = await _supabase
              .from('categorias')
              .select('id')
              .eq('user_id', _currentUserId!)
              .eq('nombre', categoria.nombre)
              .eq('tipo', categoria.tipo)
              .eq('activa', true);

          if (existentes.isNotEmpty) {
            // Ya existe en Supabase: vincular sin insertar nueva
            final remoteId = existentes.first['id'] as String;

            debugPrint('✅ Categoría "${categoria.nombre}" (${categoria.tipo}) ya existe en Supabase con id=$remoteId. Vinculando sin duplicar.');

            // Actualizar syncId local
            await (_database.update(_database.categorias)
                  ..where((c) => c.id.equals(categoria.id)))
                .write(CategoriasCompanion(
              syncId: Value(remoteId),
              sincronizado: const Value(true),
              ultimaModificacion: Value(DateTime.now()),
            ));

            // Crear mapping
            await _database.into(_database.syncMappings).insertOnConflictUpdate(
                  SyncMappingsCompanion.insert(
                    tabla: 'categorias',
                    localId: categoria.id,
                    supabaseId: remoteId,
                    syncedAt: Value(DateTime.now()),
                  ),
                );

            pushed++;
            continue; // No hacer upsert, ya existe
          }
        }

        // Mapear categoriaPadreId si existe
        String? parentSyncId;
        if (categoria.categoriaPadreId != null) {
          parentSyncId = await _getSupabaseId('categorias', categoria.categoriaPadreId!);
        }

        final data = {
          'user_id': _currentUserId,
          'nombre': categoria.nombre,
          'tipo': categoria.tipo,
          'categoria_padre_id': parentSyncId,
          'color': categoria.color,
          'icono': categoria.icono,
          'orden': categoria.orden,
          'activa': categoria.activa,
          'created_at': categoria.creadaEn.toIso8601String(),
          'updated_at': categoria.actualizadaEn.toIso8601String(),
        };

        if (categoria.syncId != null) {
          data['id'] = categoria.syncId;
        }

        final response = await _supabase
            .from('categorias')
            .upsert(data, onConflict: 'id')
            .select()
            .single();

        final supabaseId = response['id'] as String;

        await (_database.update(_database.categorias)
              ..where((c) => c.id.equals(categoria.id)))
            .write(CategoriasCompanion(
          syncId: Value(supabaseId),
          sincronizado: const Value(true),
          ultimaModificacion: Value(DateTime.now()),
        ));

        await _database.into(_database.syncMappings).insertOnConflictUpdate(
              SyncMappingsCompanion.insert(
                tabla: 'categorias',
                localId: categoria.id,
                supabaseId: supabaseId,
                syncedAt: Value(DateTime.now()),
              ),
            );

        pushed++;
      } catch (e) {
        debugPrint('Error al sincronizar categoría ${categoria.id}: $e');
      }
    }

    return pushed;
  }

  Future<int> _pushPersonas() async {
    final pendientes = await (_database.select(_database.personas)
          ..where((p) => p.sincronizado.equals(false) | p.syncId.isNull()))
        .get();

    int pushed = 0;

    for (final persona in pendientes) {
      try {
        // PREVENCIÓN DE DUPLICADOS: Si la persona NO tiene syncId,
        // verificar si ya existe en Supabase antes de hacer upsert
        if (persona.syncId == null) {
          final existentes = await _supabase
              .from('personas')
              .select('id')
              .eq('user_id', _currentUserId!)
              .eq('nombre', persona.nombre)
              .eq('activa', true);

          if (existentes.isNotEmpty) {
            // Ya existe en Supabase: vincular sin insertar nueva
            final remoteId = existentes.first['id'] as String;

            debugPrint('✅ Persona "${persona.nombre}" ya existe en Supabase con id=$remoteId. Vinculando sin duplicar.');

            // Actualizar syncId local
            await (_database.update(_database.personas)
                  ..where((p) => p.id.equals(persona.id)))
                .write(PersonasCompanion(
              syncId: Value(remoteId),
              sincronizado: const Value(true),
              ultimaModificacion: Value(DateTime.now()),
            ));

            // Crear mapping
            await _database.into(_database.syncMappings).insertOnConflictUpdate(
                  SyncMappingsCompanion.insert(
                    tabla: 'personas',
                    localId: persona.id,
                    supabaseId: remoteId,
                    syncedAt: Value(DateTime.now()),
                  ),
                );

            pushed++;
            continue; // No hacer upsert, ya existe
          }
        }

        final data = {
          'user_id': _currentUserId,
          'nombre': persona.nombre,
          'telefono': persona.telefono,
          'email': persona.email,
          'relacion': persona.relacion,
          'notas': persona.notas,
          'avatar': persona.avatar,
          'color': persona.color,
          'activa': persona.activa,
          'created_at': persona.creadaEn.toIso8601String(),
          'updated_at': persona.actualizadaEn.toIso8601String(),
        };

        if (persona.syncId != null) {
          data['id'] = persona.syncId;
        }

        final response = await _supabase
            .from('personas')
            .upsert(data, onConflict: 'id')
            .select()
            .single();

        final supabaseId = response['id'] as String;

        await (_database.update(_database.personas)
              ..where((p) => p.id.equals(persona.id)))
            .write(PersonasCompanion(
          syncId: Value(supabaseId),
          sincronizado: const Value(true),
          ultimaModificacion: Value(DateTime.now()),
        ));

        await _database.into(_database.syncMappings).insertOnConflictUpdate(
              SyncMappingsCompanion.insert(
                tabla: 'personas',
                localId: persona.id,
                supabaseId: supabaseId,
                syncedAt: Value(DateTime.now()),
              ),
            );

        pushed++;
      } catch (e) {
        debugPrint('Error al sincronizar persona ${persona.id}: $e');
      }
    }

    return pushed;
  }

  Future<int> _pushPerfil() async {
    final pendientes = await (_database.select(_database.perfiles)
          ..where((p) => p.sincronizado.equals(false) | p.syncId.isNull()))
        .get();

    int pushed = 0;

    for (final perfil in pendientes) {
      try {
        // En perfiles, el 'id' es el user_id (relación 1:1 con auth.users)
        // NO existe columna 'user_id' en la tabla perfiles
        final data = {
          'id': _currentUserId, // PK = ID del usuario autenticado
          'nombre': perfil.nombre,
          'fecha_nacimiento': perfil.fechaNacimiento?.toIso8601String(),
          'color_primario': perfil.colorPrimario,
          'tema_oscuro': perfil.temaOscuro,
          'color_dinamico': perfil.colorDinamico,
          'balance_minimo': perfil.balanceMinimo,
          'balance_maximo': perfil.balanceMaximo,
          'notif_cuotas': perfil.notifCuotas,
          'notif_dias_antes': perfil.notifDiasAntes,
          'notif_gastos_fijos': perfil.notifGastosFijos,
        };

        final response = await _supabase
            .from('perfiles')
            .upsert(data, onConflict: 'id')
            .select()
            .single();

        final supabaseId = response['id'] as String;

        await (_database.update(_database.perfiles)
              ..where((p) => p.id.equals(perfil.id)))
            .write(PerfilesCompanion(
          syncId: Value(supabaseId),
          sincronizado: const Value(true),
          ultimaModificacion: Value(DateTime.now()),
        ));

        await _database.into(_database.syncMappings).insertOnConflictUpdate(
              SyncMappingsCompanion.insert(
                tabla: 'perfiles',
                localId: perfil.id,
                supabaseId: supabaseId,
                syncedAt: Value(DateTime.now()),
              ),
            );

        pushed++;
      } catch (e) {
        debugPrint('Error al sincronizar perfil ${perfil.id}: $e');
      }
    }

    return pushed;
  }

  Future<int> _pushGastosFijos() async {
    final pendientes = await (_database.select(_database.gastosFijos)
          ..where((g) => g.sincronizado.equals(false)))
        .get();

    int pushed = 0;

    for (final gasto in pendientes) {
      try {
        String? categoriaSyncId;
        if (gasto.categoriaId != null) {
          categoriaSyncId = await _getSupabaseId('categorias', gasto.categoriaId!);
        }

        final data = {
          'user_id': _currentUserId,
          'nombre': gasto.nombre,
          'monto': gasto.monto,
          'dia_vencimiento': gasto.diaVencimiento,
          'categoria_id': categoriaSyncId,
          'activo': gasto.activo,
          'created_at': gasto.creadoEn.toIso8601String(),
        };

        if (gasto.syncId != null) {
          data['id'] = gasto.syncId;
        }

        final response = await _supabase
            .from('gastos_fijos')
            .upsert(data, onConflict: 'id')
            .select()
            .single();

        final supabaseId = response['id'] as String;

        await (_database.update(_database.gastosFijos)
              ..where((g) => g.id.equals(gasto.id)))
            .write(GastosFijosCompanion(
          syncId: Value(supabaseId),
          sincronizado: const Value(true),
          ultimaModificacion: Value(DateTime.now()),
        ));

        await _database.into(_database.syncMappings).insertOnConflictUpdate(
              SyncMappingsCompanion.insert(
                tabla: 'gastos_fijos',
                localId: gasto.id,
                supabaseId: supabaseId,
                syncedAt: Value(DateTime.now()),
              ),
            );

        pushed++;
      } catch (e) {
        debugPrint('Error al sincronizar gasto fijo ${gasto.id}: $e');
      }
    }

    return pushed;
  }

  Future<int> _pushTransacciones() async {
    final pendientes = await (_database.select(_database.transacciones)
          ..where((t) => t.sincronizado.equals(false)))
        .get();

    int pushed = 0;

    for (final tx in pendientes) {
      try {
        // Mapear foreign keys
        final cuentaSyncId = await _getSupabaseId('cuentas', tx.cuentaId);
        final categoriaSyncId = await _getSupabaseId('categorias', tx.categoriaId);
        String? personaSyncId;
        if (tx.personaId != null) {
          personaSyncId = await _getSupabaseId('personas', tx.personaId!);
        }

        // Mapear cuenta destino para transferencias
        String? cuentaDestinoSyncId;
        if (tx.cuentaDestinoId != null) {
          cuentaDestinoSyncId = await _getSupabaseId('cuentas', tx.cuentaDestinoId!);
        }

        // Sanitizar transferencia_id: regenerar si no es UUID válido
        String? transferenciaIdFinal = tx.transferenciaId;
        if (transferenciaIdFinal != null && !_esUuidValido(transferenciaIdFinal)) {
          // Regenerar UUID válido para transferencias con formato inválido
          transferenciaIdFinal = const Uuid().v4();
          debugPrint('⚠️ Regenerando UUID inválido para transferencia ${tx.id}: ${tx.transferenciaId} → $transferenciaIdFinal');

          // Actualizar registro local con UUID válido
          await (_database.update(_database.transacciones)
                ..where((t) => t.id.equals(tx.id)))
              .write(TransaccionesCompanion(
            transferenciaId: Value(transferenciaIdFinal),
          ));
        }

        final data = {
          'user_id': _currentUserId,
          'tipo': tx.tipo,
          'descripcion': tx.descripcion,
          'monto_total': tx.montoTotal,
          'forma_pago': tx.formaPago,
          'es_prestamo': tx.esPrestamo,
          'estado': tx.estado,
          'fecha': tx.fecha.toIso8601String(),
          'cuenta_id': cuentaSyncId,
          'categoria_id': categoriaSyncId,
          'persona_id': personaSyncId,
          'cuenta_destino_id': cuentaDestinoSyncId,
          'transferencia_id': transferenciaIdFinal,
          'cantidad_cuotas': tx.cantidadCuotas,
          'valor_cuota': tx.valorCuota,
          'tasa_interes': tx.tasaInteres,
          'tipo_interes': tx.tipoInteres,
          'monto_total_con_interes': tx.montoTotalConInteres,
          'interes_total': tx.interesTotal,
          'notas': tx.notas,
          'etiquetas': tx.etiquetas,
          'created_at': tx.creadaEn.toIso8601String(),
          'updated_at': tx.actualizadaEn.toIso8601String(),
          'deleted_at': tx.deletedAt?.toIso8601String(),
        };

        if (tx.syncId != null) {
          data['id'] = tx.syncId;
        }

        final response = await _supabase
            .from('transacciones')
            .upsert(data, onConflict: 'id')
            .select()
            .single();

        final supabaseId = response['id'] as String;

        await (_database.update(_database.transacciones)
              ..where((t) => t.id.equals(tx.id)))
            .write(TransaccionesCompanion(
          syncId: Value(supabaseId),
          sincronizado: const Value(true),
          ultimaModificacion: Value(DateTime.now()),
        ));

        await _database.into(_database.syncMappings).insertOnConflictUpdate(
              SyncMappingsCompanion.insert(
                tabla: 'transacciones',
                localId: tx.id,
                supabaseId: supabaseId,
                syncedAt: Value(DateTime.now()),
              ),
            );

        pushed++;
      } catch (e) {
        debugPrint('Error al sincronizar transacción ${tx.id}: $e');
      }
    }

    return pushed;
  }

  Future<int> _pushCuotas() async {
    final pendientes = await (_database.select(_database.cuotas)
          ..where((c) => c.sincronizado.equals(false)))
        .get();

    int pushed = 0;

    for (final cuota in pendientes) {
      try {
        // Mapear transaccionId
        final transaccionSyncId = await _getSupabaseId('transacciones', cuota.transaccionId);
        if (transaccionSyncId == null) {
          debugPrint('Cuota ${cuota.id}: transacción no sincronizada, omitiendo');
          continue;
        }

        final data = {
          'user_id': _currentUserId,
          'transaccion_id': transaccionSyncId,
          'numero_cuota': cuota.numeroCuota,
          'monto': cuota.monto,
          'fecha_vencimiento': cuota.fechaVencimiento.toIso8601String(),
          'pagada': cuota.pagada,
          'fecha_pago': cuota.fechaPago?.toIso8601String(),
          'monto_capital': cuota.montoCapital,
          'monto_interes': cuota.montoInteres,
          'notas': cuota.notas,
          'created_at': cuota.creadaEn.toIso8601String(),
          'updated_at': cuota.actualizadaEn.toIso8601String(),
          'deleted_at': cuota.deletedAt?.toIso8601String(),
        };

        if (cuota.syncId != null) {
          data['id'] = cuota.syncId;
        }

        final response = await _supabase
            .from('cuotas')
            .upsert(data, onConflict: 'id')
            .select()
            .single();

        final supabaseId = response['id'] as String;

        await (_database.update(_database.cuotas)
              ..where((c) => c.id.equals(cuota.id)))
            .write(CuotasCompanion(
          syncId: Value(supabaseId),
          sincronizado: const Value(true),
          ultimaModificacion: Value(DateTime.now()),
        ));

        await _database.into(_database.syncMappings).insertOnConflictUpdate(
              SyncMappingsCompanion.insert(
                tabla: 'cuotas',
                localId: cuota.id,
                supabaseId: supabaseId,
                syncedAt: Value(DateTime.now()),
              ),
            );

        pushed++;
      } catch (e) {
        debugPrint('Error al sincronizar cuota ${cuota.id}: $e');
      }
    }

    return pushed;
  }

  Future<int> _pushDeudas() async {
    final pendientes = await (_database.select(_database.deudas)
          ..where((d) => d.sincronizado.equals(false)))
        .get();

    int pushed = 0;

    for (final deuda in pendientes) {
      try {
        // Mapear foreign keys
        final personaSyncId = await _getSupabaseId('personas', deuda.personaId);
        final transaccionSyncId = await _getSupabaseId('transacciones', deuda.transaccionId);

        if (personaSyncId == null || transaccionSyncId == null) {
          debugPrint('Deuda ${deuda.id}: dependencias no sincronizadas, omitiendo');
          continue;
        }

        final data = {
          'user_id': _currentUserId,
          'persona_id': personaSyncId,
          'transaccion_id': transaccionSyncId,
          'tipo': deuda.tipo,
          'monto_total': deuda.montoTotal,
          'monto_pendiente': deuda.montoPendiente,
          'monto_pagado': deuda.montoPagado,
          'fecha_acordada_pago': deuda.fechaAcordadaPago?.toIso8601String(),
          'estado': deuda.estado,
          'notas': deuda.notas,
          'created_at': deuda.creadaEn.toIso8601String(),
          'updated_at': deuda.actualizadaEn.toIso8601String(),
          'deleted_at': deuda.deletedAt?.toIso8601String(),
        };

        if (deuda.syncId != null) {
          data['id'] = deuda.syncId;
        }

        final response = await _supabase
            .from('deudas')
            .upsert(data, onConflict: 'id')
            .select()
            .single();

        final supabaseId = response['id'] as String;

        await (_database.update(_database.deudas)
              ..where((d) => d.id.equals(deuda.id)))
            .write(DeudasCompanion(
          syncId: Value(supabaseId),
          sincronizado: const Value(true),
          ultimaModificacion: Value(DateTime.now()),
        ));

        await _database.into(_database.syncMappings).insertOnConflictUpdate(
              SyncMappingsCompanion.insert(
                tabla: 'deudas',
                localId: deuda.id,
                supabaseId: supabaseId,
                syncedAt: Value(DateTime.now()),
              ),
            );

        pushed++;
      } catch (e) {
        debugPrint('Error al sincronizar deuda ${deuda.id}: $e');
      }
    }

    return pushed;
  }

  Future<int> _pushPagosDeuda() async {
    final pendientes = await (_database.select(_database.pagosDeuda)
          ..where((p) => p.sincronizado.equals(false)))
        .get();

    int pushed = 0;

    for (final pago in pendientes) {
      try {
        // Mapear foreign keys
        final deudaSyncId = await _getSupabaseId('deudas', pago.deudaId);
        if (deudaSyncId == null) {
          debugPrint('Pago deuda ${pago.id}: deuda no sincronizada, omitiendo');
          continue;
        }

        String? transaccionSyncId;
        if (pago.transaccionId != null) {
          transaccionSyncId = await _getSupabaseId('transacciones', pago.transaccionId!);
        }

        final data = {
          'user_id': _currentUserId,
          'deuda_id': deudaSyncId,
          'monto': pago.monto,
          'fecha_pago': pago.fechaPago.toIso8601String(),
          'metodo_pago': pago.metodoPago,
          'notas': pago.notas,
          'transaccion_id': transaccionSyncId,
          'created_at': pago.creadoEn.toIso8601String(),
          'deleted_at': pago.deletedAt?.toIso8601String(),
        };

        if (pago.syncId != null) {
          data['id'] = pago.syncId;
        }

        final response = await _supabase
            .from('pagos_deuda')
            .upsert(data, onConflict: 'id')
            .select()
            .single();

        final supabaseId = response['id'] as String;

        await (_database.update(_database.pagosDeuda)
              ..where((p) => p.id.equals(pago.id)))
            .write(PagosDeudaCompanion(
          syncId: Value(supabaseId),
          sincronizado: const Value(true),
          ultimaModificacion: Value(DateTime.now()),
        ));

        await _database.into(_database.syncMappings).insertOnConflictUpdate(
              SyncMappingsCompanion.insert(
                tabla: 'pagos_deuda',
                localId: pago.id,
                supabaseId: supabaseId,
                syncedAt: Value(DateTime.now()),
              ),
            );

        pushed++;
      } catch (e) {
        debugPrint('Error al sincronizar pago deuda ${pago.id}: $e');
      }
    }

    return pushed;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PULL: Helper universal para resolución robusta de Foreign Keys
  // ══════════════════════════════════════════════════════════════════════════

  /// Resuelve un ID local a partir de un UUID de Supabase con estrategia dual:
  /// 1. Busca primero en SyncMappings (mapping explícito)
  /// 2. Si no encuentra, busca directamente en la tabla por syncId
  ///
  /// Retorna el ID local o null si no existe en ninguna fuente.
  ///
  /// Ejemplo: _resolveLocalId('cuentas', 'uuid-supabase-123')
  Future<int?> _resolveLocalId(String tabla, String? supabaseId) async {
    if (supabaseId == null) return null;

    try {
      // Estrategia 1: Buscar en SyncMappings
      final mapping = await (_database.select(_database.syncMappings)
            ..where((m) =>
                m.tabla.equals(tabla) & m.supabaseId.equals(supabaseId)))
          .getSingleOrNull();

      if (mapping != null) {
        return mapping.localId;
      }

      // Estrategia 2: Fallback directo a la tabla por syncId
      switch (tabla) {
        case 'cuentas':
          final cuenta = await (_database.select(_database.cuentas)
                ..where((c) => c.syncId.equals(supabaseId)))
              .getSingleOrNull();
          return cuenta?.id;

        case 'categorias':
          final categoria = await (_database.select(_database.categorias)
                ..where((c) => c.syncId.equals(supabaseId)))
              .getSingleOrNull();
          return categoria?.id;

        case 'personas':
          final persona = await (_database.select(_database.personas)
                ..where((p) => p.syncId.equals(supabaseId)))
              .getSingleOrNull();
          return persona?.id;

        case 'transacciones':
          final transaccion = await (_database.select(_database.transacciones)
                ..where((t) => t.syncId.equals(supabaseId)))
              .getSingleOrNull();
          return transaccion?.id;

        case 'deudas':
          final deuda = await (_database.select(_database.deudas)
                ..where((d) => d.syncId.equals(supabaseId)))
              .getSingleOrNull();
          return deuda?.id;

        case 'gastos_fijos':
          final gastoFijo = await (_database.select(_database.gastosFijos)
                ..where((g) => g.syncId.equals(supabaseId)))
              .getSingleOrNull();
          return gastoFijo?.id;

        default:
          debugPrint('⚠️ Tabla no soportada en _resolveLocalId: $tabla');
          return null;
      }
    } catch (e, stack) {
      debugPrint('Error en _resolveLocalId($tabla, $supabaseId): $e\n$stack');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PULL: Métodos específicos por tabla
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> _pullCuentas(DateTime? lastSync) async {
    debugPrint('📥 [_pullCuentas] Iniciando pull (lastSync: ${lastSync != null ? lastSync.toIso8601String() : "NULL - PULL COMPLETO"})');

    var query = _supabase
        .from('cuentas')
        .select()
        .eq('user_id', _currentUserId!);

    if (lastSync != null) {
      debugPrint('📥 [_pullCuentas] Aplicando filtro temporal');
      query = query.gt('updated_at', lastSync.toIso8601String());
    } else {
      debugPrint('📥 [_pullCuentas] PULL COMPLETO - Sin filtro temporal');
    }

    final List<dynamic> remoteCuentas = await query;
    debugPrint('📥 [_pullCuentas] Registros remotos recibidos desde Supabase: ${remoteCuentas.length}');
    int pulled = 0;

    for (final remote in remoteCuentas) {
      try {
        final supabaseId = remote['id'] as String;

        // Buscar si ya existe localmente
        final mapping = await (_database.select(_database.syncMappings)
              ..where((m) =>
                  m.tabla.equals('cuentas') & m.supabaseId.equals(supabaseId)))
            .getSingleOrNull();

        if (mapping != null) {
          // Ya existe: actualizar (conflict resolution - LWW)
          final local = await (_database.select(_database.cuentas)
                ..where((c) => c.id.equals(mapping.localId)))
              .getSingle();

          // Comparar timestamps para Last-Write-Wins
          final remoteUpdated = DateTime.parse(remote['updated_at'] as String);
          final localUpdated = local.ultimaModificacion ?? local.actualizadaEn;

          if (remoteUpdated.isAfter(localUpdated)) {
            // Remoto es más reciente, actualizar local
            await (_database.update(_database.cuentas)
                  ..where((c) => c.id.equals(mapping.localId)))
                .write(CuentasCompanion(
              nombre: Value(remote['nombre'] as String),
              tipo: Value(remote['tipo'] as String),
              saldo: Value((remote['saldo'] as num).toDouble()),
              limiteCredito: Value(remote['limite_credito'] != null
                  ? (remote['limite_credito'] as num).toDouble()
                  : null),
              diaCierre: Value(remote['dia_cierre'] as int?),
              diaPago: Value(remote['dia_pago'] as int?),
              meta: Value(remote['meta'] != null
                  ? (remote['meta'] as num).toDouble()
                  : null),
              color: Value(remote['color'] as String),
              icono: Value(remote['icono'] as String),
              activa: Value(remote['activa'] as bool),
              syncId: Value(supabaseId),
              sincronizado: const Value(true),
              ultimaModificacion: Value(remoteUpdated),
            ));
          }
        } else {
          // No existe mapeo: verificar si hay cuenta local con mismo nombre+tipo
          final nombreRemoto = remote['nombre'] as String;
          final tipoRemoto = remote['tipo'] as String;

          final cuentaLocalExistente = await (_database.select(_database.cuentas)
                ..where((c) =>
                    c.nombre.equals(nombreRemoto) &
                    c.tipo.equals(tipoRemoto) &
                    c.activa.equals(true)))
              .getSingleOrNull();

          int localId;

          if (cuentaLocalExistente != null) {
            // Ya existe una cuenta local con mismo nombre+tipo: vincular sin duplicar
            localId = cuentaLocalExistente.id;

            // Actualizar syncId de la cuenta existente
            await (_database.update(_database.cuentas)
                  ..where((c) => c.id.equals(localId)))
                .write(CuentasCompanion(
              syncId: Value(supabaseId),
              sincronizado: const Value(true),
              ultimaModificacion: Value(DateTime.now()),
            ));

            debugPrint('Cuenta "$nombreRemoto" ($tipoRemoto) ya existe localmente (id=$localId), vinculando con Supabase sin duplicar');
          } else {
            // No existe localmente: insertar nuevo
            localId = await _database.into(_database.cuentas).insert(
                  CuentasCompanion.insert(
                    nombre: nombreRemoto,
                    tipo: tipoRemoto,
                    saldo: Value((remote['saldo'] as num).toDouble()),
                    limiteCredito: Value(remote['limite_credito'] != null
                        ? (remote['limite_credito'] as num).toDouble()
                        : null),
                    diaCierre: Value(remote['dia_cierre'] as int?),
                    diaPago: Value(remote['dia_pago'] as int?),
                    meta: Value(remote['meta'] != null
                        ? (remote['meta'] as num).toDouble()
                        : null),
                    color: Value(remote['color'] as String),
                    icono: Value(remote['icono'] as String),
                    activa: Value(remote['activa'] as bool),
                    creadaEn:
                        Value(DateTime.parse(remote['created_at'] as String)),
                    actualizadaEn:
                        Value(DateTime.parse(remote['updated_at'] as String)),
                    syncId: Value(supabaseId),
                    sincronizado: const Value(true),
                    ultimaModificacion:
                        Value(DateTime.parse(remote['updated_at'] as String)),
                    userId: Value(_currentUserId),
                  ),
                );
          }

          // Crear mapeo
          await _database.into(_database.syncMappings).insertOnConflictUpdate(
                SyncMappingsCompanion.insert(
                  tabla: 'cuentas',
                  localId: localId,
                  supabaseId: supabaseId,
                  syncedAt: Value(DateTime.now()),
                ),
              );
        }

        pulled++;
      } catch (e) {
        debugPrint('Error al pull cuenta: $e');
      }
    }

    debugPrint('✅ [_pullCuentas] Pull completado: $pulled registros insertados/actualizados');
    return pulled;
  }

  Future<int> _pullCategorias(DateTime? lastSync) async {
    debugPrint('📥 [_pullCategorias] Iniciando pull (lastSync: ${lastSync != null ? lastSync.toIso8601String() : "NULL - PULL COMPLETO"})');

    var query = _supabase
        .from('categorias')
        .select()
        .eq('user_id', _currentUserId!);

    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
    }

    final List<dynamic> remoteCategorias = await query;
    int pulled = 0;

    for (final remote in remoteCategorias) {
      try {
        final supabaseId = remote['id'] as String;
        final nombreRemoto = remote['nombre'] as String;
        final tipoRemoto = remote['tipo'] as String;

        // Resolver categoriaPadreId con estrategia dual
        final parentLocalId = await _resolveLocalId(
          'categorias',
          remote['categoria_padre_id'] as String?,
        );

        final mapping = await (_database.select(_database.syncMappings)
              ..where((m) =>
                  m.tabla.equals('categorias') & m.supabaseId.equals(supabaseId)))
            .getSingleOrNull();

        if (mapping != null) {
          // Ya existe mapping: actualizar con LWW
          final local = await (_database.select(_database.categorias)
                ..where((c) => c.id.equals(mapping.localId)))
              .getSingle();

          final remoteUpdated = DateTime.parse(remote['updated_at'] as String);
          final localUpdated = local.ultimaModificacion ?? local.actualizadaEn;

          if (remoteUpdated.isAfter(localUpdated)) {
            await (_database.update(_database.categorias)
                  ..where((c) => c.id.equals(mapping.localId)))
                .write(CategoriasCompanion(
              nombre: Value(nombreRemoto),
              tipo: Value(tipoRemoto),
              categoriaPadreId: Value(parentLocalId),
              color: Value(remote['color'] as String),
              icono: Value(remote['icono'] as String),
              orden: Value(remote['orden'] as int),
              activa: Value(remote['activa'] as bool),
              syncId: Value(supabaseId),
              sincronizado: const Value(true),
              ultimaModificacion: Value(remoteUpdated),
            ));
          }
        } else {
          // No existe mapping: buscar categoría local con mismo nombre y tipo
          final categoriaExistente = await (_database.select(_database.categorias)
                ..where((c) =>
                    c.nombre.equals(nombreRemoto) &
                    c.tipo.equals(tipoRemoto) &
                    c.activa.equals(true)))
              .getSingleOrNull();

          if (categoriaExistente != null) {
            // Ya existe localmente (ej: categorías por defecto)
            // Solo crear el mapping sin duplicar
            debugPrint('Categoría "$nombreRemoto" ($tipoRemoto) ya existe localmente con id=${categoriaExistente.id}. Creando mapping sin duplicar.');

            await _database.into(_database.syncMappings).insertOnConflictUpdate(
                  SyncMappingsCompanion.insert(
                    tabla: 'categorias',
                    localId: categoriaExistente.id,
                    supabaseId: supabaseId,
                    syncedAt: Value(DateTime.now()),
                  ),
                );

            // Actualizar la categoría local con syncId y marcar como sincronizada
            await (_database.update(_database.categorias)
                  ..where((c) => c.id.equals(categoriaExistente.id)))
                .write(CategoriasCompanion(
              syncId: Value(supabaseId),
              sincronizado: const Value(true),
              ultimaModificacion: Value(DateTime.now()),
            ));
          } else {
            // No existe ni mapping ni categoría local: insertar nuevo
            final newId = await _database.into(_database.categorias).insert(
                  CategoriasCompanion.insert(
                    nombre: nombreRemoto,
                    tipo: tipoRemoto,
                    categoriaPadreId: Value(parentLocalId),
                    color: Value(remote['color'] as String),
                    icono: Value(remote['icono'] as String),
                    orden: Value(remote['orden'] as int),
                    activa: Value(remote['activa'] as bool),
                    creadaEn: Value(DateTime.parse(remote['created_at'] as String)),
                    actualizadaEn: Value(DateTime.parse(remote['updated_at'] as String)),
                    syncId: Value(supabaseId),
                    sincronizado: const Value(true),
                    ultimaModificacion: Value(DateTime.parse(remote['updated_at'] as String)),
                    userId: Value(_currentUserId),
                  ),
                );

            await _database.into(_database.syncMappings).insertOnConflictUpdate(
                  SyncMappingsCompanion.insert(
                    tabla: 'categorias',
                    localId: newId,
                    supabaseId: supabaseId,
                    syncedAt: Value(DateTime.now()),
                  ),
                );
          }
        }

        pulled++;
      } catch (e) {
        debugPrint('Error al pull categoría: $e');
      }
    }

    debugPrint('✅ [_pullCategorias] Pull completado: $pulled registros insertados/actualizados');
    return pulled;
  }

  Future<int> _pullPersonas(DateTime? lastSync) async {
    var query = _supabase
        .from('personas')
        .select()
        .eq('user_id', _currentUserId!);

    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
    }

    final List<dynamic> remotePersonas = await query;
    int pulled = 0;

    for (final remote in remotePersonas) {
      try {
        final supabaseId = remote['id'] as String;
        final mapping = await (_database.select(_database.syncMappings)
              ..where((m) =>
                  m.tabla.equals('personas') & m.supabaseId.equals(supabaseId)))
            .getSingleOrNull();

        if (mapping != null) {
          // Ya existe: actualizar con LWW
          final local = await (_database.select(_database.personas)
                ..where((p) => p.id.equals(mapping.localId)))
              .getSingle();

          final remoteUpdated = DateTime.parse(remote['updated_at'] as String);
          final localUpdated = local.ultimaModificacion ?? local.actualizadaEn;

          if (remoteUpdated.isAfter(localUpdated)) {
            await (_database.update(_database.personas)
                  ..where((p) => p.id.equals(mapping.localId)))
                .write(PersonasCompanion(
              nombre: Value(remote['nombre'] as String),
              telefono: Value(remote['telefono'] as String?),
              email: Value(remote['email'] as String?),
              relacion: Value(remote['relacion'] as String?),
              notas: Value(remote['notas'] as String?),
              avatar: Value(remote['avatar'] as String?),
              color: Value(remote['color'] as String),
              activa: Value(remote['activa'] as bool),
              syncId: Value(supabaseId),
              sincronizado: const Value(true),
              ultimaModificacion: Value(remoteUpdated),
            ));
          }
        } else {
          // No existe: insertar nuevo
          final newId = await _database.into(_database.personas).insert(
                PersonasCompanion.insert(
                  nombre: remote['nombre'] as String,
                  telefono: Value(remote['telefono'] as String?),
                  email: Value(remote['email'] as String?),
                  relacion: Value(remote['relacion'] as String?),
                  notas: Value(remote['notas'] as String?),
                  avatar: Value(remote['avatar'] as String?),
                  color: Value(remote['color'] as String),
                  activa: Value(remote['activa'] as bool),
                  creadaEn: Value(DateTime.parse(remote['created_at'] as String)),
                  actualizadaEn: Value(DateTime.parse(remote['updated_at'] as String)),
                  syncId: Value(supabaseId),
                  sincronizado: const Value(true),
                  ultimaModificacion: Value(DateTime.parse(remote['updated_at'] as String)),
                  userId: Value(_currentUserId),
                ),
              );

          await _database.into(_database.syncMappings).insertOnConflictUpdate(
                SyncMappingsCompanion.insert(
                  tabla: 'personas',
                  localId: newId,
                  supabaseId: supabaseId,
                  syncedAt: Value(DateTime.now()),
                ),
              );
        }

        pulled++;
      } catch (e) {
        debugPrint('Error al pull persona: $e');
      }
    }

    return pulled;
  }

  Future<int> _pullPerfil(DateTime? lastSync) async {
    // En perfiles, filtrar por 'id' directamente (no existe 'user_id')
    var query = _supabase
        .from('perfiles')
        .select()
        .eq('id', _currentUserId!);

    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
    }

    final List<dynamic> remotePerfiles = await query;
    int pulled = 0;

    for (final remote in remotePerfiles) {
      try {
        final supabaseId = remote['id'] as String;
        final mapping = await (_database.select(_database.syncMappings)
              ..where((m) =>
                  m.tabla.equals('perfiles') & m.supabaseId.equals(supabaseId)))
            .getSingleOrNull();

        if (mapping != null) {
          // Ya existe: actualizar con LWW
          final local = await (_database.select(_database.perfiles)
                ..where((p) => p.id.equals(mapping.localId)))
              .getSingle();

          final remoteUpdated = DateTime.parse(remote['updated_at'] as String);
          final localUpdated = local.ultimaModificacion;

          if (localUpdated == null || remoteUpdated.isAfter(localUpdated)) {
            await (_database.update(_database.perfiles)
                  ..where((p) => p.id.equals(mapping.localId)))
                .write(PerfilesCompanion(
              nombre: Value(remote['nombre'] as String?),
              fechaNacimiento: Value(remote['fecha_nacimiento'] != null
                  ? DateTime.parse(remote['fecha_nacimiento'] as String)
                  : null),
              colorPrimario: Value(remote['color_primario'] as String),
              temaOscuro: Value(remote['tema_oscuro'] as bool?),
              colorDinamico: Value(remote['color_dinamico'] as bool),
              balanceMinimo: Value((remote['balance_minimo'] as num).toDouble()),
              balanceMaximo: Value((remote['balance_maximo'] as num).toDouble()),
              notifCuotas: Value(remote['notif_cuotas'] as bool),
              notifDiasAntes: Value(remote['notif_dias_antes'] as int),
              notifGastosFijos: Value(remote['notif_gastos_fijos'] as bool),
              syncId: Value(supabaseId),
              sincronizado: const Value(true),
              ultimaModificacion: Value(remoteUpdated),
            ));
          }
        } else {
          // No existe: insertar nuevo (normalmente solo hay 1 perfil)
          final newId = await _database.into(_database.perfiles).insert(
                PerfilesCompanion.insert(
                  nombre: Value(remote['nombre'] as String?),
                  fechaNacimiento: Value(remote['fecha_nacimiento'] != null
                      ? DateTime.parse(remote['fecha_nacimiento'] as String)
                      : null),
                  colorPrimario: Value(remote['color_primario'] as String),
                  temaOscuro: Value(remote['tema_oscuro'] as bool?),
                  colorDinamico: Value(remote['color_dinamico'] as bool),
                  balanceMinimo: Value((remote['balance_minimo'] as num).toDouble()),
                  balanceMaximo: Value((remote['balance_maximo'] as num).toDouble()),
                  notifCuotas: Value(remote['notif_cuotas'] as bool),
                  notifDiasAntes: Value(remote['notif_dias_antes'] as int),
                  notifGastosFijos: Value(remote['notif_gastos_fijos'] as bool),
                  syncId: Value(supabaseId),
                  sincronizado: const Value(true),
                  ultimaModificacion: Value(DateTime.parse(remote['updated_at'] as String)),
                  userId: Value(_currentUserId),
                ),
              );

          await _database.into(_database.syncMappings).insertOnConflictUpdate(
                SyncMappingsCompanion.insert(
                  tabla: 'perfiles',
                  localId: newId,
                  supabaseId: supabaseId,
                  syncedAt: Value(DateTime.now()),
                ),
              );
        }

        pulled++;
      } catch (e) {
        debugPrint('Error al pull perfil: $e');
      }
    }

    return pulled;
  }

  Future<int> _pullGastosFijos(DateTime? lastSync) async {
    var query = _supabase
        .from('gastos_fijos')
        .select()
        .eq('user_id', _currentUserId!);

    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
    }

    final List<dynamic> remoteGastosFijos = await query;
    int pulled = 0;

    for (final remote in remoteGastosFijos) {
      try {
        final supabaseId = remote['id'] as String;

        // Resolver categoriaId con estrategia dual
        final categoriaLocalId = await _resolveLocalId(
          'categorias',
          remote['categoria_id'] as String?,
        );

        final mapping = await (_database.select(_database.syncMappings)
              ..where((m) =>
                  m.tabla.equals('gastos_fijos') & m.supabaseId.equals(supabaseId)))
            .getSingleOrNull();

        if (mapping != null) {
          // Ya existe: actualizar con LWW
          final local = await (_database.select(_database.gastosFijos)
                ..where((g) => g.id.equals(mapping.localId)))
              .getSingle();

          final remoteUpdated = DateTime.parse(remote['updated_at'] as String? ?? remote['created_at'] as String);
          final localUpdated = local.ultimaModificacion;

          if (localUpdated == null || remoteUpdated.isAfter(localUpdated)) {
            await (_database.update(_database.gastosFijos)
                  ..where((g) => g.id.equals(mapping.localId)))
                .write(GastosFijosCompanion(
              nombre: Value(remote['nombre'] as String),
              monto: Value((remote['monto'] as num).toDouble()),
              diaVencimiento: Value(remote['dia_vencimiento'] as int?),
              categoriaId: Value(categoriaLocalId),
              activo: Value(remote['activo'] as bool),
              syncId: Value(supabaseId),
              sincronizado: const Value(true),
              ultimaModificacion: Value(remoteUpdated),
            ));
          }
        } else {
          // No existe: insertar nuevo
          final newId = await _database.into(_database.gastosFijos).insert(
                GastosFijosCompanion.insert(
                  nombre: remote['nombre'] as String,
                  monto: (remote['monto'] as num).toDouble(),
                  diaVencimiento: Value(remote['dia_vencimiento'] as int?),
                  categoriaId: Value(categoriaLocalId),
                  activo: Value(remote['activo'] as bool),
                  creadoEn: Value(DateTime.parse(remote['created_at'] as String)),
                  syncId: Value(supabaseId),
                  sincronizado: const Value(true),
                  ultimaModificacion: Value(DateTime.parse(remote['updated_at'] as String? ?? remote['created_at'] as String)),
                  userId: Value(_currentUserId),
                ),
              );

          await _database.into(_database.syncMappings).insertOnConflictUpdate(
                SyncMappingsCompanion.insert(
                  tabla: 'gastos_fijos',
                  localId: newId,
                  supabaseId: supabaseId,
                  syncedAt: Value(DateTime.now()),
                ),
              );
        }

        pulled++;
      } catch (e) {
        debugPrint('Error al pull gasto fijo: $e');
      }
    }

    return pulled;
  }

  Future<int> _pullTransacciones(DateTime? lastSync) async {
    debugPrint('📥 [_pullTransacciones] Iniciando pull (lastSync: ${lastSync != null ? lastSync.toIso8601String() : "NULL - PULL COMPLETO"})');

    var query = _supabase
        .from('transacciones')
        .select()
        .eq('user_id', _currentUserId!);

    // CRÍTICO: Solo aplicar filtro temporal si NO es la primera sincronización
    if (lastSync != null) {
      debugPrint('📥 [_pullTransacciones] Aplicando filtro temporal: updated_at > ${lastSync.toIso8601String()}');
      query = query.gt('updated_at', lastSync.toIso8601String());
    } else {
      debugPrint('📥 [_pullTransacciones] PULL COMPLETO - Sin filtro temporal');
    }

    final List<dynamic> remoteTransacciones = await query;
    debugPrint('📥 [_pullTransacciones] Registros remotos recibidos desde Supabase: ${remoteTransacciones.length}');
    int pulled = 0;

    for (final remote in remoteTransacciones) {
      try {
        final supabaseId = remote['id'] as String;

        // Resolver foreign keys con estrategia dual
        debugPrint('🔍 [Tx $supabaseId] Resolviendo FKs | cuenta_id: ${remote['cuenta_id']} | categoria_id: ${remote['categoria_id']} | persona_id: ${remote['persona_id']} | cuenta_destino_id: ${remote['cuenta_destino_id']}');

        final cuentaLocalId = await _resolveLocalId(
          'cuentas',
          remote['cuenta_id'] as String?,
        );

        final categoriaLocalId = await _resolveLocalId(
          'categorias',
          remote['categoria_id'] as String?,
        );

        final personaLocalId = await _resolveLocalId(
          'personas',
          remote['persona_id'] as String?,
        );

        final cuentaDestinoLocalId = await _resolveLocalId(
          'cuentas',
          remote['cuenta_destino_id'] as String?,
        );

        debugPrint('✅ [Tx $supabaseId] FKs resueltos | cuentaLocalId: $cuentaLocalId | categoriaLocalId: $categoriaLocalId | personaLocalId: $personaLocalId | cuentaDestinoLocalId: $cuentaDestinoLocalId');

        // Validar que existan las dependencias obligatorias
        if (cuentaLocalId == null || categoriaLocalId == null) {
          debugPrint('❌ [Tx $supabaseId] DESCARTADA - Dependencias obligatorias no encontradas (cuenta: $cuentaLocalId, categoria: $categoriaLocalId)');
          continue;
        }

        debugPrint('💾 [Tx $supabaseId] Insertando/Actualizando transacción: ${remote['descripcion']} | Monto: ${remote['monto_total']}');

        final mapping = await (_database.select(_database.syncMappings)
              ..where((m) =>
                  m.tabla.equals('transacciones') & m.supabaseId.equals(supabaseId)))
            .getSingleOrNull();

        if (mapping != null) {
          // Ya existe: actualizar con LWW
          final local = await (_database.select(_database.transacciones)
                ..where((t) => t.id.equals(mapping.localId)))
              .getSingle();

          final remoteUpdated = DateTime.parse(remote['updated_at'] as String);
          final localUpdated = local.ultimaModificacion ?? local.actualizadaEn;

          if (remoteUpdated.isAfter(localUpdated)) {
            await (_database.update(_database.transacciones)
                  ..where((t) => t.id.equals(mapping.localId)))
                .write(TransaccionesCompanion(
              tipo: Value(remote['tipo'] as String),
              descripcion: Value(remote['descripcion'] as String),
              montoTotal: Value((remote['monto_total'] as num).toDouble()),
              formaPago: Value(remote['forma_pago'] as String),
              esPrestamo: Value(remote['es_prestamo'] as bool),
              estado: Value(remote['estado'] as String),
              fecha: Value(DateTime.parse(remote['fecha'] as String)),
              cuentaId: Value(cuentaLocalId),
              categoriaId: Value(categoriaLocalId),
              personaId: Value(personaLocalId),
              cuentaDestinoId: Value(cuentaDestinoLocalId),
              transferenciaId: Value(remote['transferencia_id'] as String?),
              cantidadCuotas: Value(remote['cantidad_cuotas'] as int?),
              valorCuota: Value(remote['valor_cuota'] != null
                  ? (remote['valor_cuota'] as num).toDouble()
                  : null),
              tasaInteres: Value(remote['tasa_interes'] != null
                  ? (remote['tasa_interes'] as num).toDouble()
                  : null),
              tipoInteres: Value(remote['tipo_interes'] as String?),
              montoTotalConInteres: Value(remote['monto_total_con_interes'] != null
                  ? (remote['monto_total_con_interes'] as num).toDouble()
                  : null),
              interesTotal: Value(remote['interes_total'] != null
                  ? (remote['interes_total'] as num).toDouble()
                  : null),
              notas: Value(remote['notas'] as String?),
              etiquetas: Value(remote['etiquetas'] as String?),
              deletedAt: Value(remote['deleted_at'] != null
                  ? DateTime.parse(remote['deleted_at'] as String)
                  : null),
              syncId: Value(supabaseId),
              sincronizado: const Value(true),
              ultimaModificacion: Value(remoteUpdated),
            ));
          }
        } else {
          // No existe: insertar nuevo
          final newId = await _database.into(_database.transacciones).insert(
                TransaccionesCompanion.insert(
                  tipo: remote['tipo'] as String,
                  descripcion: remote['descripcion'] as String,
                  montoTotal: (remote['monto_total'] as num).toDouble(),
                  formaPago: remote['forma_pago'] as String,
                  esPrestamo: Value(remote['es_prestamo'] as bool),
                  estado: Value(remote['estado'] as String),
                  fecha: DateTime.parse(remote['fecha'] as String),
                  cuentaId: cuentaLocalId,
                  categoriaId: categoriaLocalId,
                  personaId: Value(personaLocalId),
                  cuentaDestinoId: Value(cuentaDestinoLocalId),
                  transferenciaId: Value(remote['transferencia_id'] as String?),
                  cantidadCuotas: Value(remote['cantidad_cuotas'] as int?),
                  valorCuota: Value(remote['valor_cuota'] != null
                      ? (remote['valor_cuota'] as num).toDouble()
                      : null),
                  tasaInteres: Value(remote['tasa_interes'] != null
                      ? (remote['tasa_interes'] as num).toDouble()
                      : null),
                  tipoInteres: Value(remote['tipo_interes'] as String?),
                  montoTotalConInteres: Value(remote['monto_total_con_interes'] != null
                      ? (remote['monto_total_con_interes'] as num).toDouble()
                      : null),
                  interesTotal: Value(remote['interes_total'] != null
                      ? (remote['interes_total'] as num).toDouble()
                      : null),
                  notas: Value(remote['notas'] as String?),
                  etiquetas: Value(remote['etiquetas'] as String?),
                  creadaEn: Value(DateTime.parse(remote['created_at'] as String)),
                  actualizadaEn: Value(DateTime.parse(remote['updated_at'] as String)),
                  deletedAt: Value(remote['deleted_at'] != null
                      ? DateTime.parse(remote['deleted_at'] as String)
                      : null),
                  syncId: Value(supabaseId),
                  sincronizado: const Value(true),
                  ultimaModificacion: Value(DateTime.parse(remote['updated_at'] as String)),
                  userId: Value(_currentUserId),
                ),
              );

          await _database.into(_database.syncMappings).insertOnConflictUpdate(
                SyncMappingsCompanion.insert(
                  tabla: 'transacciones',
                  localId: newId,
                  supabaseId: supabaseId,
                  syncedAt: Value(DateTime.now()),
                ),
              );
        }

        pulled++;
      } catch (e) {
        debugPrint('❌ Error al pull transacción: $e');
      }
    }

    debugPrint('✅ [_pullTransacciones] Pull completado: $pulled transacciones insertadas/actualizadas de ${remoteTransacciones.length} recibidas');

    // CRÍTICO: Recalcular saldos si se insertaron transacciones
    if (pulled > 0) {
      debugPrint('🔄 Recalculando saldos después de insertar $pulled transacciones...');
      await _database.recalcularTodosSaldos();
      debugPrint('✅ Saldos recalculados post-pull exitosamente');
    }

    return pulled;
  }

  Future<int> _pullCuotas(DateTime? lastSync) async {
    var query = _supabase
        .from('cuotas')
        .select()
        .eq('user_id', _currentUserId!);

    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
    }

    final List<dynamic> remoteCuotas = await query;
    int pulled = 0;

    for (final remote in remoteCuotas) {
      try {
        final supabaseId = remote['id'] as String;

        // Resolver transaccionId con estrategia dual
        final transaccionLocalId = await _resolveLocalId(
          'transacciones',
          remote['transaccion_id'] as String?,
        );

        if (transaccionLocalId == null) {
          debugPrint('⚠️ Cuota $supabaseId: transacción no encontrada, omitiendo');
          continue;
        }

        final mapping = await (_database.select(_database.syncMappings)
              ..where((m) =>
                  m.tabla.equals('cuotas') & m.supabaseId.equals(supabaseId)))
            .getSingleOrNull();

        if (mapping != null) {
          // Ya existe: actualizar con LWW
          final local = await (_database.select(_database.cuotas)
                ..where((c) => c.id.equals(mapping.localId)))
              .getSingle();

          final remoteUpdated = DateTime.parse(remote['updated_at'] as String);
          final localUpdated = local.ultimaModificacion ?? local.actualizadaEn;

          if (remoteUpdated.isAfter(localUpdated)) {
            await (_database.update(_database.cuotas)
                  ..where((c) => c.id.equals(mapping.localId)))
                .write(CuotasCompanion(
              transaccionId: Value(transaccionLocalId),
              numeroCuota: Value(remote['numero_cuota'] as int),
              monto: Value((remote['monto'] as num).toDouble()),
              fechaVencimiento: Value(DateTime.parse(remote['fecha_vencimiento'] as String)),
              pagada: Value(remote['pagada'] as bool),
              fechaPago: Value(remote['fecha_pago'] != null
                  ? DateTime.parse(remote['fecha_pago'] as String)
                  : null),
              montoCapital: Value(remote['monto_capital'] != null
                  ? (remote['monto_capital'] as num).toDouble()
                  : null),
              montoInteres: Value(remote['monto_interes'] != null
                  ? (remote['monto_interes'] as num).toDouble()
                  : null),
              notas: Value(remote['notas'] as String?),
              deletedAt: Value(remote['deleted_at'] != null
                  ? DateTime.parse(remote['deleted_at'] as String)
                  : null),
              syncId: Value(supabaseId),
              sincronizado: const Value(true),
              ultimaModificacion: Value(remoteUpdated),
            ));
          }
        } else {
          // No existe: insertar nuevo
          final newId = await _database.into(_database.cuotas).insert(
                CuotasCompanion.insert(
                  transaccionId: transaccionLocalId,
                  numeroCuota: remote['numero_cuota'] as int,
                  monto: (remote['monto'] as num).toDouble(),
                  fechaVencimiento: DateTime.parse(remote['fecha_vencimiento'] as String),
                  pagada: Value(remote['pagada'] as bool),
                  fechaPago: Value(remote['fecha_pago'] != null
                      ? DateTime.parse(remote['fecha_pago'] as String)
                      : null),
                  montoCapital: Value(remote['monto_capital'] != null
                      ? (remote['monto_capital'] as num).toDouble()
                      : null),
                  montoInteres: Value(remote['monto_interes'] != null
                      ? (remote['monto_interes'] as num).toDouble()
                      : null),
                  notas: Value(remote['notas'] as String?),
                  creadaEn: Value(DateTime.parse(remote['created_at'] as String)),
                  actualizadaEn: Value(DateTime.parse(remote['updated_at'] as String)),
                  deletedAt: Value(remote['deleted_at'] != null
                      ? DateTime.parse(remote['deleted_at'] as String)
                      : null),
                  syncId: Value(supabaseId),
                  sincronizado: const Value(true),
                  ultimaModificacion: Value(DateTime.parse(remote['updated_at'] as String)),
                  userId: Value(_currentUserId),
                ),
              );

          await _database.into(_database.syncMappings).insertOnConflictUpdate(
                SyncMappingsCompanion.insert(
                  tabla: 'cuotas',
                  localId: newId,
                  supabaseId: supabaseId,
                  syncedAt: Value(DateTime.now()),
                ),
              );
        }

        pulled++;
      } catch (e) {
        debugPrint('Error al pull cuota: $e');
      }
    }

    return pulled;
  }

  Future<int> _pullDeudas(DateTime? lastSync) async {
    var query = _supabase
        .from('deudas')
        .select()
        .eq('user_id', _currentUserId!);

    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
    }

    final List<dynamic> remoteDeudas = await query;
    int pulled = 0;

    for (final remote in remoteDeudas) {
      try {
        final supabaseId = remote['id'] as String;

        // Resolver foreign keys con estrategia dual
        final personaLocalId = await _resolveLocalId(
          'personas',
          remote['persona_id'] as String?,
        );

        final transaccionLocalId = await _resolveLocalId(
          'transacciones',
          remote['transaccion_id'] as String?,
        );

        if (personaLocalId == null || transaccionLocalId == null) {
          debugPrint('⚠️ Deuda $supabaseId: dependencias no encontradas (persona: $personaLocalId, transaccion: $transaccionLocalId), omitiendo');
          continue;
        }

        final mapping = await (_database.select(_database.syncMappings)
              ..where((m) =>
                  m.tabla.equals('deudas') & m.supabaseId.equals(supabaseId)))
            .getSingleOrNull();

        if (mapping != null) {
          // Ya existe: actualizar con LWW
          final local = await (_database.select(_database.deudas)
                ..where((d) => d.id.equals(mapping.localId)))
              .getSingle();

          final remoteUpdated = DateTime.parse(remote['updated_at'] as String);
          final localUpdated = local.ultimaModificacion ?? local.actualizadaEn;

          if (remoteUpdated.isAfter(localUpdated)) {
            await (_database.update(_database.deudas)
                  ..where((d) => d.id.equals(mapping.localId)))
                .write(DeudasCompanion(
              personaId: Value(personaLocalId),
              transaccionId: Value(transaccionLocalId),
              tipo: Value(remote['tipo'] as String),
              montoTotal: Value((remote['monto_total'] as num).toDouble()),
              montoPendiente: Value((remote['monto_pendiente'] as num).toDouble()),
              montoPagado: Value((remote['monto_pagado'] as num).toDouble()),
              fechaAcordadaPago: Value(remote['fecha_acordada_pago'] != null
                  ? DateTime.parse(remote['fecha_acordada_pago'] as String)
                  : null),
              estado: Value(remote['estado'] as String),
              notas: Value(remote['notas'] as String?),
              deletedAt: Value(remote['deleted_at'] != null
                  ? DateTime.parse(remote['deleted_at'] as String)
                  : null),
              syncId: Value(supabaseId),
              sincronizado: const Value(true),
              ultimaModificacion: Value(remoteUpdated),
            ));
          }
        } else {
          // No existe: insertar nuevo
          final newId = await _database.into(_database.deudas).insert(
                DeudasCompanion.insert(
                  personaId: personaLocalId,
                  transaccionId: transaccionLocalId,
                  tipo: remote['tipo'] as String,
                  montoTotal: (remote['monto_total'] as num).toDouble(),
                  montoPendiente: (remote['monto_pendiente'] as num).toDouble(),
                  montoPagado: Value((remote['monto_pagado'] as num).toDouble()),
                  fechaAcordadaPago: Value(remote['fecha_acordada_pago'] != null
                      ? DateTime.parse(remote['fecha_acordada_pago'] as String)
                      : null),
                  estado: Value(remote['estado'] as String),
                  notas: Value(remote['notas'] as String?),
                  creadaEn: Value(DateTime.parse(remote['created_at'] as String)),
                  actualizadaEn: Value(DateTime.parse(remote['updated_at'] as String)),
                  deletedAt: Value(remote['deleted_at'] != null
                      ? DateTime.parse(remote['deleted_at'] as String)
                      : null),
                  syncId: Value(supabaseId),
                  sincronizado: const Value(true),
                  ultimaModificacion: Value(DateTime.parse(remote['updated_at'] as String)),
                  userId: Value(_currentUserId),
                ),
              );

          await _database.into(_database.syncMappings).insertOnConflictUpdate(
                SyncMappingsCompanion.insert(
                  tabla: 'deudas',
                  localId: newId,
                  supabaseId: supabaseId,
                  syncedAt: Value(DateTime.now()),
                ),
              );
        }

        pulled++;
      } catch (e) {
        debugPrint('Error al pull deuda: $e');
      }
    }

    return pulled;
  }

  Future<int> _pullPagosDeuda(DateTime? lastSync) async {
    var query = _supabase
        .from('pagos_deuda')
        .select()
        .eq('user_id', _currentUserId!);

    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
    }

    final List<dynamic> remotePagos = await query;
    int pulled = 0;

    for (final remote in remotePagos) {
      try {
        final supabaseId = remote['id'] as String;

        // Resolver foreign keys con estrategia dual
        final deudaLocalId = await _resolveLocalId(
          'deudas',
          remote['deuda_id'] as String?,
        );

        final transaccionLocalId = await _resolveLocalId(
          'transacciones',
          remote['transaccion_id'] as String?,
        );

        if (deudaLocalId == null) {
          debugPrint('⚠️ Pago deuda $supabaseId: deuda no encontrada, omitiendo');
          continue;
        }

        final mapping = await (_database.select(_database.syncMappings)
              ..where((m) =>
                  m.tabla.equals('pagos_deuda') & m.supabaseId.equals(supabaseId)))
            .getSingleOrNull();

        if (mapping != null) {
          // Ya existe: actualizar con LWW
          final local = await (_database.select(_database.pagosDeuda)
                ..where((p) => p.id.equals(mapping.localId)))
              .getSingle();

          final remoteUpdated = DateTime.parse(remote['updated_at'] as String? ?? remote['created_at'] as String);
          final localUpdated = local.ultimaModificacion;

          if (localUpdated == null || remoteUpdated.isAfter(localUpdated)) {
            await (_database.update(_database.pagosDeuda)
                  ..where((p) => p.id.equals(mapping.localId)))
                .write(PagosDeudaCompanion(
              deudaId: Value(deudaLocalId),
              monto: Value((remote['monto'] as num).toDouble()),
              fechaPago: Value(DateTime.parse(remote['fecha_pago'] as String)),
              metodoPago: Value(remote['metodo_pago'] as String),
              notas: Value(remote['notas'] as String?),
              transaccionId: Value(transaccionLocalId),
              deletedAt: Value(remote['deleted_at'] != null
                  ? DateTime.parse(remote['deleted_at'] as String)
                  : null),
              syncId: Value(supabaseId),
              sincronizado: const Value(true),
              ultimaModificacion: Value(remoteUpdated),
            ));
          }
        } else {
          // No existe: insertar nuevo
          final newId = await _database.into(_database.pagosDeuda).insert(
                PagosDeudaCompanion.insert(
                  deudaId: deudaLocalId,
                  monto: (remote['monto'] as num).toDouble(),
                  fechaPago: Value(DateTime.parse(remote['fecha_pago'] as String)),
                  metodoPago: Value(remote['metodo_pago'] as String),
                  notas: Value(remote['notas'] as String?),
                  transaccionId: Value(transaccionLocalId),
                  creadoEn: Value(DateTime.parse(remote['created_at'] as String)),
                  deletedAt: Value(remote['deleted_at'] != null
                      ? DateTime.parse(remote['deleted_at'] as String)
                      : null),
                  syncId: Value(supabaseId),
                  sincronizado: const Value(true),
                  ultimaModificacion: Value(DateTime.parse(remote['updated_at'] as String? ?? remote['created_at'] as String)),
                  userId: Value(_currentUserId),
                ),
              );

          await _database.into(_database.syncMappings).insertOnConflictUpdate(
                SyncMappingsCompanion.insert(
                  tabla: 'pagos_deuda',
                  localId: newId,
                  supabaseId: supabaseId,
                  syncedAt: Value(DateTime.now()),
                ),
              );
        }

        pulled++;
      } catch (e) {
        debugPrint('Error al pull pago deuda: $e');
      }
    }

    return pulled;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILIDADES
  // ══════════════════════════════════════════════════════════════════════════

  /// Obtener Supabase ID desde un ID local
  ///
  /// Estrategia dual de resolución:
  /// 1. Intenta leer directamente 'syncId' de la tabla local (más rápido, más confiable)
  /// 2. Si no tiene syncId, busca en sync_mappings usando .firstOrNull (evita "Too many elements")
  ///
  /// IMPORTANTE: Como la PK de sync_mappings es (tabla, supabaseId), pueden existir
  /// múltiples filas para el mismo localId, por lo que NUNCA usar .getSingleOrNull() al buscar por localId.
  Future<String?> _getSupabaseId(String tabla, int localId) async {
    // Paso 1: Intentar leer syncId directamente de la tabla local
    String? syncId;

    switch (tabla) {
      case 'cuentas':
        final record = await (_database.select(_database.cuentas)
              ..where((c) => c.id.equals(localId)))
            .getSingleOrNull();
        syncId = record?.syncId;
        break;

      case 'categorias':
        final record = await (_database.select(_database.categorias)
              ..where((c) => c.id.equals(localId)))
            .getSingleOrNull();
        syncId = record?.syncId;
        break;

      case 'personas':
        final record = await (_database.select(_database.personas)
              ..where((p) => p.id.equals(localId)))
            .getSingleOrNull();
        syncId = record?.syncId;
        break;

      case 'transacciones':
        final record = await (_database.select(_database.transacciones)
              ..where((t) => t.id.equals(localId)))
            .getSingleOrNull();
        syncId = record?.syncId;
        break;

      case 'gastos_fijos':
        final record = await (_database.select(_database.gastosFijos)
              ..where((g) => g.id.equals(localId)))
            .getSingleOrNull();
        syncId = record?.syncId;
        break;

      case 'cuotas':
        final record = await (_database.select(_database.cuotas)
              ..where((c) => c.id.equals(localId)))
            .getSingleOrNull();
        syncId = record?.syncId;
        break;

      case 'deudas':
        final record = await (_database.select(_database.deudas)
              ..where((d) => d.id.equals(localId)))
            .getSingleOrNull();
        syncId = record?.syncId;
        break;

      case 'pagos_deuda':
        final record = await (_database.select(_database.pagosDeuda)
              ..where((p) => p.id.equals(localId)))
            .getSingleOrNull();
        syncId = record?.syncId;
        break;

      case 'perfil':
        final record = await (_database.select(_database.perfiles)
              ..where((p) => p.id.equals(localId)))
            .getSingleOrNull();
        syncId = record?.syncId;
        break;
    }

    // Si encontró syncId directamente, retornar
    if (syncId != null) {
      return syncId;
    }

    // Paso 2: Fallback a sync_mappings (para registros legacy sin syncId)
    // CRÍTICO: Usar .get() + .firstOrNull en lugar de .getSingleOrNull()
    // porque pueden existir múltiples mappings para el mismo localId
    final mappings = await (_database.select(_database.syncMappings)
          ..where((m) => m.tabla.equals(tabla) & m.localId.equals(localId)))
        .get();

    return mappings.firstOrNull?.supabaseId;
  }

  /// Recalcular saldos de todas las cuentas activas
  Future<void> _recalcularTodosSaldos() async {
    await _database.recalcularTodosSaldos();
  }

  /// Limpiar cuentas duplicadas locales
  ///
  /// Busca cuentas con el mismo nombre y tipo, conserva una sola
  /// (la que tenga syncId o la más antigua) y elimina las duplicadas.
  /// Actualiza los SyncMappings y referencias en transacciones.
  Future<int> limpiarCuentasDuplicadas() async {
    debugPrint('Iniciando limpieza de cuentas duplicadas...');
    int eliminadas = 0;

    try {
      final todasCuentas = await _database.select(_database.cuentas).get();

      // Agrupar por nombre + tipo
      final grupos = <String, List<Cuenta>>{};
      for (final cuenta in todasCuentas) {
        final key = '${cuenta.nombre.toLowerCase()}_${cuenta.tipo}';
        grupos.putIfAbsent(key, () => []).add(cuenta);
      }

      // Procesar cada grupo con duplicados
      for (final entry in grupos.entries) {
        final duplicados = entry.value;
        if (duplicados.length <= 1) continue; // No hay duplicados

        // Ordenar: primero las que tienen syncId, luego por ID (más antiguas primero)
        duplicados.sort((a, b) {
          if (a.syncId != null && b.syncId == null) return -1;
          if (a.syncId == null && b.syncId != null) return 1;
          return a.id.compareTo(b.id);
        });

        final cuentaConservar = duplicados.first;
        final cuentasEliminar = duplicados.skip(1).toList();

        debugPrint('Cuenta "${cuentaConservar.nombre}" (${cuentaConservar.tipo}): conservando id=${cuentaConservar.id}, eliminando ${cuentasEliminar.length} duplicados');

        // Actualizar referencias en transacciones
        for (final ctaEliminar in cuentasEliminar) {
          await (_database.update(_database.transacciones)
                ..where((t) => t.cuentaId.equals(ctaEliminar.id)))
              .write(TransaccionesCompanion(
            cuentaId: Value(cuentaConservar.id),
          ));

          // Actualizar mapping si existe
          final mapping = await (_database.select(_database.syncMappings)
                ..where((m) =>
                    m.tabla.equals('cuentas') & m.localId.equals(ctaEliminar.id)))
              .getSingleOrNull();

          if (mapping != null) {
            // Actualizar mapping para apuntar a la cuenta conservada
            await (_database.update(_database.syncMappings)
                  ..where((m) =>
                      m.tabla.equals('cuentas') &
                      m.supabaseId.equals(mapping.supabaseId)))
                .write(SyncMappingsCompanion(
              localId: Value(cuentaConservar.id),
            ));
          }

          // Eliminar cuenta duplicada
          await (_database.delete(_database.cuentas)
                ..where((c) => c.id.equals(ctaEliminar.id)))
              .go();

          eliminadas++;
        }
      }

      debugPrint('Limpieza completada: $eliminadas cuentas duplicadas eliminadas');
    } catch (e, stack) {
      debugPrint('Error en limpieza de duplicados de cuentas: $e\n$stack');
    }

    return eliminadas;
  }

  /// Limpiar categorías duplicadas locales
  ///
  /// Busca categorías con el mismo nombre y tipo, conserva una sola
  /// (la que tenga syncId o la más antigua) y elimina las duplicadas.
  /// Actualiza los SyncMappings y referencias en transacciones.
  Future<int> limpiarCategoriasDuplicadas() async {
    debugPrint('Iniciando limpieza de categorías duplicadas...');
    int eliminadas = 0;

    try {
      final todasCategorias = await _database.select(_database.categorias).get();

      // Agrupar por nombre + tipo
      final grupos = <String, List<Categoria>>{};
      for (final cat in todasCategorias) {
        final key = '${cat.nombre.toLowerCase()}_${cat.tipo}';
        grupos.putIfAbsent(key, () => []).add(cat);
      }

      // Procesar cada grupo con duplicados
      for (final entry in grupos.entries) {
        final duplicados = entry.value;
        if (duplicados.length <= 1) continue; // No hay duplicados

        // Ordenar: primero las que tienen syncId, luego por ID (más antiguas primero)
        duplicados.sort((a, b) {
          if (a.syncId != null && b.syncId == null) return -1;
          if (a.syncId == null && b.syncId != null) return 1;
          return a.id.compareTo(b.id);
        });

        final categoriaConservar = duplicados.first;
        final categoriasEliminar = duplicados.skip(1).toList();

        debugPrint('Categoría "${categoriaConservar.nombre}" (${categoriaConservar.tipo}): conservando id=${categoriaConservar.id}, eliminando ${categoriasEliminar.length} duplicados');

        // Actualizar referencias en transacciones
        for (final catEliminar in categoriasEliminar) {
          await (_database.update(_database.transacciones)
                ..where((t) => t.categoriaId.equals(catEliminar.id)))
              .write(TransaccionesCompanion(
            categoriaId: Value(categoriaConservar.id),
          ));

          // Actualizar referencias en gastos fijos
          await (_database.update(_database.gastosFijos)
                ..where((g) => g.categoriaId.equals(catEliminar.id)))
              .write(GastosFijosCompanion(
            categoriaId: Value(categoriaConservar.id),
          ));

          // Actualizar mapping si existe
          final mapping = await (_database.select(_database.syncMappings)
                ..where((m) =>
                    m.tabla.equals('categorias') & m.localId.equals(catEliminar.id)))
              .getSingleOrNull();

          if (mapping != null) {
            // Actualizar mapping para apuntar a la categoría conservada
            await (_database.update(_database.syncMappings)
                  ..where((m) =>
                      m.tabla.equals('categorias') &
                      m.supabaseId.equals(mapping.supabaseId)))
                .write(SyncMappingsCompanion(
              localId: Value(categoriaConservar.id),
            ));
          }

          // Eliminar categoría duplicada
          await (_database.delete(_database.categorias)
                ..where((c) => c.id.equals(catEliminar.id)))
              .go();

          eliminadas++;
        }
      }

      debugPrint('Limpieza completada: $eliminadas categorías duplicadas eliminadas');
    } catch (e, stack) {
      debugPrint('Error en limpieza de duplicados: $e\n$stack');
    }

    return eliminadas;
  }

  /// Limpiar caché y resetear estado (para testing o logout)
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncKey);
    _status.value = SyncStatus.idle;
  }

  /// Validar si un string es un UUID v4 válido
  bool _esUuidValido(String value) {
    // Regex para UUID v4: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    // donde y es uno de [8, 9, a, b]
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(value);
  }

  /// Dispose
  void dispose() {
    _status.dispose();
  }
}
