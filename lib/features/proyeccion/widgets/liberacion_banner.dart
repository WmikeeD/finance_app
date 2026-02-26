import 'package:flutter/material.dart';
import '../models/proyeccion_models.dart';

class LiberacionBannerDelegate extends SliverPersistentHeaderDelegate {
  final MesLiberacion mesLiberacion;

  LiberacionBannerDelegate({required this.mesLiberacion});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.celebration, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🎉 LIBERACIÓN: ${mesLiberacion.fecha.month}/${mesLiberacion.fecha.year}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Última: ${mesLiberacion.descripcionUltima} - \$${mesLiberacion.montoUltima}',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Chip(
            label: Text('Faltan ${mesLiberacion.mesesFaltantes}'),
            backgroundColor: Colors.amber[100],
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 70;

  @override
  double get minExtent => 70;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}