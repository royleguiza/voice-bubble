import 'package:flutter/material.dart';
import '../models/credential.dart';
import '../services/storage_service.dart';

/// Tab "Claves": sección propia de credenciales para relleno desde el
/// teclado. No mezclada con el resto de opciones.
///
/// Reglas de producto (mockup laboratorio_ui/credentials_lab.html):
/// - La contraseña solo se escribe al guardar: sin ojo, sin edición,
///   sin lectura de vuelta. Ante un error se borra y se crea de nuevo.
/// - La lista muestra nombre, y usuario solo si [showUser] está activo.
class CredentialsScreen extends StatefulWidget {
  final StorageService storageService;

  const CredentialsScreen({
    super.key,
    required this.storageService,
  });

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  final _nameController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  List<VbCredential> _credentials = [];
  bool _showUser = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final creds = await widget.storageService.loadCredentials();
    final showUser = await widget.storageService.loadCredShowUser();
    if (!mounted) return;
    setState(() {
      _credentials = creds;
      _showUser = showUser;
    });
  }

  Future<void> _save() async {
    final ok = await widget.storageService.addCredential(
      nombre: _nameController.text,
      usuario: _userController.text,
      password: _passController.text,
    );
    if (!mounted) return;
    if (ok) {
      _nameController.clear();
      _userController.clear();
      _passController.clear();
      await _reload();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa los campos: nombre y usuario no vacíos.'),
        ),
      );
    }
  }

  Future<void> _delete(String id) async {
    await widget.storageService.deleteCredential(id);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _toggleShowUser(bool value) async {
    await widget.storageService.saveCredShowUser(value);
    if (!mounted) return;
    setState(() => _showUser = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Claves',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Text(
              '${_credentials.length} / ${StorageService.maxCredentials}',
              style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Se rellenan con un toque desde la llave del teclado.',
          style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Experimental: superficie congelada (SPK-09), sin cambios fuera de fixes.',
          key: const ValueKey('experimental-banner-claves'),
          style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('credenciales-add-nombre'),
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nombre (ej. Banco)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('credenciales-add-usuario'),
          controller: _userController,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Usuario',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('credenciales-add-password'),
          controller: _passController,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Contraseña (solo escritura)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('credenciales-add-button'),
            icon: const Icon(Icons.add),
            label: const Text('Guardar'),
            onPressed: _save,
          ),
        ),
        SwitchListTile(
          key: const ValueKey('credenciales-show-user'),
          title: const Text('Mostrar usuario junto al nombre'),
          value: _showUser,
          onChanged: _toggleShowUser,
        ),
        if (_credentials.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Todavía no hay claves. Guarda la primera arriba.',
              style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          for (final cred in _credentials)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    cred.nombre.isEmpty
                        ? '•'
                        : cred.nombre[0].toUpperCase(),
                  ),
                ),
                title: Text(cred.nombre),
                subtitle: _showUser ? Text(cred.usuario) : null,
                trailing: IconButton(
                  key: ValueKey('credenciales-delete-${cred.id}'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Borrar',
                  onPressed: () => _delete(cred.id),
                ),
              ),
            ),
      ],
    );
  }
}
