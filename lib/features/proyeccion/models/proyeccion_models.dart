/// Representa un mes proyectado con todos sus datos
class MesProyeccion {
  final DateTime fecha;
  final double totalCuotas;
  final double totalGastosFijos;
  final double totalIngresos;
  final double totalEgresos;
  final double sobrante;
  final List<CuotaMes> cuotas;
  final List<PrestamoCobro> prestamosCobrar;
  
  MesProyeccion({
    required this.fecha,
    required this.totalCuotas,
    this.totalGastosFijos = 0,
    this.totalIngresos = 0,
    required this.totalEgresos,
    required this.sobrante,
    required this.cuotas,
    this.prestamosCobrar = const [],
  });
  
  String get nombreMes => '${_mesNombre(fecha.month)} ${fecha.year}';
  bool get esMesLiberacion => cuotas.isEmpty && totalCuotas == 0;
  
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
  
  CuotaMes({
    required this.descripcion,
    required this.numeroCuota,
    required this.totalCuotas,
    required this.monto,
    required this.fechaVencimiento,
    required this.nombreTarjeta,
    required this.transaccionId,
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