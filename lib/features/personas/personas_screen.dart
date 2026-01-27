import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/database.dart';
import '../../core/widgets/app_drawer.dart';

class PersonasScreen extends StatefulWidget {
  final AppDatabase database;
  
  const PersonasScreen({super.key, required this.database});

  @override
  State<PersonasScreen> createState() => _PersonasScreenState();
}

class _PersonasScreenState extends State<PersonasScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Personas'),
      ),
      drawer: AppDrawer(
        database: widget.database,
        currentRoute: '/personas',
      ),
      body: StreamBuilder<List<Persona>>(
        stream: widget.database.select(widget.database.personas).watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final personas = snapshot.data ?? [];

          if (personas.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: personas.length,
            itemBuilder: (context, index) {
              final persona = personas[index];
              return _buildPersonaCard(persona);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPersonaDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Persona'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay personas registradas',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Registra personas para gestionar préstamos',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddPersonaDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Agregar Persona'),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaCard(Persona persona) {
    Color personaColor = Color(int.parse(persona.color.replaceFirst('#', '0xFF')));
    String iniciales = persona.avatar ?? _getIniciales(persona.nombre);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: personaColor,
          child: Text(
            iniciales,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          persona.nombre,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (persona.relacion != null)
              Text(
                persona.relacion!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            if (persona.telefono != null)
              Row(
                children: [
                  Icon(Icons.phone, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    persona.telefono!,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showEditPersonaDialog(persona),
        ),
      ),
    );
  }

  String _getIniciales(String nombre) {
    final palabras = nombre.trim().split(' ');
    if (palabras.isEmpty) return '??';
    if (palabras.length == 1) {
      return palabras[0].substring(0, 1).toUpperCase();
    }
    return (palabras[0].substring(0, 1) + palabras[1].substring(0, 1)).toUpperCase();
  }

  void _showAddPersonaDialog() {
    final nombreController = TextEditingController();
    final telefonoController = TextEditingController();
    final relacionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Persona'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  hintText: 'Ej: Juan Pérez',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: relacionController,
                decoration: const InputDecoration(
                  labelText: 'Relación (opcional)',
                  hintText: 'Ej: Hermano, Amigo',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: telefonoController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (opcional)',
                  hintText: 'Ej: +56 9 1234 5678',
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nombreController.text.isNotEmpty) {
                final iniciales = _getIniciales(nombreController.text);
                
                await widget.database.into(widget.database.personas).insert(
                  PersonasCompanion.insert(
                    nombre: nombreController.text,
                    telefono: telefonoController.text.isEmpty 
                        ? const drift.Value(null) 
                        : drift.Value(telefonoController.text),
                    relacion: relacionController.text.isEmpty 
                        ? const drift.Value(null) 
                        : drift.Value(relacionController.text),
                    avatar: drift.Value(iniciales),
                  ),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Persona registrada exitosamente')),
                  );
                }
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showEditPersonaDialog(Persona persona) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(persona.nombre),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (persona.relacion != null)
              Text('Relación: ${persona.relacion}'),
            if (persona.telefono != null)
              Text('Teléfono: ${persona.telefono}'),
            if (persona.email != null)
              Text('Email: ${persona.email}'),
            if (persona.notas != null)
              Text('Notas: ${persona.notas}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () async {
              await (widget.database.delete(widget.database.personas)
                    ..where((p) => p.id.equals(persona.id)))
                  .go();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Persona eliminada')),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}