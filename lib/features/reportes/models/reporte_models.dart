import 'package:flutter/material.dart';

/// Resumen financiero de un período (mes, rango personalizado, etc.)
class ResumenFinanciero {
  final double ingresos;
  final double egresos;
  final double balance;
  final double tasaAhorro; // % de ahorro: ((ingresos - egresos) / ingresos) * 100
  final double? variacionIngresosVsMesAnterior; // % cambio vs mes anterior
  final double? variacionEgresosVsMesAnterior; // % cambio vs mes anterior

  const ResumenFinanciero({
    required this.ingresos,
    required this.egresos,
    required this.balance,
    required this.tasaAhorro,
    this.variacionIngresosVsMesAnterior,
    this.variacionEgresosVsMesAnterior,
  });

  /// Constructor vacío (sin movimientos)
  const ResumenFinanciero.vacio()
      : ingresos = 0,
        egresos = 0,
        balance = 0,
        tasaAhorro = 0,
        variacionIngresosVsMesAnterior = null,
        variacionEgresosVsMesAnterior = null;

  /// Calcula la tasa de ahorro a partir de ingresos y egresos
  static double calcularTasaAhorro(double ingresos, double egresos) {
    if (ingresos <= 0) return 0;
    return ((ingresos - egresos) / ingresos) * 100;
  }

  @override
  String toString() =>
      'ResumenFinanciero(ingresos: $ingresos, egresos: $egresos, balance: $balance, tasaAhorro: ${tasaAhorro.toStringAsFixed(1)}%)';
}

/// Métrica de gasto agregada por categoría
class CategoriaGastoReporte {
  final int categoriaId;
  final String nombre;
  final String color; // Hex color de la categoría
  final String? icono; // Nombre del ícono (si está definido)
  final double totalGasto;
  final double porcentajeTotal; // % del total de egresos

  const CategoriaGastoReporte({
    required this.categoriaId,
    required this.nombre,
    required this.color,
    this.icono,
    required this.totalGasto,
    required this.porcentajeTotal,
  });

  /// Convierte el color hex a Color de Flutter
  Color get colorFlutter {
    try {
      return Color(int.parse(color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  String toString() =>
      'CategoriaGastoReporte($nombre: \$${totalGasto.toStringAsFixed(0)} - ${porcentajeTotal.toStringAsFixed(1)}%)';
}

/// Métrica histórica mensual de ingresos/egresos/balance
class MesHistoricoReporte {
  final String mesKey; // Formato: "2026-08" (año-mes)
  final String nombreMes; // Formato corto: "Ago" o "Ago '26"
  final double ingresos;
  final double egresos;
  final double balance;

  const MesHistoricoReporte({
    required this.mesKey,
    required this.nombreMes,
    required this.ingresos,
    required this.egresos,
    required this.balance,
  });

  /// Parsea el mesKey a DateTime (primer día del mes)
  DateTime get fecha {
    final parts = mesKey.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
  }

  @override
  String toString() =>
      'MesHistoricoReporte($nombreMes: +\$${ingresos.toStringAsFixed(0)} / -\$${egresos.toStringAsFixed(0)} = \$${balance.toStringAsFixed(0)})';
}
