import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/credential.dart';
import '../services/storage_service.dart';
import '../ui/design_tokens.dart';
import '../widgets/settings_v2.dart';

/// Página "Claves": credenciales para rellenar desde la llave del teclado.
///
/// Reglas de producto (mockup laboratorio_ui/credentials_lab.html):
/// - La contraseña solo se escribe al guardar: sin ojo, sin edición,
///   sin lectura de vuelta. Ante un error se borra y se crea de nuevo.
/// - La lista muestra nombre, y usuario solo si "Mostrar usuario" está activo.
/// El "+" vive en la barra de la página y llama a
/// [CredentialsScreenState.openAddCredential].
class CredentialsScreen extends StatefulWidget {
  final StorageService storageService;

  const CredentialsScreen({
    super.key,
    required this.storageService,
  });

  @override
  State<CredentialsScreen> createState() => CredentialsScreenState();
}

class CredentialsScreenState extends State<CredentialsScreen> {
  List<VbCredential> _credentials = [];
  bool _showUser = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final creds = await widget.storageService.loadCredentials();
    final showUser = await widget.storageService.loadCredShowUser();
    if (!mounted) return;
    setState(() {
      _credentials = creds;
      _showUser = showUser;
      _loaded = true;
    });
  }

  /// Abre el sheet de alta (lo llama el "+" de la barra).
  Future<void> openAddCredential() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: kScrimColor,
      builder: (_) => _CredentialFormSheet(storageService: widget.storageService),
    );
    if (saved == true && mounted) await _reload();
  }

  Future<void> _delete(VbCredential cred) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Borrar clave'),
        content: Text('¿Borrar "${cred.nombre}"? No se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const ValueKey('credenciales-confirm-delete'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.storageService.deleteCredential(cred.id);
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
    return ListView(
      key: const PageStorageKey<String>('credentials_tab_scroll'),
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        kSettingsGroupGap + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        SettingsSection(
          footer: 'Junto al nombre, en la lista del teclado.',
          children: [
            SettingsSwitchRow(
              key: const ValueKey('credenciales-show-user'),
              title: 'Mostrar usuario',
              value: _showUser,
              onChanged: _toggleShowUser,
            ),
          ],
        ),
        const SizedBox(height: kSettingsGroupGap),
        if (_loaded && _credentials.isEmpty)
          SettingsEmptyState(
            icon: Icons.key_rounded,
            title: 'Sin claves guardadas',
            message: 'Guardá usuario y contraseña para rellenarlos desde la '
                'llave del teclado.',
            actionLabel: 'Agregar clave',
            actionKey: const ValueKey('credenciales-empty-add'),
            onAction: openAddCredential,
          )
        else if (_credentials.isNotEmpty)
          SettingsSection(
            header: 'Guardadas',
            footer: '${_credentials.length} de ${StorageService.maxCredentials}'
                ' · La contraseña nunca se muestra.',
            children: [
              for (final cred in _credentials)
                _CredentialRow(
                  cred: cred,
                  showUser: _showUser,
                  onDelete: () => _delete(cred),
                ),
            ],
          ),
      ],
    );
  }
}

/// Fila de credencial: nombre (y usuario) + borrar.
class _CredentialRow extends StatelessWidget {
  final VbCredential cred;
  final bool showUser;
  final VoidCallback onDelete;

  const _CredentialRow({
    required this.cred,
    required this.showUser,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kSettingRowMinHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
        child: Row(
          children: [
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cred.nombre, style: kTextBody.copyWith(color: p.label)),
                    if (showUser)
                      Text(
                        cred.usuario,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kTextSubhead.copyWith(color: p.secondary),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              key: ValueKey('credenciales-delete-${cred.id}'),
              icon: const Icon(Icons.delete_outline_rounded, size: 22),
              color: p.secondary,
              tooltip: 'Borrar ${cred.nombre}',
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet de alta: nombre, usuario y contraseña (solo escritura).
class _CredentialFormSheet extends StatefulWidget {
  final StorageService storageService;

  const _CredentialFormSheet({required this.storageService});

  @override
  State<_CredentialFormSheet> createState() => _CredentialFormSheetState();
}

class _CredentialFormSheetState extends State<_CredentialFormSheet> {
  final _nameController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await widget.storageService.addCredential(
      nombre: _nameController.text,
      usuario: _userController.text,
      password: _passController.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = 'Revisá los campos: nombre y usuario no pueden quedar vacíos.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            8, 0, 8, 8 + MediaQuery.viewInsetsOf(context).bottom),
        child: AutofillGroup(
          child: SettingsSheetFrame(
            title: 'Nueva clave',
            closeKey: const ValueKey('credenciales-cancel-button'),
            onClose: () => Navigator.of(context).pop(),
            saveKey: const ValueKey('credenciales-add-button'),
            onSave: _saving ? null : _save,
            children: [
              SettingsSheetCard(
                children: [
                  SettingsSheetField(
                    key: const ValueKey('credenciales-add-nombre'),
                    label: 'Nombre',
                    hint: 'Ej. Banco',
                    controller: _nameController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                  ),
                  SettingsSheetField(
                    key: const ValueKey('credenciales-add-usuario'),
                    label: 'Usuario',
                    hint: 'Usuario o email',
                    controller: _userController,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                  ),
                  SettingsSheetField(
                    key: const ValueKey('credenciales-add-password'),
                    label: 'Contraseña',
                    hint: 'Solo se escribe, nunca se muestra',
                    controller: _passController,
                    obscure: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _save(),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(
                  _error ??
                      'Se guarda cifrada. El teclado la rellena solo en '
                          'campos de contraseña.',
                  style: kTextFootnote.copyWith(
                    color: _error == null
                        ? p.secondary
                        : Theme.of(context).colorScheme.error,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
