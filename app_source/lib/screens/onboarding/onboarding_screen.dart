import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../app_info.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_ext.dart';
import '../../services/keyboard_service.dart';
import '../../services/storage_service.dart';
import '../../ui/design_tokens.dart';
import '../../widgets/settings_v2.dart';

/// Para qué va a usar Orison (precarga snippets de ejemplo).
enum OnboardingUse { code, sales, writing }

/// T13 · Primer uso guiado (sección 07 del plan): de la instalación limpia
/// al primer dictado sin pasar por Ajustes. Pasos: bienvenida, para qué lo
/// vas a usar, privacidad, clave de Groq, micrófono, activar el teclado y
/// probarlo. Cada paso se puede saltear; al terminar (o saltear todo) se
/// guarda `onboarding_done_v1` y se puede volver a abrir desde Ajustes ›
/// Acerca de.
class OnboardingScreen extends StatefulWidget {
  final StorageService? storageService;
  final FlutterSecureStorage? secureStorage;
  final KeyboardService? keyboardService;

  /// Pide el permiso de micrófono y dice si quedó concedido.
  final Future<bool> Function()? requestMicrophone;

  const OnboardingScreen({
    super.key,
    this.storageService,
    this.secureStorage,
    this.keyboardService,
    this.requestMicrophone,
  });

  static const int stepCount = 8;
  static const String groqKeysUrl = 'https://console.groq.com/keys';

  @override
  State<OnboardingScreen> createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  late final StorageService _storage;
  late final FlutterSecureStorage _secure;
  late final KeyboardService _keyboard;
  final _keyController = TextEditingController();
  final _tryController = TextEditingController();

  int _step = 0;
  bool _closing = false;
  OnboardingUse? _use;
  bool _hasKey = false;
  String? _keyError;
  String? _clipboardKey;
  bool _micGranted = false;
  bool _aiTranslate = false;
  bool _keyboardEnabled = false;
  bool _keyboardSelected = false;

  int get step => _step;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _storage = widget.storageService ?? StorageService();
    _secure = widget.secureStorage ?? StorageService.espSecureStorage;
    _keyboard = widget.keyboardService ?? KeyboardService();
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyController.dispose();
    _tryController.dispose();
    super.dispose();
  }

  /// Al volver de Groq o de los Ajustes de Android: clave copiada y teclado.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    String stored = '';
    try {
      stored = await _secure.read(key: 'groq_api_key') ?? '';
    } catch (_) {}
    final enabled = await _keyboard.isKeyboardEnabled();
    final selected = await _keyboard.isKeyboardSelected();
    String? copied;
    if (stored.isEmpty) {
      try {
        final data = await Clipboard.getData('text/plain');
        final text = data?.text?.trim() ?? '';
        if (_looksLikeGroqKey(text)) copied = text;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _hasKey = stored.isNotEmpty;
      _keyboardEnabled = enabled;
      _keyboardSelected = selected;
      _clipboardKey = copied;
    });
  }

  static bool _looksLikeGroqKey(String text) =>
      text.startsWith('gsk_') && text.length >= 20 && !text.contains(' ');

  void _next() {
    if (_step < OnboardingScreen.stepCount - 1) {
      setState(() => _step++);
    } else {
      unawaited(_finish());
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  /// Terminar o saltear. No usa maybePop: el PopScope (Atrás = paso
  /// anterior) lo interceptaba y «Empezar a usar» volvía al paso 6 en vez
  /// de cerrar (bug del video del 25/11).
  Future<void> _finish() async {
    if (_closing) return;
    _closing = true;
    await _storage.saveOnboardingDone();
    if (!mounted) return;
    setState(() {});
    Navigator.of(context).pop();
  }

  Future<void> _chooseUse(OnboardingUse use) async {
    setState(() => _use = use);
    final l = context.l10n;
    final examples = switch (use) {
      OnboardingUse.code => [
          (l.onbSnipCode1Name, 'git status && git log --oneline -5'),
          (l.onbSnipCode2Name, 'ssh usuario@servidor'),
          (l.onbSnipCode3Name, 'claude --continue'),
        ],
      OnboardingUse.sales => [
          (l.onbSnipSales1Name, l.onbSnipSales1Body),
          (l.onbSnipSales2Name, l.onbSnipSales2Body),
          (l.onbSnipSales3Name, l.onbSnipSales3Body),
        ],
      OnboardingUse.writing => [
          (l.onbSnipWrite1Name, l.onbSnipWrite1Body),
          (l.onbSnipWrite2Name, l.onbSnipWrite2Body),
        ],
    };
    try {
      final current = await _storage.loadSnippets();
      final names = current.map((s) => s.nombre).toSet();
      for (final (name, body) in examples) {
        if (names.contains(name)) continue;
        await _storage.addSnippet(nombre: name, contenido: body);
      }
    } catch (_) {}
  }

  Future<void> _acceptPrivacy() async {
    await _storage.savePrivacyNoticeAccepted();
    _next();
  }

  Future<void> _saveKey([String? value]) async {
    final key = (value ?? _keyController.text).trim();
    final l = context.l10n;
    String? error;
    if (key.isEmpty) {
      error = l.settingsKeyPasteToContinue;
    } else if (key.length < 10) {
      error = l.settingsKeyIncomplete;
    } else if (!key.startsWith('gsk_')) {
      error = l.settingsGroqKeyPrefix;
    }
    if (error != null) {
      setState(() => _keyError = error);
      return;
    }
    try {
      await _secure.write(key: 'groq_api_key', value: key);
      await _storage.saveSttMirror(apiKey: key);
      await _storage.savePrivacyNoticeAccepted();
    } catch (_) {
      if (mounted) setState(() => _keyError = l.settingsKeySaveFailed);
      return;
    }
    if (!mounted) return;
    setState(() {
      _hasKey = true;
      _keyError = null;
      _clipboardKey = null;
      _keyController.clear();
    });
  }

  Future<void> _requestMic() async {
    bool ok = false;
    // El pedido lo hace quien abre el primer uso (Inicio o Ajustes) con su
    // propio grabador: acá no se construye ninguno (C-05, árbitro del mic).
    try {
      ok = await widget.requestMicrophone?.call() ?? false;
    } catch (_) {}
    if (mounted) setState(() => _micGranted = ok);
  }

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    final l = context.l10n;
    final isLast = _step == OnboardingScreen.stepCount - 1;
    return PopScope(
      canPop: _step == 0 || _closing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: p.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(child: _Progress(step: _step)),
                    TextButton(
                      key: const ValueKey('onb-skip-all'),
                      onPressed: _finish,
                      child: Text(l.onbSkipAll),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: ValueKey('onb-step-$_step'),
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: _buildStep(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    if (_step > 0)
                      TextButton(
                        key: const ValueKey('onb-back'),
                        onPressed: _back,
                        child: Text(l.commonBack),
                      ),
                    const Spacer(),
                    FilledButton(
                      key: const ValueKey('onb-next'),
                      onPressed: _primaryAction(),
                      child: Text(_primaryLabel(l, isLast)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  VoidCallback? _primaryAction() {
    if (_step == 2) return _acceptPrivacy;
    return _next;
  }

  String _primaryLabel(AppLocalizations l, bool isLast) {
    if (isLast) return l.onbFinish;
    if (_step == 2) return l.privacyNoticeAccept;
    final skipping = (_step == 1 && _use == null) ||
        (_step == 3 && !_hasKey) ||
        (_step == 4 && !_aiTranslate) ||
        (_step == 5 && !_micGranted) ||
        (_step == 6 && !_keyboardSelected);
    return skipping ? l.onbNotNow : l.onbNext;
  }

  Widget _buildStep(BuildContext context) {
    final l = context.l10n;
    switch (_step) {
      case 0:
        return _StepScaffold(
          title: l.onbWelcomeTitle(AppInfo.name),
          body: l.onbWelcomeBody,
          children: [
            _InfoCard(icon: Icons.mic_none_rounded, title: l.onbWelcomeCard1Title, body: l.onbWelcomeCard1Body),
            _InfoCard(icon: Icons.sticky_note_2_outlined, title: l.onbWelcomeCard2Title, body: l.onbWelcomeCard2Body),
            _InfoCard(icon: Icons.code_rounded, title: l.onbWelcomeCard3Title, body: l.onbWelcomeCard3Body),
          ],
        );
      case 1:
        return _StepScaffold(
          title: l.onbUseTitle,
          body: l.onbUseBody,
          children: [
            _ChoiceCard(
              key: const ValueKey('onb-use-code'),
              icon: Icons.terminal_rounded,
              title: l.onbUseCode,
              body: l.onbUseCodeBody,
              selected: _use == OnboardingUse.code,
              onTap: () => _chooseUse(OnboardingUse.code),
            ),
            _ChoiceCard(
              key: const ValueKey('onb-use-sales'),
              icon: Icons.storefront_outlined,
              title: l.onbUseSales,
              body: l.onbUseSalesBody,
              selected: _use == OnboardingUse.sales,
              onTap: () => _chooseUse(OnboardingUse.sales),
            ),
            _ChoiceCard(
              key: const ValueKey('onb-use-writing'),
              icon: Icons.edit_note_rounded,
              title: l.onbUseWriting,
              body: l.onbUseWritingBody,
              selected: _use == OnboardingUse.writing,
              onTap: () => _chooseUse(OnboardingUse.writing),
            ),
          ],
        );
      case 2:
        return _StepScaffold(
          title: l.privacyNoticeTitle,
          body: l.privacyNoticeBody,
          children: const [],
        );
      case 3:
        return _buildKeyStep(context);
      case 4:
        return _buildTranslateStep(context);
      case 5:
        return _StepScaffold(
          title: l.onbMicTitle,
          body: l.onbMicBody,
          children: [
            _ActionRow(
              key: const ValueKey('onb-mic-button'),
              done: _micGranted,
              label: _micGranted ? l.onbMicGranted : l.onbMicAllow,
              onPressed: _micGranted ? null : _requestMic,
            ),
          ],
        );
      case 6:
        return _StepScaffold(
          title: l.onbKeyboardTitle(AppInfo.name),
          body: l.onbKeyboardBody,
          children: [
            _ActionRow(
              key: const ValueKey('onb-kb-enable'),
              done: _keyboardEnabled,
              label: l.onbKeyboardEnable(AppInfo.name),
              onPressed: _keyboardEnabled ? null : () => _keyboard.openKeyboardSettings(),
            ),
            _ActionRow(
              key: const ValueKey('onb-kb-select'),
              done: _keyboardSelected,
              label: l.onbKeyboardSelect(AppInfo.name),
              onPressed: !_keyboardEnabled || _keyboardSelected
                  ? null
                  : () async {
                      await _keyboard.showInputMethodPicker();
                      // El selector no pausa la app: releer un rato después.
                      await Future<void>.delayed(const Duration(seconds: 2));
                      await _refresh();
                    },
            ),
          ],
        );
      default:
        final p = SettingsPalette.of(context);
        final tried = _tryController.text.trim().isNotEmpty;
        return _StepScaffold(
          title: l.onbTryTitle,
          body: l.onbTryBody,
          children: [
            TextField(
              key: const ValueKey('onb-try-field'),
              controller: _tryController,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l.onbTryHint,
                filled: true,
                fillColor: p.field,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (tried) ...[
              const SizedBox(height: 12),
              Text(
                l.onbTryDone,
                key: const ValueKey('onb-try-done'),
                style: kTextSubhead.copyWith(color: p.tintText, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 20),
            Text(l.onbExtras, style: kTextFootnote.copyWith(color: p.secondary)),
          ],
        );
    }
  }

  /// Traducción: «En el teléfono» es lo de siempre (el texto no sale); con
  /// IA es más rápida y precisa, y se activa solo si el usuario la autoriza
  /// acá (el mismo consentimiento que Ajustes › Inteligencia artificial).
  Future<void> _authorizeAiTranslate() async {
    await _storage.saveTranslateMode(StorageService.translateModeAi);
    if (mounted) setState(() => _aiTranslate = true);
  }

  Future<void> _keepLocalTranslate() async {
    await _storage.saveTranslateMode(StorageService.translateModeLocal);
    if (mounted) setState(() => _aiTranslate = false);
    _next();
  }

  Widget _buildTranslateStep(BuildContext context) {
    final l = context.l10n;
    return _StepScaffold(
      title: l.onbTranslateTitle,
      body: l.onbTranslateBody,
      children: [
        _InfoCard(
          icon: Icons.phone_android_rounded,
          title: l.onbTranslateLocalTitle,
          body: l.onbTranslateLocalBody,
        ),
        _InfoCard(
          icon: Icons.auto_awesome_outlined,
          title: l.onbTranslateAiTitle,
          body: l.onbTranslateAiBody,
        ),
        if (_aiTranslate)
          _ActionRow(
            key: const ValueKey('onb-translate-ai-on'),
            done: true,
            label: l.onbTranslateAiOn,
            onPressed: null,
          )
        else ...[
          _ActionRow(
            key: const ValueKey('onb-translate-ai'),
            done: false,
            label: l.settingsTranslateAiAuthorize,
            onPressed: _hasKey ? _authorizeAiTranslate : null,
          ),
          if (!_hasKey)
            Text(l.onbTranslateNeedsKey,
                style: kTextFootnote.copyWith(color: SettingsPalette.of(context).secondary)),
          const SizedBox(height: 4),
          TextButton(
            key: const ValueKey('onb-translate-local'),
            onPressed: _keepLocalTranslate,
            child: Text(l.onbTranslateKeepLocal),
          ),
        ],
      ],
    );
  }

  Widget _buildKeyStep(BuildContext context) {
    final l = context.l10n;
    final p = SettingsPalette.of(context);
    if (_hasKey) {
      return _StepScaffold(
        title: l.onbKeyTitle,
        body: l.onbKeyReady,
        children: [
          _ActionRow(key: const ValueKey('onb-key-ready'), done: true, label: l.onbKeySaved, onPressed: null),
        ],
      );
    }
    final steps = [l.onbKeyStep1, l.onbKeyStep2, l.onbKeyStep3, l.onbKeyStep4, l.onbKeyStep5];
    return _StepScaffold(
      title: l.onbKeyTitle,
      body: l.onbKeyBody,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.isDark ? kHoleDark : kHoleLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.tintFill, width: 2),
                  ),
                  child: Text('${i + 1}', style: kTextMono.copyWith(color: kOnHole, fontSize: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(steps[i], style: kTextSubhead.copyWith(color: p.label))),
              ],
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('onb-open-groq'),
          onPressed: () => _keyboard.openUrl(OnboardingScreen.groqKeysUrl),
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(l.onbKeyOpenGroq),
        ),
        if (_clipboardKey != null) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('onb-paste-copied-key'),
            onPressed: () => _saveKey(_clipboardKey),
            icon: const Icon(Icons.content_paste_rounded),
            label: Text(l.onbKeyPasteCopied),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('onb-key-field'),
          controller: _keyController,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            hintText: 'gsk_…',
            errorText: _keyError,
            filled: true,
            fillColor: p.field,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) => _saveKey(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const ValueKey('onb-key-save'),
            onPressed: _saveKey,
            child: Text(l.commonSave),
          ),
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  final int step;
  const _Progress({required this.step});

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    return Semantics(
      label: '${step + 1} / ${OnboardingScreen.stepCount}',
      child: Row(
        children: [
          for (var i = 0; i < OnboardingScreen.stepCount; i++)
            Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i <= step ? p.tintFill : p.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  final String title;
  final String body;
  final List<Widget> children;
  const _StepScaffold({required this.title, required this.body, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title, style: kTextTitle.copyWith(fontSize: 26, color: p.label)),
        const SizedBox(height: 10),
        Text(body, style: kTextCallout.copyWith(color: p.secondary, height: 1.45)),
        const SizedBox(height: 20),
        ...children,
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _InfoCard({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border, width: p.borderWidth),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: p.tintText),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: kTextCallout.copyWith(color: p.label, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(body, style: kTextFootnote.copyWith(color: p.secondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: p.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: selected ? p.tintFill : p.border, width: selected ? 2 : p.borderWidth),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: selected ? p.tintText : p.icon),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: kTextCallout.copyWith(color: p.label, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(body, style: kTextFootnote.copyWith(color: p.secondary, height: 1.4)),
                      ],
                    ),
                  ),
                  if (selected) Icon(Icons.check_circle_rounded, color: p.tintText),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final bool done;
  final String label;
  final VoidCallback? onPressed;
  const _ActionRow({super.key, required this.done, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: done
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border, width: p.borderWidth),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: p.success),
                    const SizedBox(width: 12),
                    Expanded(child: Text(label, style: kTextCallout.copyWith(color: p.label))),
                  ],
                ),
              )
            : FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(label),
              ),
      ),
    );
  }
}
