/// Modelos para simulación de compras en cuotas
///
/// Permite probar escenarios hipotéticos sin afectar la base de datos real.
library;

/// Representa una compra simulada en cuotas
class CompraSimulada {
  /// Descripción de la compra (ej. "PlayStation 5", "Smart TV")
  final String descripcion;

  /// Monto total de la compra
  final double montoTotal;

  /// Número de cuotas (de 1 a 48)
  final int cantidadCuotas;

  /// Mes de inicio del cobro de la primera cuota
  final DateTime mesInicio;

  CompraSimulada({
    required this.descripcion,
    required this.montoTotal,
    required this.cantidadCuotas,
    required this.mesInicio,
  }) : assert(cantidadCuotas > 0 && cantidadCuotas <= 48,
            'Las cuotas deben estar entre 1 y 48');

  /// Monto de cada cuota = montoTotal / cantidadCuotas
  double get montoCuota => montoTotal / cantidadCuotas;

  /// Fecha de la última cuota
  DateTime get mesFin => DateTime(
        mesInicio.year,
        mesInicio.month + cantidadCuotas - 1,
        1,
      );

  /// Verifica si una fecha cae dentro del rango de cuotas
  bool aplicaEnMes(DateTime mes) {
    final mesNormalizado = DateTime(mes.year, mes.month, 1);
    final inicioNormalizado = DateTime(mesInicio.year, mesInicio.month, 1);
    final finNormalizado = DateTime(mesFin.year, mesFin.month, 1);

    return !mesNormalizado.isBefore(inicioNormalizado) &&
        !mesNormalizado.isAfter(finNormalizado);
  }

  /// Obtiene el número de cuota para un mes dado (1-indexed)
  /// Retorna null si el mes está fuera del rango
  int? getNumeroCuotaEnMes(DateTime mes) {
    if (!aplicaEnMes(mes)) return null;

    final mesNormalizado = DateTime(mes.year, mes.month, 1);
    final inicioNormalizado = DateTime(mesInicio.year, mesInicio.month, 1);

    final mesesDiferencia =
        (mesNormalizado.year - inicioNormalizado.year) * 12 +
            (mesNormalizado.month - inicioNormalizado.month);

    return mesesDiferencia + 1;
  }

  @override
  String toString() =>
      '$descripcion: ${cantidadCuotas}x de \$${montoCuota.toStringAsFixed(0)}';
}

/// Impacto de una simulación sobre la proyección de liquidez
class ImpactoSimulacion {
  /// Nombres de los meses donde el saldo final acumulado cae a < 0
  final List<String> mesesConDeficit;

  /// El menor saldo proyectado en toda la simulación
  final double menorSaldoProyectado;

  /// Diferencia entre el menor saldo con la compra vs sin la compra
  final double diferenciaTotalLiquidez;

  /// Si la compra es viable (no causa déficit en ningún mes)
  final bool esViable;

  /// Primer mes en que se gatilla déficit (si existe)
  final String? primerMesDeficit;

  ImpactoSimulacion({
    required this.mesesConDeficit,
    required this.menorSaldoProyectado,
    required this.diferenciaTotalLiquidez,
  })  : esViable = mesesConDeficit.isEmpty,
        primerMesDeficit =
            mesesConDeficit.isNotEmpty ? mesesConDeficit.first : null;

  /// Mensaje descriptivo del impacto
  String get mensajeImpacto {
    if (esViable) {
      if (menorSaldoProyectado > 0) {
        return 'Tu liquidez resiste esta compra. Saldo mínimo proyectado: \$${menorSaldoProyectado.toStringAsFixed(0)}';
      } else {
        return 'Compra viable sin causar déficit adicional';
      }
    } else {
      final meses = mesesConDeficit.length;
      return 'Atención: Esta compra causa déficit en $meses ${meses == 1 ? "mes" : "meses"} (${primerMesDeficit!} y siguientes)';
    }
  }

  /// Nivel de alerta (ok, warning, danger)
  AlertLevel get nivelAlerta {
    if (esViable) {
      if (menorSaldoProyectado > 100000) {
        return AlertLevel.ok;
      } else {
        return AlertLevel.warning; // Viable pero ajustado
      }
    } else {
      return AlertLevel.danger;
    }
  }
}

/// Nivel de alerta para el impacto
enum AlertLevel {
  ok,
  warning,
  danger,
}
