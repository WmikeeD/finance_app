/// Representa un mes proyectado con todos sus datos
class MesProyeccion {
  final DateTime fecha;
  final double totalCuotas;
  final double totalGastosFijos;
  final double totalIngresos;
  final double totalEgresos;
  @Deprecated('Use flujoNetoMes instead') final double sobrante;
  final List<CuotaMes> cuotas;
  final List<PrestamoCobro> prestamosCobrar;

  // ✨ NUEVOS CAMPOS - Motor de Arrastre de Liquidez
  /// Saldo acumulado con el que inicia el mes (arrastre del mes anterior)
  final double saldoInicial;

  /// Flujo neto del mes = totalIngresos - totalEgresos (operativo del mes)
  final double flujoNetoMes;

  /// Saldo final acumulado = saldoInicial + flujoNetoMes
  /// Representa el saldo estimado en cuentas bancarias al cierre del mes
  final double saldoFinalAcumulado;

  /// Indica si el mes cierra con déficit acumulado (saldoFinalAcumulado < 0)
  final bool enDeficitAcumulado;

  MesProyeccion({
    required this.fecha,
    required this.totalCuotas,
    this.totalGastosFijos = 0,
    this.totalIngresos = 0,
    required this.totalEgresos,
    @Deprecated('Use flujoNetoMes instead') this.sobrante = 0,
    required this.cuotas,
    this.prestamosCobrar = const [],
    this.saldoInicial = 0,
    double? flujoNetoMes,
    double? saldoFinalAcumulado,
    bool? enDeficitAcumulado,
  })  : flujoNetoMes = flujoNetoMes ?? (totalIngresos - totalEgresos),
        saldoFinalAcumulado = saldoFinalAcumulado ??
            ((flujoNetoMes ?? (totalIngresos - totalEgresos)) + (saldoInicial)),
        enDeficitAcumulado = enDeficitAcumulado ??
            (((flujoNetoMes ?? (totalIngresos - totalEgresos)) + saldoInicial) < 0);

  String get nombreMes => '${_mesNombre(fecha.month)} ${fecha.year}';
  bool get esMesLiberacion => cuotas.isEmpty && totalCuotas == 0;

  /// Retorna true si el flujo operativo del mes es positivo (ingresos > egresos)
  bool get tieneFlujoPositivo => flujoNetoMes > 0;

  /// Retorna true si el saldo acumulado permite cubrir los egresos del mes
  bool get tieneLiquidezSuficiente => saldoFinalAcumulado >= 0;

  static String _mesNombre(int mes) {
    const meses = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return meses[mes - 1];
  }
}

class CuotaMes {
  final String descripcion;
  final int numeroCuota;
  final int totalCuotas;
  final double monto;
  final DateTime fechaVencimiento;
  final String nombreTarjeta;
  final int transaccionId;
  final bool esSimulada; // ✨ Identifica cuotas simuladas vs reales

  CuotaMes({
    required this.descripcion,
    required this.numeroCuota,
    required this.totalCuotas,
    required this.monto,
    required this.fechaVencimiento,
    required this.nombreTarjeta,
    required this.transaccionId,
    this.esSimulada = false,
  });

  String get label => 'Cuota $numeroCuota/$totalCuotas';
}

class PrestamoCobro {
  final int personaId;
  final String nombrePersona;
  final double monto;
  final DateTime? fechaEsperada;
  
  PrestamoCobro({
    required this.personaId,
    required this.nombrePersona,
    required this.monto,
    this.fechaEsperada,
  });
}

class MesLiberacion {
  final DateTime fecha;
  final String descripcionUltima;
  final double montoUltima;
  final String tarjetaUltima;
  final int mesesFaltantes;

  MesLiberacion({
    required this.fecha,
    required this.descripcionUltima,
    required this.montoUltima,
    required this.tarjetaUltima,
    required this.mesesFaltantes,
  });
}

/// Datos completos de una proyección de cuotas
class ProyeccionData {
  final List<MesProyeccion> meses;
  final MesLiberacion? liberacion;

  ProyeccionData({required this.meses, this.liberacion});
}