import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/transcription_service.dart';
import '../services/storage_service.dart';
import '../services/cloud_stt_service.dart';
import '../services/floating_bubble_service.dart';
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
  final FloatingBubbleService? floatingBubbleService;

  const HomeScreen({
    super.key,
    this.transcriptionService,
    this.storageService,
    this.floatingBubbleService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late final TranscriptionService _transcriptionService;
  late final StorageService _storageService;
  late final FloatingBubbleService _floatingBubbleService;
  final _secureStorage = const FlutterSecureStorage();

  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isStartingRecording = false;
  bool _isStoppingRecording = false;
  bool _shouldStopAfterStart = false;
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
    _floatingBubbleService =
        widget.floatingBubbleService ?? FloatingBubbleService();
    _floatingBubbleService.onBubbleTap = _handleBubbleTap;
    _floatingBubbleService.onBubbleClose = _handleBubbleClose;

    if (widget.transcriptionService != null) {
      _transcriptionService = widget.transcriptionService!;
      _storageService =
          widget.storageService ?? _transcriptionService.storageService;
    } else {
      _storageService = widget.storageService ?? StorageService();
      _transcriptionService = TranscriptionService(
        cloudService: const CloudSttService(apiKey: ''),
        storageService: _storageService,
      );
    }
    _init();
  }

  Future<void> _handleBubbleTap() async {
    if (_isTranscribing || _isStartingRecording || _isStoppingRecording) return;
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  void _handleBubbleClose() {
    _storageService.saveFloatingBubbleEnabled(false);
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
    try {
      final bubbleEnabled = await _storageService.loadFloatingBubbleEnabled();
      if (bubbleEnabled) {
        final hasPermission = await _floatingBubbleService.canDrawOverlays();
        if (hasPermission) {
          await _floatingBubbleService.startBubble();
        } else {
          await _storageService.saveFloatingBubbleEnabled(false);
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {});
    }
  }

  bool get motionSafe => !MediaQuery.of(context).disableAnimations;

  RecordButtonState get _buttonState {
    if (_isTranscribing || _isStoppingRecording) return RecordButtonState.transcribing;
    if (_isRecording || _isStartingRecording) return RecordButtonState.recording;
    return RecordButtonState.idle;
  }

  String get _statusText {
    if (_isRecording || _isStartingRecording) return 'Grabando...';
    if (_isTranscribing || _isStoppingRecording) return 'Procesando...';
    if (_pendingAudioPath != null) return 'Error, toca para reintentar';
    if (_resultText.isEmpty) return 'Listo para transcribir';
    return '';
  }

  void _hapticStart() => HapticFeedback.mediumImpact();
  void _hapticStop() => HapticFeedback.lightImpact();

  Future<void> _toggleRecording() async {
    if (_isRecording || _isStartingRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (_isStartingRecording || _isStoppingRecording || _isRecording || _isTranscribing) {
      return;
    }
    _isStartingRecording = true;
    _shouldStopAfterStart = false;
    final previousPending = _pendingAudioPath;
    _pendingAudioPath = null;
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() {});
    }

    try {
      if (previousPending != null) {
        await _transcriptionService.cleanupTempFile(previousPending);
      }
      final dir = await getTemporaryDirectory();
      // Encoder wav (PCM 16 bits + cabecera RIFF): Groq rechaza PCM crudo.
      final path =
          '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _transcriptionService.startRecording(path);
      await _floatingBubbleService
          .updateBubbleState(BubbleVisualState.recording);
      if (mounted) {
        setState(() {
          _isStartingRecording = false;
          _isRecording = true;
        });
        _hapticStart();
      } else {
        _isStartingRecording = false;
        _isRecording = true;
      }
      if (_shouldStopAfterStart) {
        _shouldStopAfterStart = false;
        await _stopRecording();
      }
    } catch (e) {
      _isStartingRecording = false;
      _shouldStopAfterStart = false;
      await _floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
      if (mounted) {
        setState(() {});
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
    if (started == null) return;
    if (DateTime.now().difference(started) < const Duration(milliseconds: 300)) {
      if (_isStartingRecording) {
        _shouldStopAfterStart = true;
      } else if (_isRecording) {
        final path = await _transcriptionService.stopRecording();
        if (path != null) {
          await _transcriptionService.cleanupTempFile(path);
        }
        await _floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
        if (mounted) setState(() => _isRecording = false);
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_isStartingRecording) {
      _shouldStopAfterStart = true;
      return;
    }
    if (_isStoppingRecording || !_isRecording) {
      return;
    }
    _isStoppingRecording = true;
    _hapticStop();
    await _floatingBubbleService
        .updateBubbleState(BubbleVisualState.transcribing);

    // Pasar a "Procesando" de inmediato: no dejar un frame de botón rojo
    // con overflow mientras se cierra el recorder.
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });
    }
    final path = await _transcriptionService.stopRecording();
    _isStoppingRecording = false;

    if (path == null) {
      await _floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
      if (mounted) {
        setState(() => _isTranscribing = false);
      }
      return;
    }

    // Verificar si el archivo tiene audio suficiente (>1000 bytes).
    // Si la grabación fue instantánea o vacía, se limpia sin llamar a Groq ni arrojar error.
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() < 1000) {
      await _transcriptionService.cleanupTempFile(path);
      await _floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
      if (mounted) {
        setState(() => _isTranscribing = false);
      }
      return;
    }

    try {
      final result = await _transcriptionService.transcribe(path);
      await Clipboard.setData(ClipboardData(text: result.text));
      await _floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
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
      await _floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
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
    await _floatingBubbleService
        .updateBubbleState(BubbleVisualState.transcribing);
    try {
      final result = await _transcriptionService.transcribe(path);
      await Clipboard.setData(ClipboardData(text: result.text));
      await _floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
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
      await _floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
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
          initialChildSize: kHistorySheetInitialFactor,
          minChildSize: 0.25,
          maxChildSize: kHistorySheetMaxFactor,
          snap: true,
          snapSizes: const [
            0.50,
            kHistorySheetMaxFactor,
          ],
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
                    child: HistoryList(
                      transcriptions: transcriptions,
                      // El ListView DEBE usar el controller del sheet:
                      // sin él, arrastrar la lista no expande el sheet
                      // y nunca se llega al snap del 90%.
                      scrollController: scrollController,
                    ),
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
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    storageService: _storageService,
                    floatingBubbleService: _floatingBubbleService,
                  ),
                ),
              );
              await _loadApiKey();
              await _loadRecordMode();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final historyBottom = insets.bottom + kHistoryPillBottomGap;
          final recordBottom =
              constraints.maxHeight * kRecordClusterBottomFactor;
          return Stack(
            children: [
              // Zona de gesto inferior para desplegar el historial.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: historyBottom + 52,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openHistory,
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) < -100) {
                      _openHistory();
                    }
                  },
                  onVerticalDragUpdate: (details) {
                    if (details.delta.dy < -8) {
                      _openHistory();
                    }
                  },
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Semantics(
                        button: true,
                        label: 'Abrir historial',
                        child: GlassContainer(
                          borderRadius: kBorderRadiusCapsule,
                          small: true,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history_rounded,
                                  size: 18, color: labelSecondary),
                              const SizedBox(width: 6),
                              Text('Historial',
                                  style: kTextFootnote.copyWith(
                                      color: labelSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: recordBottom,
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
                      onHoldStart: _recordMode == 'hold'
                          ? () {
                              _holdStartedAt = DateTime.now();
                              _startRecording();
                            }
                          : null,
                      onHoldEnd: _recordMode == 'hold'
                          ? () async {
                              await _cancelHoldIfTooShort();
                              if (_isRecording || _isStartingRecording) {
                                await _stopRecording();
                              }
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
