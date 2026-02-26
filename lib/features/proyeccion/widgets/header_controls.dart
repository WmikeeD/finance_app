import 'package:flutter/material.dart';
import '../../../core/database/database.dart';

class HeaderControls extends StatelessWidget {
  final DateTime mesInicio;
  final int? cuentaId;
  final int mesesAVer;
  final bool incluirGastosFijos;
  final double? sueldo;
  final bool incluirPrestamos;
  final Set<int> prestamosSeleccionados;
  final double? gastosFijos; 
  
  final Function(DateTime) onMesInicioChanged;
  final Function(int?) onCuentaChanged;
  final Function(int) onMesesChanged;
  final Function(double?) onSueldoChanged;
  final Function((bool, Set<int>)) onPrestamosChanged;
  final ValueChanged<double?> onGastosFijosChanged;

  final AppDatabase database;

  const HeaderControls({
    super.key,
    required this.mesInicio,
    required this.cuentaId,
    required this.mesesAVer,
    required this.incluirGastosFijos,
    required this.sueldo,
    required this.incluirPrestamos,
    required this.prestamosSeleccionados,
    required this.onMesInicioChanged,
    required this.onCuentaChanged,
    required this.onMesesChanged,
    required this.onGastosFijosChanged,
    required this.onSueldoChanged,
    required this.onPrestamosChanged,
    required this.database,
    required this.gastosFijos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: Selectores principales
          Row(
            children: [
              // Mes inicio
              Expanded(
                child: _buildDropdown<DateTime>(
                  label: 'Desde',
                  value: mesInicio,
                  items: _generarMesesInicio(),
                  onChanged: (v) => v != null ? onMesInicioChanged(v) : null,
                  displayText: (d) => '${_mesNombre(d.month)} ${d.year}',
                ),
              ),
              const SizedBox(width: 8),
              
              // Cuenta
              Expanded(
                child: StreamBuilder<List<Cuenta>>(
                  stream: database.select(database.cuentas).watch(),
                  builder: (context, snapshot) {
                    final cuentas = snapshot.data ?? [];
                    return _buildDropdown<int?>(
                      label: 'Cuenta',
                      value: cuentaId,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todas')),
                        ...cuentas.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.nombre, overflow: TextOverflow.ellipsis),
                        )),
                      ],
                      onChanged: onCuentaChanged,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              
              // Meses a ver
              Expanded(
                child: _buildDropdown<int>(
                  label: 'Meses',
                  value: mesesAVer,
                  items: List.generate(12, (i) => i + 1)
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (v) => v != null ? onMesesChanged(v) : null,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Fila 2: Checkboxes de configuración
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              // Gastos fijos
              _buildCheckbox(
                label: 'Gastos fijos',
                value: gastosFijos != null,
                onChanged: (v) => onGastosFijosChanged(v ? 0 : null),
                trailing: gastosFijos != null 
                  ? _buildMontoInput(onGastosFijosChanged)
                  : null,
              ),
              
              // Sueldo
              _buildCheckbox(
                label: 'Sueldo',
                value: sueldo != null,
                onChanged: (v) => onSueldoChanged(v ? 0 : null),
                trailing: sueldo != null
                  ? _buildMontoInput(onSueldoChanged)
                  : null,
              ),
              
              // Préstamos a cobrar
              _buildPrestamosCheckbox(),
            ],
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
    String Function(T)? displayText,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Widget _buildCheckbox({
    required String label,
    required bool value,
    required Function(bool) onChanged,
    Widget? trailing,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
        ),
        Text(label),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          SizedBox(width: 100, child: trailing),
        ],
      ],
    );
  }

  Widget _buildMontoInput(ValueChanged<double?> onChanged) {
    return TextField(
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        prefixText: '\$ ',
        isDense: true,
      ),
      onChanged: (v) => onChanged(double.tryParse(v)),
    );
  }

  Widget _buildPrestamosCheckbox() {
    return PopupMenuButton<bool>(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: incluirPrestamos,
            onChanged: null, // Controlado por el popup
          ),
          const Text('Préstamos'),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
      itemBuilder: (context) => [
        // Aquí iría la lista de préstamos pendientes
        PopupMenuItem(
          child: StreamBuilder<List<Deuda>>(
            stream: (database.select(database.deudas)
                  ..where((d) => d.estado.isNotIn(['pagada'])))
                .watch(),
            builder: (context, snapshot) {
              final deudas = snapshot.data ?? [];
              if (deudas.isEmpty) {
                return const Text('No hay préstamos pendientes');
              }
              return Column(
                children: deudas.map((d) => CheckboxListTile(
                  title: Text('Deuda #${d.id}'),
                  subtitle: Text('\$${d.montoPendiente}'),
                  value: prestamosSeleccionados.contains(d.id),
                  onChanged: (v) {
                    final nuevoSet = Set<int>.from(prestamosSeleccionados);
                    if (v == true) {
                      nuevoSet.add(d.id);
                    } else {
                      nuevoSet.remove(d.id);
                    }
                    onPrestamosChanged((nuevoSet.isNotEmpty, nuevoSet));
                  },
                )).toList(),
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
    // Asegurar día 1, sin hora
    final mes = DateTime(ahora.year, ahora.month + i, 1);
    return DropdownMenuItem(
      value: mes,
      child: Text('${_mesNombre(mes.month)} ${mes.year}'),
    );
  });
}

  String _mesNombre(int mes) {
    const meses = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return meses[mes - 1];
  }
}