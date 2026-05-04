import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../models/proyeccion_models.dart';

class GraficoBarras extends StatelessWidget {
  final List<MesProyeccion> meses;
  final double? sueldo;
  final bool incluirGastosFijos;
  final Function(MesProyeccion) onMesSeleccionado;

  const GraficoBarras({
    super.key,
    required this.meses,
    this.sueldo,
    required this.incluirGastosFijos,
    required this.onMesSeleccionado,
  });

  @override
  Widget build(BuildContext context) {
    if (meses.isEmpty) {
      return const Center(child: Text('No hay datos para mostrar'));
    }

    final maxValor = _calcularMaxValor();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Leyenda
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLeyenda('Cuotas', Colors.blue),
              const SizedBox(width: 16),
              if (incluirGastosFijos) _buildLeyenda('Fijos', Colors.grey),
              if (sueldo != null) ...[
                const SizedBox(width: 16),
                _buildLeyenda('Sueldo', Colors.red, isLinea: true),
              ],
            ],
          ),
          const SizedBox(height: 16),
          
          // Gráfico
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: meses.map((mes) => _buildBarra(mes, maxValor)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeyenda(String label, Color color, {bool isLinea = false}) {
    return Row(
      children: [
        Container(
          width: 16,
          height: isLinea ? 2 : 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildBarra(MesProyeccion mes, double maxValor) {
    final alturaCuotas = ((mes.totalCuotas / maxValor) * 200).toDouble();
    final alturaFijos = incluirGastosFijos 
        ? ((mes.totalGastosFijos / maxValor) * 200).toDouble()
        : 0.0;
    final alturaSueldo = sueldo != null 
        ? ((sueldo! / maxValor) * 200).toDouble()
        : 0.0;

    final esLiberacion = mes.esMesLiberacion;

    return GestureDetector(
      onTap: () => onMesSeleccionado(mes),
      child: Container(
        width: 60,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Monto encima
            Text(
              Formatters.moneda(mes.totalCuotas + mes.totalGastosFijos),
              style: const TextStyle(fontSize: 10),
            ),
            const SizedBox(height: 4),
            
            // Barras
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Línea de sueldo
                if (sueldo != null)
                  Container(
                    width: 50,
                    height: 2,
                    color: Colors.red,
                    margin: EdgeInsets.only(bottom: alturaSueldo),
                  ),
                
                // Barra de gastos fijos
                if (incluirGastosFijos)
                  Container(
                    width: 40,
                    height: alturaFijos,
                    color: Colors.grey[400],
                  ),
                
                // Barra de cuotas
                Container(
                  width: 40,
                  height: alturaCuotas,
                  decoration: BoxDecoration(
                    color: esLiberacion ? Colors.amber : Colors.blue,
                    border: esLiberacion 
                        ? Border.all(color: Colors.orange, width: 2)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: esLiberacion 
                      ? const Center(child: Text('★', style: TextStyle(fontSize: 20)))
                      : null,
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Mes abajo
            Text(
              mes.nombreMes,
              style: TextStyle(
                fontSize: 12,
                fontWeight: esLiberacion ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calcularMaxValor() {
    double max = 0;
    for (final mes in meses) {
      final total = mes.totalCuotas + mes.totalGastosFijos;
      if (total > max) max = total;
    }
    if (sueldo != null && sueldo! > max) max = sueldo!;
    return max == 0 ? 1 : max * 1.1;
  }
}