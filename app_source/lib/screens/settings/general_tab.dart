part of '../settings_screen.dart';

/// Páginas generales de Ajustes: Transcripción, Inteligencia artificial,
/// Burbuja flotante, Notas y widgets, y los sheets de clave (Groq / Google).
/// Solo construyen UI; estado y acciones viven en [_SettingsScreenState].
extension _GeneralPages on _SettingsScreenState {
  Widget _buildTranscripcionPage(BuildContext context) {
    final p = SettingsPalette.of(context);
    final isHold = _recordMode == StorageService.recordModeHold;
    return _subpage(
      context,
      title: 'Transcripción',
      sections: [
        SettingsSection(
          header: 'Clave de API',
          footer: 'Se guarda cifrada en este teléfono. La conseguís gratis '
              'en console.groq.com.',
          children: [
            SettingsNavRow(
              key: const ValueKey('api-key-row'),
              title: 'Groq',
              value: _hasApiKey ? _apiKeyTail : 'Agregar',
              valueColor: _hasApiKey ? null : p.tintText,
              onTap: _startApiEdit,
            ),
          ],
        ),
        SettingsSection(
          header: 'Grabación',
          footer: isHold
              ? 'Mantené presionado mientras hablás y soltá para transcribir.'
              : 'Tocá para empezar y otra vez para transcribir.',
          children: [
            SettingsMenuRow<String>(
              id: 'record-mode-selector',
              title: 'Botón de grabar',
              value: _recordMode,
              options: const [
                SettingsOption(StorageService.defaultRecordMode, 'Tocar'),
                SettingsOption(StorageService.recordModeHold, 'Mantener'),
              ],
              onSelected: _saveRecordMode,
            ),
          ],
        ),
        const SettingsSection(
          header: 'Motor',
          footer: 'El audio sale del teléfono solo cuando dictás.',
          children: [
            SettingsValueRow(title: 'Modelo', value: 'Whisper v3 Turbo'),
          ],
        ),
      ],
    );
  }

  Widget _buildIaPage(BuildContext context) {
    final p = SettingsPalette.of(context);
    return _subpage(
      context,
      title: 'Inteligencia artificial',
      sections: [
        SettingsSection(
          header: 'Clave de API',
          footer: 'Opcional. La conseguís en aistudio.google.com.',
          children: [
            SettingsNavRow(
              key: const ValueKey('gemini-key-row'),
              title: 'Google AI Studio',
              value: _geminiHasApiKey ? _geminiApiKeyTail : 'Agregar',
              valueColor: _geminiHasApiKey ? null : p.tintText,
              onTap: _startGeminiApiEdit,
            ),
          ],
        ),
        if (_geminiHasApiKey)
          SettingsSection(
            footer: 'Título y resumen con un toque en el editor de cada nota.',
            children: [
              SettingsSwitchRow(
                key: const ValueKey('geminiActionsSwitch'),
                title: 'Acciones de IA en notas',
                value: _geminiActionsEnabled,
                onChanged: _toggleGeminiActions,
              ),
              SettingsActionRow(
                key: const ValueKey('geminiTestButton'),
                title: 'Probar conexión',
                onTap: _testGeminiConnection,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildBurbujaPage(BuildContext context) {
    return _subpage(
      context,
      title: 'Barra flotante',
      sections: [
        SettingsSection(
          footer: 'Dictá y usá el puntero encima de cualquier app. '
              'Arrastrala hacia el centro para usarla como burbuja; pegala '
              'a un borde para volver a la barra.',
          children: [
            SettingsSwitchRow(
              key: const ValueKey('bubble-active-switch'),
              title: 'Barra flotante',
              value: _isBubbleEnabled,
              onChanged: _toggleBubble,
            ),
            SettingsMenuRow<String>(
              id: 'dock-form-selector',
              title: 'Forma',
              value: _dockForm,
              options: const [
                SettingsOption('edge', 'Barra en el borde'),
                SettingsOption('bubble', 'Burbuja'),
              ],
              onSelected: _saveDockForm,
            ),
          ],
        ),
        SettingsSection(
          header: 'Herramientas',
          footer: 'Con una sola herramienta, tocar la burbuja la usa '
              'directo.',
          children: [
            SettingsSwitchRow(
              key: const ValueKey('dock-tool-mic-switch'),
              title: 'Micrófono',
              value: _dockToolMic,
              onChanged: (v) => _toggleDockTool(pointer: false, value: v),
            ),
            SettingsSwitchRow(
              key: const ValueKey('dock-tool-pointer-switch'),
              title: 'Puntero',
              value: _dockToolPointer,
              onChanged: (v) => _toggleDockTool(pointer: true, value: v),
            ),
          ],
        ),
        SettingsSection(
          footer: 'Mantené presionada la barra o la burbuja para ver lo '
              'último que dictaste.',
          children: [
            SettingsSwitchRow(
              key: const ValueKey('bubble-history-switch'),
              title: 'Historial',
              value: _showBubbleHistory,
              onChanged: _toggleBubbleHistory,
            ),
          ],
        ),
        SettingsSection(
          header: 'Permiso',
          footer: 'Android lo pide para mostrar la barra encima de otras '
              'apps.',
          children: [
            SettingsNavRow(
              key: const ValueKey('burbuja-overlay-permission-row'),
              title: 'Mostrar sobre otras apps',
              value: 'Revisar',
              onTap: _reviewOverlayPermission,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotasPage(BuildContext context) {
    return _subpage(
      context,
      title: 'Notas y widgets',
      sections: [
        SettingsSection(
          header: 'Notas',
          footer: 'Sin red, el audio queda en Notas y lo transcribís cuando '
              'vuelva la conexión. Transcribir sin internet: '
              'aún no disponible.',
          children: [
            SettingsSwitchRow(
              key: const ValueKey('notes-deferred-queue-switch'),
              title: 'Guardar audio sin conexión',
              value: _notesDeferredQueue,
              onChanged: _toggleNotesDeferredQueue,
            ),
          ],
        ),
        SettingsSection(
          header: 'Widget de notas',
          children: [
            SettingsMenuRow<String>(
              id: 'widget-mic-position-selector',
              title: 'Micrófono',
              value: _widgetMicPosition,
              options: const [
                SettingsOption('left', 'A la izquierda'),
                SettingsOption('right', 'A la derecha'),
              ],
              onSelected: _setWidgetMicPosition,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGroqKeySheet(BuildContext context) {
    return _keySheet(
      context,
      title: 'Clave de Groq',
      inputKey: const ValueKey('api-key-input-field'),
      saveKey: const ValueKey('api-key-save-button'),
      cancelKey: const ValueKey('api-key-cancel-button'),
      deleteKey: const ValueKey('api-key-delete-button'),
      controller: _apiKeyController,
      hint: _hasApiKey ? 'Guardada: $_apiKeyTail' : 'gsk_…',
      error: _apiKeyError,
      help: 'Pegala tal cual la copiaste de console.groq.com.',
      onSave: _saveApiKey,
      onCancel: _cancelApiEdit,
      onDelete: _hasApiKey ? _clearApiKey : null,
    );
  }

  Widget _buildGeminiKeySheet(BuildContext context) {
    return _keySheet(
      context,
      title: 'Clave de Google AI',
      inputKey: const ValueKey('gemini-key-input-field'),
      saveKey: const ValueKey('gemini-key-save-button'),
      cancelKey: const ValueKey('gemini-key-cancel-button'),
      deleteKey: const ValueKey('gemini-key-delete-button'),
      controller: _geminiApiKeyController,
      hint: _geminiHasApiKey ? 'Guardada: $_geminiApiKeyTail' : 'AIza…',
      error: _geminiApiKeyError,
      help: 'Pegala tal cual la copiaste de aistudio.google.com.',
      onSave: _saveGeminiApiKey,
      onCancel: _cancelGeminiApiEdit,
      onDelete: _geminiHasApiKey ? _clearGeminiApiKey : null,
    );
  }

  /// Sheet de clave: campo oculto, ayuda corta y "Eliminar clave" si existe.
  Widget _keySheet(
    BuildContext context, {
    required String title,
    required Key inputKey,
    required Key saveKey,
    required Key cancelKey,
    required Key deleteKey,
    required TextEditingController controller,
    required String hint,
    required String? error,
    required String help,
    required Future<void> Function() onSave,
    required VoidCallback onCancel,
    required Future<void> Function()? onDelete,
  }) {
    final p = SettingsPalette.of(context);
    return SettingsSheetFrame(
      title: title,
      closeKey: cancelKey,
      onClose: onCancel,
      saveKey: saveKey,
      onSave: onSave,
      children: [
        SettingsSheetCard(
          children: [
            SettingsSheetField(
              key: inputKey,
              label: 'Clave',
              controller: controller,
              hint: hint,
              obscure: true,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSave(),
              errorText: error,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(
            help,
            style: kTextFootnote.copyWith(color: p.secondary, height: 1.35),
          ),
        ),
        if (onDelete != null) ...[
          const SizedBox(height: 16),
          SettingsSheetCard(
            children: [
              SettingsActionRow(
                key: deleteKey,
                title: 'Eliminar clave',
                destructive: true,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
