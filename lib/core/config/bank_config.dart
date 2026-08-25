import '../models/bank_notification.dart';

/// Configuración de bancos y paquetes autorizados para escuchar notificaciones
class BankConfig {
  /// Lista blanca de paquetes autorizados (instituciones financieras)
  /// Se usa Set para búsqueda O(1)
  static const Set<String> authorizedPackages = {
    // Bancos Tradicionales
    'cl.bancoestado.personas', // BancoEstado
    'cl.bancochile.mobilebanking', // Banco de Chile
    'cl.santander.unired', // Santander
    'cl.bci.android', // BCI
    'com.scotiabank.mobile.cl', // Scotiabank
    'com.itau.empresas', // Itaú

    // Fintechs y Billeteras Digitales
    'com.mach.android', // MACH
    'cl.tenpo.mobile', // Tenpo
    'com.mercadopago', // Mercado Pago
    'cl.mercadopago.wallet', // Mercado Pago Chile

    // Retail
    'cl.falabella.cmr', // CMR Falabella
    'cl.ripley.tarjetaripley', // Tarjeta Ripley

    // Otros
    'cl.coopeuch.personas', // Coopeuch
    'cl.santander.superclave', // Superclave Santander
  };

  /// Mapeo de paquetes a tipos de banco
  static final Map<String, BankType> packageToBankType = {
    'cl.bancoestado.personas': BankType.bancoEstado,
    'cl.bancochile.mobilebanking': BankType.bancoDeChile,
    'cl.santander.unired': BankType.santander,
    'cl.santander.superclave': BankType.santander,
    'cl.bci.android': BankType.bci,
    'com.scotiabank.mobile.cl': BankType.scotiabank,
    'com.itau.empresas': BankType.itau,
    'com.mach.android': BankType.mach,
    'cl.tenpo.mobile': BankType.tenpo,
    'com.mercadopago': BankType.mercadoPago,
    'cl.mercadopago.wallet': BankType.mercadoPago,
    'cl.falabella.cmr': BankType.falabella,
    'cl.ripley.tarjetaripley': BankType.ripley,
    'cl.coopeuch.personas': BankType.other,
  };

  /// Verifica si un paquete está autorizado
  static bool isAuthorized(String packageName) {
    return authorizedPackages.contains(packageName);
  }

  /// Obtiene el tipo de banco desde el paquete
  static BankType getBankType(String packageName) {
    return packageToBankType[packageName] ?? BankType.other;
  }

  /// Palabras clave que indican una transacción de egreso (compra/pago)
  static const Set<String> egresoKeywords = {
    'compra',
    'compro',
    'pago',
    'cargo',
    'débito',
    'debito',
    'gastaste',
    'gastos',
    'transferencia enviada',
    'retiro',
    'consumo',
  };

  /// Palabras clave que indican una transacción de ingreso (abono/depósito)
  static const Set<String> ingresoKeywords = {
    'abono',
    'depósito',
    'deposito',
    'recibiste',
    'ingreso',
    'crédito',
    'credito',
    'transferencia recibida',
    'recarga',
    'carga',
  };
}
