import 'package:flutter/material.dart';
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
    final colorIndicador = _getColorIndicador(mes.sobrante, mes.totalIngresos);

    return Card(
      margin: const EdgeInsets.all(AppSpacing.sm),
      child: InkWell(
        onTap: () => onMesTap(mes),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header del mes
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
                    ),
                ],
              ),
              
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
              
              // Resultado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SOBRANTE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Icon(Icons.circle, color: colorIndicador, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        Formatters.monedaConSimbolo(mes.sobrante),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorIndicador,
                        ),
                      ),
                    ],
                  ),
                ],
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
      builder: (context) => Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: AppRadius.smBR,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cuota.descripcion,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${cuota.label} • Vence: ${Formatters.fecha(cuota.fechaVencimiento)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            Formatters.monedaConSimbolo(cuota.monto),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
    );
  }

  Color _getColorIndicador(double sobrante, double ingresos) {
    if (ingresos == 0) return Colors.grey;
    final porcentaje = sobrante / ingresos;
    if (porcentaje < 0) return AppColors.alertDanger;
    if (porcentaje < 0.1) return AppColors.alertWarning;
    if (porcentaje < 0.3) return AppColors.alertCaution;
    return AppColors.alertOk;
  }
}