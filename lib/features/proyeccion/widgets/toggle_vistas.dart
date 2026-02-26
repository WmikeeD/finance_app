import 'package:flutter/material.dart';

class ToggleVistas extends StatelessWidget {
  final bool mostrarGrafico;
  final bool mostrarDetalle;
  final Function(bool) onGraficoChanged;
  final Function(bool) onDetalleChanged;
  final VoidCallback onPantallaCompleta;

  const ToggleVistas({
    super.key,
    required this.mostrarGrafico,
    required this.mostrarDetalle,
    required this.onGraficoChanged,
    required this.onDetalleChanged,
    required this.onPantallaCompleta,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          // Toggle Gráfico
          FilterChip(
            label: const Text('📊 Gráfico'),
            selected: mostrarGrafico,
            onSelected: (v) {
              if (!v && !mostrarDetalle) return; // No ocultar ambos
              onGraficoChanged(v);
            },
          ),
          const SizedBox(width: 8),
          
          // Toggle Detalle
          FilterChip(
            label: const Text('📋 Detalle'),
            selected: mostrarDetalle,
            onSelected: (v) {
              if (!v && !mostrarGrafico) return; // No ocultar ambos
              onDetalleChanged(v);
            },
          ),
          const Spacer(),
          
          // Pantalla completa
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: onPantallaCompleta,
            tooltip: 'Pantalla completa',
          ),
        ],
      ),
    );
  }
}