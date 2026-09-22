import 'package:flutter/material.dart';

import '../../services/storage_service.dart';
import '../../ui/design_tokens.dart';
import '../../widgets/settings_v2.dart';

/// Tab General de Ajustes (rediseño v2): fusiona Inicio + Burbuja en una
/// sola superficie agrupada estilo iOS (API Key, grabación, modelo,
/// burbuja flotante, acerca de). La conducta y las Keys se preservan.
class GeneralTab extends StatelessWidget {
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
  final ValueChanged<bool> onToggleBubble;
  final bool showBubbleHistory;
  final ValueChanged<bool> onToggleBubbleHistory;
  final bool notesDeferredQueue;
  final ValueChanged<bool> onToggleNotesDeferredQueue;
  final VoidCallback onReviewOverlayPermission;
  final VoidCallback onShowAboutSheet;
  final String widgetMicPosition;
  final ValueChanged<String> onWidgetMicPosition;

  const GeneralTab({
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
    required this.onToggleBubble,
    required this.showBubbleHistory,
    required this.onToggleBubbleHistory,
    required this.notesDeferredQueue,
    required this.onToggleNotesDeferredQueue,
    required this.onReviewOverlayPermission,
    required this.onShowAboutSheet,
    required this.widgetMicPosition,
    required this.onWidgetMicPosition,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variantColor = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final successColor = isDark ? kSuccessDark : kSuccessLight;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        const SettingsPageTitle('General'),
        ApiKeyCard(
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
        const SizedBox(height: 8),
        SettingsCard(
          children: [
            _IconValueRow(
              icon: Icons.psychology_rounded,
              iconColor: kTilePurple,
              title: 'Modelo Transcripción',
              value: 'Cloud Whisper',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SettingIconTile(
                        icon: Icons.mic_rounded,
                        background: kTileRed,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Grabación',
                        style: kSettingRowTitle.copyWith(
                          color: isDark
                              ? kLabelPrimaryDark
                              : kLabelPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                    onSelectionChanged: (modes) =>
                        onSaveRecordMode(modes.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recordMode == StorageService.recordModeHold
                        ? 'Mantén presionado para grabar y suelta para transcribir.'
                        : 'Toca para iniciar y vuelve a tocar para transcribir.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: variantColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SettingsGroupTitle('Burbuja Flotante'),
        SettingsCard(
          children: [
            SwitchListTile(
              secondary: const SettingIconTile(
                icon: Icons.chat_bubble_rounded,
                background: kTileGreen,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: const Text('Activar burbuja'),
              value: isBubbleEnabled,
              onChanged: onToggleBubble,
            ),
            SwitchListTile(
              key: const ValueKey('bubble-history-switch'),
              secondary: const SettingIconTile(
                icon: Icons.history_rounded,
                background: kTileGray,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: const Text('Historial en la burbuja'),
              subtitle: const Text(
                'El toque largo sobre la burbuja abre el historial con morph inteligente. Apagado: el toque largo no hace nada.',
              ),
              value: showBubbleHistory,
              onChanged: onToggleBubbleHistory,
            ),
            SettingChevronRow(
              key: const ValueKey('burbuja-overlay-permission-row'),
              icon: Icons.layers_outlined,
              iconColor: kTileOrange,
              title: 'Permiso superposición',
              onTap: onReviewOverlayPermission,
            ),
          ],
        ),
        const SettingsGroupTitle('Notas'),
        SettingsCard(
          children: [
            SwitchListTile(
              key: const ValueKey('notes-deferred-queue-switch'),
              secondary: const SettingIconTile(
                icon: Icons.cloud_off_rounded,
                background: kTileOrange,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: const Text('Guardar audio sin conexión'),
              subtitle: const Text(
                'Si no hay red al dictar, el audio queda en Notas. Transcribir solo cuando lo pidas.',
              ),
              value: notesDeferredQueue,
              onChanged: onToggleNotesDeferredQueue,
            ),
          ],
        ),
        const SettingsGroupTitle('Widgets'),
        SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  const SettingIconTile(
                    icon: Icons.widgets_rounded,
                    background: kTileBlue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Posición del micrófono',
                          style: kSettingRowTitle.copyWith(
                            color: isDark ? kLabelPrimaryDark : kLabelPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'En el widget grande de notas',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: variantColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'left', label: Text('Izquierda')),
                  ButtonSegment(value: 'right', label: Text('Derecha')),
                ],
                selected: {widgetMicPosition},
                onSelectionChanged: (s) => onWidgetMicPosition(s.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SettingsCard(
          children: [
            SettingChevronRow(
              key: const ValueKey('about-open-button'),
              icon: Icons.info_outline_rounded,
              iconColor: kTileGray,
              title: 'Acerca de VoiceBubble',
              onTap: onShowAboutSheet,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              hasApiKey ? Icons.check_circle : Icons.key_rounded,
              color: hasApiKey ? successColor : theme.colorScheme.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasApiKey
                    ? 'API Key cargada $apiKeyTail'
                    : 'Sin API Key: el modo Cloud no transcribe.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: variantColor),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Fila con icono, título y valor a la derecha (sin navegación).
class _IconValueRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _IconValueRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kSettingRowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SettingIconTile(icon: icon, background: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: kSettingRowTitle.copyWith(
                  color:
                      isDark ? kLabelPrimaryDark : kLabelPrimaryLight,
                ),
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta API Key como botón-estado (paridad v1): vacía → CTA;
/// editando → campo con validación; guardada → botón verde con cola
/// enmascarada + detalle Cambiar/Borrar. Preserva espejo D7.
class ApiKeyCard extends StatelessWidget {
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

  const ApiKeyCard({
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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variantColor = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final successColor = isDark ? kSuccessDark : kSuccessLight;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints:
                  const BoxConstraints(minHeight: kSettingRowMinHeight),
              child: Row(
                children: [
                  SettingIconTile(
                    icon: Icons.key_rounded,
                    background: hasApiKey ? kTileGreen : kTileBlue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'API Key de Groq',
                      style: kSettingRowTitle.copyWith(
                        color: isDark
                            ? kLabelPrimaryDark
                            : kLabelPrimaryLight,
                      ),
                    ),
                  ),
                  StatusPill(
                    dotColor: hasApiKey ? successColor : kWarning,
                    label: hasApiKey ? 'Activa' : 'Falta',
                  ),
                ],
              ),
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
                      ? Icon(Icons.check_circle, color: successColor)
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
                  icon: Icon(Icons.check_circle, color: successColor),
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
