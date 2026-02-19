import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../../core/database/database.dart';
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
        ],
      ),
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