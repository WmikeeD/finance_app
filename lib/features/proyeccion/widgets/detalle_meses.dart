import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/proyeccion_models.dart';

class DetalleMeses extends StatelessWidget {
  final List<MesProyeccion> meses;
  final bool incluirGastosFijos;
  final double? sueldo;
  final Function(MesProyeccion) onMesTap;

  const DetalleMeses({
    super.key,
    required this.meses,
    required this.incluirGastosFijos,
    this.sueldo,
    required this.onMesTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: meses.length,
      itemBuilder: (context, index) => _buildMesCard(context, meses[index]),
    );
  }

  Widget _buildMesCard(BuildContext context, MesProyeccion mes) {
    final scheme = Theme.of(context).colorScheme;
    final colorFlujoNeto = mes.flujoNetoMes >= 0
        ? AppTheme.incomeColor(context)
        : AppTheme.expenseColor(context);
    final colorSaldoAcumulado = mes.enDeficitAcumulado
        ? AppTheme.expenseColor(context)
        : AppTheme.incomeColor(context);

    return Card(
      margin: const EdgeInsets.all(AppSpacing.sm),
      elevation: 0,
      child: InkWell(
        onTap: () => onMesTap(mes),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header del mes con indicador de déficit
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    mes.nombreMes.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (mes.esMesLiberacion)
                    const Chip(
                      label: Text('🎉 LIBERACIÓN'),
                      backgroundColor: AppColors.alertCelebrate,
                    )
                  else if (mes.enDeficitAcumulado)
                    Chip(
                      label: const Text('⚠️ DÉFICIT'),
                      backgroundColor: AppTheme.expenseColor(context).withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: AppTheme.expenseColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),

              // ✨ SALDO INICIAL (arrastre del mes anterior)
              if (mes.saldoInicial != 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: AppRadius.smBR,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Saldo inicial en bancos',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        Formatters.monedaConSimbolo(mes.saldoInicial),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: mes.saldoInicial >= 0
                              ? AppTheme.incomeColor(context)
                              : AppTheme.expenseColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(),

              // Ingresos
              if (sueldo != null || mes.prestamosCobrar.isNotEmpty) ...[
                const Text(
                  'INGRESOS',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (sueldo != null)
                  _buildFila('Sueldo', sueldo!),
                ...mes.prestamosCobrar.map((p) => _buildFila(
                  'Préstamo ${p.nombrePersona}',
                  p.monto,
                  icon: Icons.arrow_circle_up,
                  color: AppTheme.incomeColor(context),
                )),
                _buildFila('Total ingresos', mes.totalIngresos, isTotal: true),
                const SizedBox(height: 12),
              ],

              // Egresos
              const Text(
                'EGRESOS',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              _buildFila('Cuotas tarjetas', mes.totalCuotas),
              if (incluirGastosFijos)
                _buildFila('Gastos fijos', mes.totalGastosFijos),
              _buildFila('Total egresos', mes.totalEgresos, isTotal: true),

              const Divider(),

              // ✨ FLUJO NETO DEL MES (operativo)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'FLUJO DEL MES',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                  Row(
                    children: [
                      Icon(
                        mes.flujoNetoMes >= 0 ? Icons.trending_up : Icons.trending_down,
                        color: colorFlujoNeto,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        Formatters.monedaConSimbolo(mes.flujoNetoMes),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorFlujoNeto,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ✨ SALDO FINAL ACUMULADO (liquidez estimada al cierre)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorSaldoAcumulado.withValues(alpha: 0.1),
                  borderRadius: AppRadius.mdBR,
                  border: Border.all(
                    color: colorSaldoAcumulado.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SALDO ESTIMADO EN BANCOS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Al cierre del mes',
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 3,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            mes.enDeficitAcumulado
                                ? Icons.warning_rounded
                                : Icons.account_balance_wallet,
                            color: colorSaldoAcumulado,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              Formatters.monedaConSimbolo(mes.saldoFinalAcumulado),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorSaldoAcumulado,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Desglose de cuotas
              if (mes.cuotas.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'DETALLE DE CUOTAS',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                ...mes.cuotas.map((c) => _buildCuotaTile(c)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFila(String label, double monto, {
    IconData? icon,
    Color? color,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          Text(
            Formatters.monedaConSimbolo(monto),
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCuotaTile(CuotaMes cuota) {
    return Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;

        // ✨ Cuotas simuladas: color diferenciado
        final backgroundColor = cuota.esSimulada
            ? scheme.secondaryContainer
            : scheme.surfaceContainerLowest;
        final textColor = cuota.esSimulada
            ? scheme.onSecondaryContainer
            : scheme.onSurface;
        final borderColor = cuota.esSimulada
            ? scheme.secondary.withValues(alpha: 0.3)
            : Colors.transparent;

        return Container(
          margin: const EdgeInsets.only(top: AppSpacing.xs),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: AppRadius.smBR,
            border: cuota.esSimulada
                ? Border.all(color: borderColor, width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              // ✨ Ícono de simulación
              if (cuota.esSimulada) ...[
                PhosphorIcon(
                  PhosphorIconsRegular.sparkle,
                  size: 18,
                  color: scheme.secondary,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cuota.descripcion,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${cuota.label} • Vence: ${Formatters.fecha(cuota.fechaVencimiento)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                Formatters.monedaConSimbolo(cuota.monto),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}