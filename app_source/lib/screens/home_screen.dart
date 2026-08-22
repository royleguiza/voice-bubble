import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/transcription_service.dart';
import '../services/storage_service.dart';
import '../services/cloud_stt_service.dart';
import '../ui/design_tokens.dart';
import '../ui/glass_container.dart';
import 'settings_screen.dart';
import '../widgets/record_button.dart';
import '../widgets/history_list.dart';
import '../widgets/transcription_popup.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class HomeScreen extends StatefulWidget {
  final TranscriptionService? transcriptionService;
  final StorageService? storageService;

  const HomeScreen({
    super.key,
    this.transcriptionService,
    this.storageService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late final TranscriptionService _transcriptionService;
  late final StorageService _storageService;
  final _secureStorage = const FlutterSecureStorage();

  bool _isRecording = false;
  bool _isTranscribing = false;
  String _resultText = '';
  String? _pendingAudioPath;
  String _recordMode = StorageService.defaultRecordMode;
  DateTime? _holdStartedAt;

  late final AnimationController _popupCtrl = AnimationController(
    vsync: this,
    duration: kAnimPopupExpand,
  );

  @override
  void initState() {
    super.initState();
    if (widget.transcriptionService != null) {
      _transcriptionService = widget.transcriptionService!;
      _storageService = widget.storageService ?? _transcriptionService.storageService;
    } else {
      _storageService = widget.storageService ?? StorageService();
      _transcriptionService = TranscriptionService(
        cloudService: const CloudSttService(apiKey: ''),
        storageService: _storageService,
      );
    }
    _init();
  }

  Future<void> _loadApiKey() async {
    try {
      final key = await _secureStorage.read(key: 'groq_api_key') ?? '';
      _transcriptionService.updateApiKey(key);
    } catch (_) {}
  }

  Future<void> _loadRecordMode() async {
    try {
      final mode = await _storageService.loadRecordMode();
      if (mounted) setState(() => _recordMode = mode);
    } catch (_) {}
  }

  Future<void> _init() async {
    try {
      await _storageService.load();
    } catch (_) {}
    try {
      await _transcriptionService.requestPermissions();
    } catch (_) {}
    await _loadApiKey();
    await _loadRecordMode();
    if (mounted) {
      setState(() {});
    }
  }

  bool get motionSafe => !MediaQuery.of(context).disableAnimations;

  RecordButtonState get _buttonState {
    if (_isTranscribing) return RecordButtonState.transcribing;
    if (_isRecording) return RecordButtonState.recording;
    return RecordButtonState.idle;
  }

  String get _statusText {
    if (_isRecording) return 'Grabando...';
    if (_isTranscribing) return 'Procesando...';
    if (_pendingAudioPath != null) return 'Error, toca para reintentar';
    if (_resultText.isEmpty) return 'Listo para transcribir';
    return '';
  }

  void _hapticStart() => HapticFeedback.mediumImpact();
  void _hapticStop() => HapticFeedback.lightImpact();

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (_pendingAudioPath != null) {
        await _transcriptionService.cleanupTempFile(_pendingAudioPath!);
        setState(() => _pendingAudioPath = null);
      }
      final dir = await getTemporaryDirectory();
      // Encoder wav (PCM 16 bits + cabecera RIFF): Groq rechaza PCM crudo.
      final path =
          '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _transcriptionService.startRecording(path);
      if (mounted) {
        setState(() => _isRecording = true);
        _hapticStart();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar grabación: $e')),
        );
      }
    }
  }

  /// Hold demasiado corto (<300 ms): descartar como toque accidental.
  Future<void> _cancelHoldIfTooShort() async {
    final started = _holdStartedAt;
    _holdStartedAt = null;
    if (started == null || !_isRecording) return;
    if (DateTime.now().difference(started) >= const Duration(milliseconds: 300)) {
      return;
    }
    final path = await _transcriptionService.stopRecording();
    if (path != null) {
      await _transcriptionService.cleanupTempFile(path);
    }
    if (mounted) setState(() => _isRecording = false);
  }

  Future<void> _stopRecording() async {
    _hapticStop();
    final path = await _transcriptionService.stopRecording();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });
    }

    if (path == null) {
      if (mounted) {
        setState(() => _isTranscribing = false);
      }
      return;
    }

    try {
      final result = await _transcriptionService.transcribe(path);
      if (mounted) {
        setState(() {
          _resultText = result.text;
          _isTranscribing = false;
        });
        if (motionSafe) {
          _popupCtrl.forward(from: 0);
        } else {
          _popupCtrl.value = 1.0;
        }
      }
    } catch (e) {
      // Conservar el audio para reintento sin regrabar.
      if (mounted) {
        setState(() {
          _pendingAudioPath = path;
          _isTranscribing = false;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              action: SnackBarAction(
                label: 'Reintentar',
                onPressed: _retryPending,
              ),
            ),
          );
      }
    }
  }

  Future<void> _retryPending() async {
    final path = _pendingAudioPath;
    if (path == null || _isTranscribing || _isRecording) return;
    setState(() => _isTranscribing = true);
    try {
      final result = await _transcriptionService.transcribe(path);
      if (mounted) {
        setState(() {
          _resultText = result.text;
          _pendingAudioPath = null;
          _isTranscribing = false;
        });
        if (motionSafe) {
          _popupCtrl.forward(from: 0);
        } else {
          _popupCtrl.value = 1.0;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranscribing = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              action: SnackBarAction(
                label: 'Reintentar',
                onPressed: _retryPending,
              ),
            ),
          );
      }
    }
  }

  void _openHistory() {
    final transcriptions = _transcriptionService.history;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: kScrimColor,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.50,
          minChildSize: 0.25,
          maxChildSize: kHistorySheetMaxFactor,
          snap: true,
          snapSizes: const [0.50],
          builder: (_, scrollController) {
            return GlassContainer(
              borderRadius: kBorderRadiusSheet,
              small: false,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(sheetContext).pop(),
                    child: SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? kLabelTertiaryDark
                                : kLabelTertiaryLight,
                            borderRadius:
                                BorderRadius.circular(kBorderRadiusCapsule),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 52,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Historial',
                            style: kTextTitle.copyWith(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? kLabelPrimaryDark
                                  : kLabelPrimaryLight,
                            )),
                        Text('${transcriptions.length} / 20',
                            style: kTextCaption.copyWith(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? kLabelSecondaryDark
                                  : kLabelSecondaryLight,
                            )),
                      ],
                    ),
                  ),
                  Expanded(
                    child: HistoryList(transcriptions: transcriptions),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _copyToClipboard() async {
    if (_resultText.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: _resultText));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Texto copiado al portapapeles'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _popupCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final labelSecondary = Theme.of(context).brightness == Brightness.dark
        ? kLabelSecondaryDark
        : kLabelSecondaryLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VoiceBubble STT'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              await _loadApiKey();
              await _loadRecordMode();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Zona de gesto del historial (franja inferior completa).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: insets.bottom + 56,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openHistory,
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < -200) _openHistory();
              },
              child: Center(
                child: Semantics(
                  button: true,
                  label: 'Abrir historial',
                  child: GlassContainer(
                    borderRadius: kBorderRadiusCapsule,
                    small: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_rounded,
                            size: 18, color: labelSecondary),
                        const SizedBox(width: 6),
                        Text('Historial',
                            style:
                                kTextFootnote.copyWith(color: labelSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Contenido inferior: estado + tarjeta emergente + botón.
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              reverse: true,
              padding: EdgeInsets.only(bottom: insets.bottom + 72),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_resultText.isNotEmpty && !_isTranscribing)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TranscriptionPopup(
                        text: _resultText,
                        timestamp: DateTime.now(),
                        controller: _popupCtrl,
                        motionSafe: motionSafe,
                        onCopy: _copyToClipboard,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    _statusText,
                    style: kTextSubhead.copyWith(
                      color: _isRecording ? kRecording : labelSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  RecordButton(
                    key: const ValueKey('recordButton'),
                    state: _buttonState,
                    onPressed:
                        _recordMode == StorageService.defaultRecordMode
                            ? _toggleRecording
                            : null,
                    onHoldStart:
                        _recordMode == 'hold'
                            ? () {
                                _holdStartedAt = DateTime.now();
                                _startRecording();
                              }
                            : null,
                    onHoldEnd:
                        _recordMode == 'hold'
                            ? () async {
                                await _cancelHoldIfTooShort();
                                if (_holdStartedAt == null && _isRecording) {
                                  await _stopRecording();
                                }
                              }
                            : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
