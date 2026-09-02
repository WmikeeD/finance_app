import 'package:flutter/material.dart';
import '../../../core/database/database.dart';
import '../../../core/utils/formatters.dart';

class HeaderControls extends StatelessWidget {
  final DateTime mesInicio;
  final int? cuentaId;
  final int mesesAVer;
  final bool incluirGastosFijos;
  final bool incluirIngresosRecurrentes;
  final bool incluirPrestamos;
  final Set<int> prestamosSeleccionados;

  final Function(DateTime) onMesInicioChanged;
  final Function(int?) onCuentaChanged;
  final Function(int) onMesesChanged;
  final ValueChanged<bool> onGastosFijosChanged;
  final ValueChanged<bool> onIngresosRecurrentesChanged;
  final Function((bool, Set<int>)) onPrestamosChanged;

  final AppDatabase database;

  const HeaderControls({
    super.key,
    required this.mesInicio,
    required this.cuentaId,
    required this.mesesAVer,
    required this.incluirGastosFijos,
    required this.incluirIngresosRecurrentes,
    required this.incluirPrestamos,
    required this.prestamosSeleccionados,
    required this.onMesInicioChanged,
    required this.onCuentaChanged,
    required this.onMesesChanged,
    required this.onGastosFijosChanged,
    required this.onIngresosRecurrentesChanged,
    required this.onPrestamosChanged,
    required this.database,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 12),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: Selectores principales
          Row(
            children: [
              Expanded(
                child: _buildDropdown<DateTime>(
                  label: 'Desde',
                  value: mesInicio,
                  items: _generarMesesInicio(),
                  onChanged: (v) => v != null ? onMesInicioChanged(v) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StreamBuilder<List<Cuenta>>(
                  stream: database.select(database.cuentas).watch(),
                  builder: (context, snapshot) {
                    final cuentas = snapshot.data ?? [];
                    return _buildDropdown<int?>(
                      label: 'Cuenta',
                      value: cuentaId,
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Todas')),
                        ...cuentas.map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.nombre,
                                  overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: onCuentaChanged,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropdown<int>(
                  label: 'Meses',
                  value: mesesAVer,
                  items: List.generate(12, (i) => i + 1)
                      .map((n) =>
                          DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (v) => v != null ? onMesesChanged(v) : null,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Fila 2: Opciones adicionales
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Gastos fijos (auto-carga desde DB)
                StreamBuilder<List<GastoFijo>>(
                  stream: database.watchGastosFijos(soloActivos: true),
                  builder: (context, snapshot) {
                    final gastos = snapshot.data ?? [];
                    final total =
                        gastos.fold<double>(0, (s, g) => s + g.monto);
                    final hayGastos = gastos.isNotEmpty;

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: incluirGastosFijos && hayGastos,
                          onChanged: hayGastos
                              ? (v) => onGastosFijosChanged(v ?? false)
                              : null,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Gastos fijos',
                              style: TextStyle(
                                color: hayGastos ? null : Colors.grey,
                              ),
                            ),
                            if (hayGastos)
                              Text(
                                Formatters.monedaConSimbolo(total),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              )
                            else
                              const Text(
                                'Sin registros',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),
                      ],
                    );
                  },
                ),

                // Ingresos recurrentes (auto-carga desde DB)
                StreamBuilder<List<IngresoRecurrente>>(
                  stream: (database.select(database.ingresosRecurrentes)
                        ..where((i) => i.activo.equals(true))
                        ..where((i) => i.deletedAt.isNull()))
                      .watch(),
                  builder: (context, snapshot) {
                    final ingresos = snapshot.data ?? [];
                    final total = ingresos.fold<double>(0, (s, i) => s + i.monto);
                    final hayIngresos = ingresos.isNotEmpty;

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: incluirIngresosRecurrentes && hayIngresos,
                          onChanged: hayIngresos
                              ? (v) => onIngresosRecurrentesChanged(v ?? false)
                              : null,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ingresos recurrentes',
                              style: TextStyle(
                                color: hayIngresos ? null : Colors.grey,
                              ),
                            ),
                            if (hayIngresos)
                              Text(
                                Formatters.monedaConSimbolo(total),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              )
                            else
                              const Text(
                                'Sin registros',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),
                      ],
                    );
                  },
                ),

                // Préstamos a cobrar
                _buildPrestamosCheckbox(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required Function(T?) onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildPrestamosCheckbox() {
    return PopupMenuButton<bool>(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: incluirPrestamos,
            onChanged: null,
          ),
          const Text('Préstamos'),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: StreamBuilder<List<Deuda>>(
            stream: (database.select(database.deudas)
                  ..where((d) => d.estado.isNotIn(['pagada'])))
                .watch(),
            builder: (context, snapshot) {
              final deudas = snapshot.data ?? [];
              if (deudas.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('No hay préstamos pendientes'),
                );
              }
              return Column(
                children: deudas
                    .map((d) => CheckboxListTile(
                          dense: true,
                          title: Text('Deuda #${d.id}'),
                          subtitle:
                              Text(Formatters.monedaConSimbolo(d.montoPendiente)),
                          value: prestamosSeleccionados.contains(d.id),
                          onChanged: (v) {
                            final nuevoSet =
                                Set<int>.from(prestamosSeleccionados);
                            if (v == true) {
                              nuevoSet.add(d.id);
                            } else {
                              nuevoSet.remove(d.id);
                            }
                            onPrestamosChanged(
                                (nuevoSet.isNotEmpty, nuevoSet));
                          },
                        ))
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  List<DropdownMenuItem<DateTime>> _generarMesesInicio() {
    final ahora = DateTime.now();
    return List.generate(12, (i) {
      final mes = DateTime(ahora.year, ahora.month + i, 1);
      return DropdownMenuItem(
        value: mes,
        child: Text('${_mesNombre(mes.month)} ${mes.year}'),
      );
    });
  }

  String _mesNombre(int mes) {
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return meses[mes - 1];
  }
}
