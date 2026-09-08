import 'package:flutter/material.dart';

import '../../services/storage_service.dart';

/// Tab Inicio de Ajustes (SPK-06, módulo 3 de N): tarjeta API Key +
/// modo grabación + modelo + accesos, extraído de SettingsScreen
/// sin cambiar conducta.
class InicioTab extends StatelessWidget {
  final bool hasApiKey;
  final bool isEditingApiKey;
  final TextEditingController apiKeyController;
  final String? apiKeyError;
  final bool showApiDetail;
  final String apiKeyTail;
  final VoidCallback onStartApiEdit;
  final VoidCallback onCancelApiEdit;
  final VoidCallback onSaveApiKey;
  final VoidCallback onClearApiKey;
  final VoidCallback onToggleApiDetail;
  final String recordMode;
  final ValueChanged<String> onSaveRecordMode;
  final bool isBubbleEnabled;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onShowAboutSheet;

  const InicioTab({
    super.key,
    required this.hasApiKey,
    required this.isEditingApiKey,
    required this.apiKeyController,
    required this.apiKeyError,
    required this.showApiDetail,
    required this.apiKeyTail,
    required this.onStartApiEdit,
    required this.onCancelApiEdit,
    required this.onSaveApiKey,
    required this.onClearApiKey,
    required this.onToggleApiDetail,
    required this.recordMode,
    required this.onSaveRecordMode,
    required this.isBubbleEnabled,
    required this.onSelectTab,
    required this.onShowAboutSheet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variantColor = theme.colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _ApiKeyCard(
          hasApiKey: hasApiKey,
          isEditingApiKey: isEditingApiKey,
          apiKeyController: apiKeyController,
          apiKeyError: apiKeyError,
          showApiDetail: showApiDetail,
          apiKeyTail: apiKeyTail,
          onStartApiEdit: onStartApiEdit,
          onCancelApiEdit: onCancelApiEdit,
          onSaveApiKey: onSaveApiKey,
          onClearApiKey: onClearApiKey,
          onToggleApiDetail: onToggleApiDetail,
        ),
        const SizedBox(height: 16),
        Text(
          'Modo de grabación',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: StorageService.defaultRecordMode,
              label: Text('Toque'),
            ),
            ButtonSegment(
              value: StorageService.recordModeHold,
              label: Text('Mantener'),
            ),
          ],
          selected: {recordMode},
          onSelectionChanged: (modes) => onSaveRecordMode(modes.first),
        ),
        const SizedBox(height: 8),
        Text(
          recordMode == StorageService.recordModeHold
              ? 'Mantén presionado para grabar y suelta para transcribir.'
              : 'Toca para iniciar y vuelve a tocar para transcribir.',
          style: theme.textTheme.bodySmall?.copyWith(color: variantColor),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Modelo de transcripcion',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.cloud,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modo Cloud',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        'Groq Whisper Large V3 (whisper-large-v3)',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('inicio-go-burbuja'),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: Text(
                  isBubbleEnabled ? 'Burbuja activada' : 'Burbuja',
                ),
                onPressed: () => onSelectTab(1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('inicio-go-teclado'),
                icon: const Icon(Icons.keyboard_outlined),
                label: const Text('Teclado'),
                onPressed: () => onSelectTab(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('about-open-button'),
          icon: const Icon(Icons.info_outline_rounded),
          label: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Acerca de VoiceBubble'),
              Text(
                'Versión, privacidad y qué hace la app',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
            ],
          ),
          onPressed: onShowAboutSheet,
        ),
      ],
    );
  }
}

/// Tarjeta API Key como botón-estado (paridad prototipo v1):
/// vacía → CTA; editando → campo con validación; guardada → botón verde
/// con cola enmascarada + detalle Cambiar/Borrar. Preserva espejo D7.
class _ApiKeyCard extends StatelessWidget {
  final bool hasApiKey;
  final bool isEditingApiKey;
  final TextEditingController apiKeyController;
  final String? apiKeyError;
  final bool showApiDetail;
  final String apiKeyTail;
  final VoidCallback onStartApiEdit;
  final VoidCallback onCancelApiEdit;
  final VoidCallback onSaveApiKey;
  final VoidCallback onClearApiKey;
  final VoidCallback onToggleApiDetail;

  const _ApiKeyCard({
    required this.hasApiKey,
    required this.isEditingApiKey,
    required this.apiKeyController,
    required this.apiKeyError,
    required this.showApiDetail,
    required this.apiKeyTail,
    required this.onStartApiEdit,
    required this.onCancelApiEdit,
    required this.onSaveApiKey,
    required this.onClearApiKey,
    required this.onToggleApiDetail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variantColor = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.key_rounded,
                  color: hasApiKey
                      ? Colors.green
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'API Key de Groq',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (hasApiKey && !isEditingApiKey)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Necesaria para el modo Cloud. Obtén tu clave en console.groq.com',
              style: theme.textTheme.bodySmall?.copyWith(color: variantColor),
            ),
            const SizedBox(height: 12),
            if (!hasApiKey && !isEditingApiKey) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('api-cta-button'),
                  onPressed: onStartApiEdit,
                  child: const Text('Ingresa tu API Key'),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tócalo para habilitar el campo, pégala y guárdala.',
                style: theme.textTheme.bodySmall?.copyWith(color: variantColor),
              ),
            ],
            if (isEditingApiKey) ...[
              TextField(
                controller: apiKeyController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'gsk_...',
                  border: const OutlineInputBorder(),
                  errorText: apiKeyError,
                  suffixIcon: hasApiKey
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancelApiEdit,
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar'),
                      onPressed: onSaveApiKey,
                    ),
                  ),
                ],
              ),
            ],
            if (hasApiKey && !isEditingApiKey) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('api-loaded-button'),
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  label: Text('API Key cargada $apiKeyTail'),
                  onPressed: onToggleApiDetail,
                ),
              ),
              if (showApiDetail) ...[
                const SizedBox(height: 4),
                Text(
                  'Oculta por seguridad. Solo se muestran los últimos 4 caracteres.',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: variantColor),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onStartApiEdit,
                        child: const Text('Cambiar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Borrar'),
                        onPressed: onClearApiKey,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
