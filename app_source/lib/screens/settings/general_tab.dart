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
      title: context.l10n.settingsNavTranscription,
      sections: [
        SettingsSection(
          header: context.l10n.settingsApiKeyHeader,
          footer: context.l10n.settingsApiKeyFooter,
          children: [
            SettingsNavRow(
              key: const ValueKey('api-key-row'),
              title: 'Groq',
              value: _hasApiKey ? _apiKeyTail : context.l10n.settingsAdd,
              valueColor: _hasApiKey ? null : p.tintText,
              onTap: _startApiEdit,
            ),
          ],
        ),
        SettingsSection(
          header: context.l10n.settingsRecordingHeader,
          footer: isHold
              ? context.l10n.settingsRecordHoldFooter
              : context.l10n.settingsRecordTapFooter,
          children: [
            SettingsMenuRow<String>(
              id: 'record-mode-selector',
              title: context.l10n.settingsRecordButton,
              value: _recordMode,
              options: [
                SettingsOption(StorageService.defaultRecordMode, context.l10n.settingsRecordTap),
                SettingsOption(StorageService.recordModeHold, context.l10n.settingsRecordHold),
              ],
              onSelected: _saveRecordMode,
            ),
          ],
        ),
        SettingsSection(
          header: context.l10n.settingsEngineHeader,
          footer: [
            _sttModel == CloudSttService.preciseModel
                ? context.l10n.settingsEnginePreciseFooter
                : context.l10n.settingsEngineFastFooter,
            if (_sttLanguage == CloudSttService.autoLanguage)
              context.l10n.settingsSpokenLanguageAutoFooter,
          ].join(' '),
          children: [
            SettingsMenuRow<String>(
              id: 'stt-model-selector',
              title: context.l10n.settingsModel,
              value: _sttModel,
              options: [
                SettingsOption(CloudSttService.model, 'Whisper v3 Turbo',
                    detail: context.l10n.settingsModelFast),
                SettingsOption(CloudSttService.preciseModel, 'Whisper v3',
                    detail: context.l10n.settingsModelPrecise),
              ],
              onSelected: _saveSttModel,
            ),
            SettingsMenuRow<String>(
              id: 'stt-language-selector',
              title: context.l10n.settingsSpokenLanguage,
              value: _sttLanguage,
              options: [
                SettingsOption(CloudSttService.autoLanguage,
                    context.l10n.settingsSpokenLanguageAuto),
                const SettingsOption('es', 'Español'),
                const SettingsOption('en', 'English'),
                const SettingsOption('pt', 'Português'),
              ],
              onSelected: _saveSttLanguage,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIaPage(BuildContext context) {
    final p = SettingsPalette.of(context);
    return _subpage(
      context,
      title: context.l10n.settingsNavAi,
      sections: [
        SettingsSection(
          header: context.l10n.settingsAiProviderHeader,
          footer: _aiNotesProvider == StorageService.aiNotesProviderGroq
              ? (_hasApiKey
                  ? context.l10n.settingsAiProviderGroqHint
                  : context.l10n.settingsAiProviderGroqNoKey)
              : (_geminiHasApiKey
                  ? context.l10n.settingsAiProviderGoogleHint
                  : context.l10n.settingsAiProviderGoogleNoKey),
          children: [
            SettingsMenuRow<String>(
              id: 'ai-notes-provider-selector',
              title: context.l10n.settingsAiProviderTitle,
              value: _aiNotesProvider,
              options: [
                SettingsOption(StorageService.aiNotesProviderGroq, 'Groq',
                    detail: context.l10n.settingsModelFast),
                SettingsOption(StorageService.aiNotesProviderGoogle, 'Google',
                    detail: 'Gemini'),
              ],
              onSelected: _saveAiNotesProvider,
            ),
          ],
        ),
        SettingsSection(
          header: context.l10n.settingsGoogleKeyHeader,
          footer: context.l10n.settingsGoogleKeyFooter,
          children: [
            SettingsNavRow(
              key: const ValueKey('gemini-key-row'),
              title: 'Google AI Studio',
              value: _geminiHasApiKey ? _geminiApiKeyTail : context.l10n.settingsAdd,
              valueColor: _geminiHasApiKey ? null : p.tintText,
              onTap: _startGeminiApiEdit,
            ),
          ],
        ),
        if (_hasApiKey || _geminiHasApiKey)
          SettingsSection(
            footer: context.l10n.settingsAiActionsFooter,
            children: [
              SettingsSwitchRow(
                key: const ValueKey('geminiActionsSwitch'),
                title: context.l10n.settingsAiActionsSwitch,
                value: _geminiActionsEnabled,
                onChanged: _toggleGeminiActions,
              ),
              SettingsActionRow(
                key: const ValueKey('geminiTestButton'),
                title: context.l10n.settingsAiTestConnection,
                onTap: _testGeminiConnection,
              ),
            ],
          ),
        SettingsSection(
          header: context.l10n.settingsTranslateHeader,
          footer: _translateMode == StorageService.translateModeAi
              ? context.l10n.settingsTranslateFooterAi
              : context.l10n.settingsTranslateFooterLocal,
          children: [
            SettingsMenuRow<String>(
              id: 'translate-target-selector',
              title: context.l10n.settingsTranslateTo,
              value: _translateTarget,
              options: [
                for (final e in StorageService.translateTargets.entries)
                  SettingsOption(e.key, _translateTargetName(context, e.key, e.value)),
              ],
              onSelected: _saveTranslateTarget,
            ),
            SettingsMenuRow<String>(
              id: 'translate-mode-selector',
              title: context.l10n.settingsTranslateHow,
              value: _translateMode,
              options: [
                SettingsOption(StorageService.translateModeLocal,
                    context.l10n.settingsTranslateLocal, detail: context.l10n.settingsTranslateLocalDetail),
                SettingsOption(StorageService.translateModeAi, context.l10n.settingsTranslateAi,
                    detail: context.l10n.settingsTranslateAiDetail),
              ],
              onSelected: _saveTranslateMode,
            ),
            SettingsSwitchRow(
              key: const ValueKey('translate-dictation-switch'),
              title: context.l10n.settingsTranslateDictation,
              value: _translateDictation,
              onChanged: _toggleTranslateDictation,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBurbujaPage(BuildContext context) {
    // La isla la dibuja solo el complemento VoiceBubble Puntero: sin él
    // activo se ve pero no se puede elegir, y se explica por qué.
    final islandAvailable =
        _pointerStatus == FloatingTrackpadService.pointerReady;
    return _subpage(
      context,
      title: context.l10n.settingsNavBubble,
      sections: [
        SettingsSection(
          footer: context.l10n.settingsBubbleFooter,
          children: [
            SettingsSwitchRow(
              key: const ValueKey('bubble-active-switch'),
              title: context.l10n.settingsNavBubble,
              value: _isBubbleEnabled,
              onChanged: _toggleBubble,
            ),
            SettingsMenuRow<String>(
              id: 'dock-form-selector',
              title: context.l10n.settingsDockForm,
              value: _dockForm,
              options: [
                SettingsOption('edge', context.l10n.settingsDockEdge),
                SettingsOption('bubble', context.l10n.settingsDockBubble),
                SettingsOption(
                  'island',
                  context.l10n.settingsDockIsland,
                  detail: islandAvailable ? null : context.l10n.settingsDockUnavailable,
                  enabled: islandAvailable,
                ),
              ],
              onSelected: _saveDockForm,
            ),
            if (_dockForm == 'island')
              SettingsNavRow(
                key: const ValueKey('island-adjust-row'),
                title: context.l10n.islandTitle,
                onTap: () => _go(SettingsPage.isla),
              ),
          ],
        ),
        if (!islandAvailable)
          SettingsSection(
            key: const ValueKey('island-companion-section'),
            header: context.l10n.settingsDockIsland,
            footer: context.l10n.settingsIslandNeedsFooter,
            children: _pointerCompanionRows(),
          ),
        SettingsSection(
          header: context.l10n.settingsToolsHeader,
          footer: context.l10n.settingsToolsFooter,
          children: [
            SettingsSwitchRow(
              key: const ValueKey('dock-tool-mic-switch'),
              title: context.l10n.settingsToolMic,
              value: _dockToolMic,
              onChanged: (v) => _toggleDockTool(pointer: false, value: v),
            ),
            SettingsSwitchRow(
              key: const ValueKey('dock-tool-pointer-switch'),
              title: context.l10n.settingsToolPointer,
              value: _dockToolPointer,
              onChanged: (v) => _toggleDockTool(pointer: true, value: v),
            ),
          ],
        ),
        SettingsSection(
          footer: context.l10n.settingsBubbleHistoryFooter,
          children: [
            SettingsSwitchRow(
              key: const ValueKey('bubble-history-switch'),
              title: context.l10n.settingsBubbleHistory,
              value: _showBubbleHistory,
              onChanged: _toggleBubbleHistory,
            ),
          ],
        ),
        SettingsSection(
          header: context.l10n.settingsPermissionHeader,
          footer: context.l10n.settingsPermissionFooter,
          children: [
            SettingsNavRow(
              key: const ValueKey('burbuja-overlay-permission-row'),
              title: context.l10n.settingsOverlayRow,
              value: context.l10n.settingsReview,
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
      title: context.l10n.settingsNavNotes,
      sections: [
        SettingsSection(
          header: context.l10n.settingsNotesHeader,
          footer: context.l10n.settingsNotesQueueFooter,
          children: [
            SettingsSwitchRow(
              key: const ValueKey('notes-deferred-queue-switch'),
              title: context.l10n.settingsNotesQueueSwitch,
              value: _notesDeferredQueue,
              onChanged: _toggleNotesDeferredQueue,
            ),
          ],
        ),
        SettingsSection(
          header: context.l10n.settingsWidgetHeader,
          children: [
            SettingsMenuRow<String>(
              id: 'widget-mic-position-selector',
              title: context.l10n.settingsToolMic,
              value: _widgetMicPosition,
              options: [
                SettingsOption('left', context.l10n.commonLeft),
                SettingsOption('right', context.l10n.commonRight),
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
      title: context.l10n.settingsGroqKeyTitle,
      inputKey: const ValueKey('api-key-input-field'),
      saveKey: const ValueKey('api-key-save-button'),
      cancelKey: const ValueKey('api-key-cancel-button'),
      deleteKey: const ValueKey('api-key-delete-button'),
      controller: _apiKeyController,
      hint: _hasApiKey ? context.l10n.settingsKeySavedHint(_apiKeyTail) : 'gsk_…',
      error: _apiKeyError,
      help: context.l10n.settingsGroqKeyHelp,
      onSave: _saveApiKey,
      onCancel: _cancelApiEdit,
      onDelete: _hasApiKey ? _clearApiKey : null,
    );
  }

  Widget _buildGeminiKeySheet(BuildContext context) {
    return _keySheet(
      context,
      title: context.l10n.settingsGoogleKeyTitle,
      inputKey: const ValueKey('gemini-key-input-field'),
      saveKey: const ValueKey('gemini-key-save-button'),
      cancelKey: const ValueKey('gemini-key-cancel-button'),
      deleteKey: const ValueKey('gemini-key-delete-button'),
      controller: _geminiApiKeyController,
      hint: _geminiHasApiKey ? context.l10n.settingsGoogleKeySavedHint(_geminiApiKeyTail) : 'AIza…',
      error: _geminiApiKeyError,
      help: context.l10n.settingsGoogleKeyHelp,
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
              label: context.l10n.settingsKeyField,
              controller: controller,
              hint: hint,
              obscure: true,
              mono: true,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSave(),
              errorText: error,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Text(
            help,
            style: kTextFootnote.copyWith(color: p.secondary, height: 1.35),
          ),
        ),
        if (onDelete != null) ...[
          const SizedBox(height: 8),
          // Destructivo como texto danger, sin caja.
          SettingsActionRow(
            key: deleteKey,
            title: context.l10n.settingsKeyDelete,
            destructive: true,
            onTap: onDelete,
          ),
        ],
      ],
    );
  }
}

/// Nombre del idioma destino (el código guardado no se traduce; el nombre
/// del servicio queda como respaldo para códigos nuevos).
String _translateTargetName(BuildContext context, String code, String fallback) {
  final l10n = context.l10n;
  switch (code) {
    case 'en':
      return l10n.translateTargetEn;
    case 'es':
      return l10n.translateTargetEs;
    case 'pt':
      return l10n.translateTargetPt;
    case 'fr':
      return l10n.translateTargetFr;
    case 'it':
      return l10n.translateTargetIt;
    case 'de':
      return l10n.translateTargetDe;
    default:
      return fallback;
  }
}
