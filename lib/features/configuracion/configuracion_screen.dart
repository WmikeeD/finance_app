import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../../core/database/database.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_drawer.dart';

class ConfiguracionScreen extends StatefulWidget {
  final AppDatabase database;
  
  const ConfiguracionScreen({super.key, required this.database});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      drawer: AppDrawer(
        database: widget.database,
        currentRoute: '/settings',
      ),
      body: StreamBuilder<Perfil?>(
        stream: widget.database.select(widget.database.perfiles).watch().map(
          (perfiles) => perfiles.isEmpty ? null : perfiles.first,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final perfil = snapshot.data;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildPerfilSection(perfil),
              const SizedBox(height: 24),
              _buildPreferenciasSection(perfil),
              const SizedBox(height: 24),
              _buildColorDinamicoSection(perfil),
              const SizedBox(height: 24),
              _buildNotificacionesSection(perfil),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPerfilSection(Perfil? perfil) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                const Text(
                  'Perfil de Usuario',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: const Text('Nombre'),
            subtitle: Text(perfil?.nombre ?? 'No configurado'),
            trailing: const Icon(Icons.edit),
            onTap: () => _showEditNombreDialog(perfil),
          ),
          ListTile(
            leading: const Icon(Icons.cake),
            title: const Text('Fecha de Nacimiento'),
            subtitle: Text(
              perfil?.fechaNacimiento != null
                  ? _dateFormat.format(perfil!.fechaNacimiento!)
                  : 'No configurado',
            ),
            trailing: const Icon(Icons.edit),
            onTap: () => _showEditFechaNacimientoDialog(perfil),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenciasSection(Perfil? perfil) {
    final colorActual = perfil?.colorPrimario ?? '#6C63FF';
    
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.palette, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                const Text(
                  'Preferencias de la App',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(int.parse(colorActual.replaceFirst('#', '0xFF'))),
                shape: BoxShape.circle,
              ),
            ),
            title: const Text('Color Principal'),
            subtitle: Text(colorActual.toUpperCase()),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showColorPickerDialog(perfil),
          ),
          const Divider(height: 1),
          _buildTemaToggle(perfil),
        ],
      ),
    );
  }

  // ── Sección color dinámico ─────────────────────────────────────────────

  Widget _buildTemaToggle(Perfil? perfil) {
    final temaOscuro = perfil?.temaOscuro;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                temaOscuro == null
                    ? Icons.brightness_auto
                    : temaOscuro
                        ? Icons.dark_mode
                        : Icons.light_mode,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Text('Tema de la aplicación',
                  style: TextStyle(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<bool?>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Claro'),
                icon: Icon(Icons.light_mode, size: 18),
              ),
              ButtonSegment(
                value: null,
                label: Text('Sistema'),
                icon: Icon(Icons.brightness_auto, size: 18),
              ),
              ButtonSegment(
                value: true,
                label: Text('Oscuro'),
                icon: Icon(Icons.dark_mode, size: 18),
              ),
            ],
            selected: {temaOscuro},
            onSelectionChanged: (seleccion) async {
              await widget.database.guardarPerfil(
                PerfilesCompanion(
                  temaOscuro: drift.Value(seleccion.first),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildColorDinamicoSection(Perfil? perfil) {
    final activado = perfil?.colorDinamico ?? false;
    final minimo = perfil?.balanceMinimo ?? 100000.0;
    final maximo = perfil?.balanceMaximo ?? 50000000.0;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.auto_awesome,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                const Text(
                  'Color Dinámico',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Toggle activar/desactivar
          SwitchListTile(
            secondary: const Icon(Icons.palette_outlined),
            title: const Text('Activar color dinámico'),
            subtitle: Text(
              activado
                  ? 'El color se adapta automáticamente a tu balance'
                  : 'Se usa el color seleccionado manualmente',
              style: const TextStyle(fontSize: 12),
            ),
            value: activado,
            onChanged: (v) async {
              await widget.database.guardarPerfil(
                PerfilesCompanion(colorDinamico: drift.Value(v)),
              );
            },
          ),

          if (activado) ...[
            const Divider(height: 1),

            // Preview con balance actual
            _buildColorDinamicoPreview(minimo, maximo),

            const Divider(height: 1),

            // Explicación de zonas
            _buildZonasExplicacion(),

            const Divider(height: 1),

            // Configurar límites
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LÍMITES DE BALANCE',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _buildLimiteField(
                    label: 'Balance mínimo (precaución)',
                    valor: minimo,
                    icono: Icons.warning_amber,
                    color: Colors.red,
                    onSave: (v) => widget.database.guardarPerfil(
                      PerfilesCompanion(balanceMinimo: drift.Value(v)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLimiteField(
                    label: 'Balance máximo (meta)',
                    valor: maximo,
                    icono: Icons.emoji_events,
                    color: const Color(0xFFFFB300),
                    onSave: (v) => widget.database.guardarPerfil(
                      PerfilesCompanion(balanceMaximo: drift.Value(v)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColorDinamicoPreview(double minimo, double maximo) {
    return StreamBuilder<List<Cuenta>>(
      stream: widget.database.select(widget.database.cuentas).watch(),
      builder: (_, snap) {
        final cuentas = snap.data ?? [];
        final balance = cuentas
            .where((c) => c.tipo == 'efectivo' || c.tipo == 'debito')
            .fold<double>(0, (s, c) => s + c.saldo);

        final color = AppTheme.calcularColorDinamico(balance, minimo, maximo);
        final zona = AppTheme.nombreZonaDinamica(balance, minimo, maximo);
        final pct = balance >= maximo
            ? 1.0
            : balance <= 0
                ? 0.0
                : ((balance - 0) / maximo).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ESTADO ACTUAL',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Formatters.monedaConSimbolo(balance),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          zona,
                          style: TextStyle(
                              fontSize: 13,
                              color: color,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(Formatters.monedaConSimbolo(0),
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(Formatters.monedaConSimbolo(maximo),
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildZonasExplicacion() {
    final zonas = [
      (Colors.red[900]!, 'Negativo', 'Balance negativo — atención urgente'),
      (Colors.orange, 'Precaución', 'Por debajo del mínimo configurado'),
      (Colors.green, 'Estable', 'Entre el mínimo y la mitad de la meta'),
      (Colors.teal, 'Cómodo', 'Superando la mitad de la meta'),
      (const Color(0xFFFFB300), 'Meta alcanzada', 'Balance supera el máximo objetivo'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ZONAS DE COLOR',
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          ...zonas.map(
            (z) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                        color: z.$1, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Text(z.$2,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '— ${z.$3}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimiteField({
    required String label,
    required double valor,
    required IconData icono,
    required Color color,
    required Future<void> Function(double) onSave,
  }) {
    final ctrl = TextEditingController(text: valor.toStringAsFixed(0));

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icono, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: label,
              prefixText: '\$ ',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onEditingComplete: () {
              final v = double.tryParse(ctrl.text);
              if (v != null && v > 0) onSave(v);
            },
          ),
        ),
      ],
    );
  }

  // ── Sección notificaciones ─────────────────────────────────────────────────

  Widget _buildNotificacionesSection(Perfil? perfil) {
    return FutureBuilder<bool>(
      future: NotificationService.tienePermiso(),
      builder: (_, snap) {
        final tienePermiso = snap.data ?? false;

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.notifications,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    const Text(
                      'Notificaciones',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (!tienePermiso) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notifications_off, color: Colors.grey[500]),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Permiso no concedido. Habilita las notificaciones para recibir recordatorios de pagos.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.notification_add),
                        label: const Text('Solicitar permiso'),
                        onPressed: () async {
                          await NotificationService.solicitarPermiso();
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ] else ...[
                SwitchListTile(
                  secondary: const Icon(Icons.credit_card),
                  title: const Text('Recordar cuotas por vencer'),
                  subtitle: const Text(
                    'Alerta antes del vencimiento de cuotas de crédito',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: perfil?.notifCuotas ?? true,
                  onChanged: (v) async {
                    await widget.database.guardarPerfil(
                      PerfilesCompanion(notifCuotas: drift.Value(v)),
                    );
                    await NotificationService.programarNotificaciones(
                        widget.database);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.receipt_long),
                  title: const Text('Recordar gastos fijos'),
                  subtitle: const Text(
                    'Alerta antes del vencimiento de gastos fijos activos',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: perfil?.notifGastosFijos ?? true,
                  onChanged: (v) async {
                    await widget.database.guardarPerfil(
                      PerfilesCompanion(notifGastosFijos: drift.Value(v)),
                    );
                    await NotificationService.programarNotificaciones(
                        widget.database);
                  },
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildDiasAntesField(perfil),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiasAntesField(Perfil? perfil) {
    final dias = perfil?.notifDiasAntes ?? 3;
    return Row(
      children: [
        const Icon(Icons.schedule, size: 20),
        const SizedBox(width: 12),
        const Expanded(
          child: Text('Días de anticipación para las alertas'),
        ),
        DropdownButton<int>(
          value: dias,
          items: [1, 2, 3, 5, 7]
              .map((d) => DropdownMenuItem(
                    value: d,
                    child: Text('$d día${d > 1 ? 's' : ''}'),
                  ))
              .toList(),
          onChanged: (v) async {
            if (v == null) return;
            await widget.database.guardarPerfil(
              PerfilesCompanion(notifDiasAntes: drift.Value(v)),
            );
            await NotificationService.programarNotificaciones(widget.database);
          },
        ),
      ],
    );
  }

  void _showEditNombreDialog(Perfil? perfil) {
    final controller = TextEditingController(text: perfil?.nombre ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Nombre'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Tu nombre',
            hintText: 'Ej: Juan Pérez',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await widget.database.guardarPerfil(
                PerfilesCompanion(
                  nombre: drift.Value(controller.text.isEmpty ? null : controller.text),
                ),
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nombre actualizado')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditFechaNacimientoDialog(Perfil? perfil) async {
    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: perfil?.fechaNacimiento ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Selecciona tu fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Guardar',
    );

    if (fechaSeleccionada != null && mounted) {
      await widget.database.guardarPerfil(
        PerfilesCompanion(
          fechaNacimiento: drift.Value(fechaSeleccionada),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fecha de nacimiento actualizada')),
        );
      }
    }
  }

  void _showColorPickerDialog(Perfil? perfil) {
    final coloresDisponibles = [
      {'nombre': 'Púrpura (Predeterminado)', 'hex': '#6C63FF'},
      {'nombre': 'Azul', 'hex': '#2196F3'},
      {'nombre': 'Índigo', 'hex': '#3F51B5'},
      {'nombre': 'Teal', 'hex': '#009688'},
      {'nombre': 'Verde', 'hex': '#4CAF50'},
      {'nombre': 'Naranja', 'hex': '#FF9800'},
      {'nombre': 'Rojo', 'hex': '#F44336'},
      {'nombre': 'Rosa', 'hex': '#E91E63'},
      {'nombre': 'Morado', 'hex': '#9C27B0'},
      {'nombre': 'Cyan', 'hex': '#00BCD4'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecciona un Color'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: coloresDisponibles.length,
            itemBuilder: (context, index) {
              final color = coloresDisponibles[index];
              final hexColor = color['hex']!;
              final isSelected = hexColor == (perfil?.colorPrimario ?? '#6C63FF');
              
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(int.parse(hexColor.replaceFirst('#', '0xFF'))),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.black, width: 3)
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
                title: Text(color['nombre']!),
                subtitle: Text(hexColor),
                onTap: () async {
                  await widget.database.guardarPerfil(
                    PerfilesCompanion(
                      colorPrimario: drift.Value(hexColor),
                    ),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    
                    // Mostrar diálogo informativo
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Color Actualizado'),
                        content: const Text(
                          'El color se aplicará cuando reinicies la aplicación.',
                        ),
                        actions: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Entendido'),
                          ),
                        ],
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}