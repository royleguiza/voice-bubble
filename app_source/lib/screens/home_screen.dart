import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/transcription_service.dart';
import '../services/storage_service.dart';
import '../services/cloud_stt_service.dart';
import '../services/local_stt_service.dart';
import '../ui/design_tokens.dart';
import 'settings_screen.dart';
import '../widgets/record_button.dart';
import '../widgets/history_list.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  late final TranscriptionService _transcriptionService;
  late final StorageService _storageService;
  final _secureStorage = const FlutterSecureStorage();

  bool _isRecording = false;
  bool _isTranscribing = false;
  String _resultText = '';
  String _currentMode = 'Cloud';

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
        localService: LocalSttService(),
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

  Future<void> _init() async {
    try {
      await _storageService.load();
    } catch (_) {}
    try {
      await _transcriptionService.requestPermissions();
    } catch (_) {}
    await _loadApiKey();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      final dir = await getTemporaryDirectory();
      // Encoder wav (PCM 16 bits + cabecera RIFF) y extension .wav:
      // Groq rechaza con 400 el PCM crudo de pcm16bits.
      final path =
          '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _transcriptionService.startRecording(path);
      if (mounted) {
        setState(() => _isRecording = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar grabación: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
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
      }
    } catch (e) {
      await _transcriptionService.cleanupTempFile(path);
      if (mounted) {
        setState(() => _isTranscribing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Mode selector
            SegmentedButton<TranscriptionMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: TranscriptionMode.cloud,
                  label: Text('Cloud'),
                  icon: Icon(Icons.cloud),
                ),
                ButtonSegment(
                  value: TranscriptionMode.local,
                  label: Text('Local'),
                  icon: Icon(Icons.phone_android),
                ),
              ],
              selected: {_transcriptionService.mode},
              onSelectionChanged: (modes) {
                setState(() {
                  _transcriptionService.setMode(modes.first);
                  _currentMode =
                      modes.first == TranscriptionMode.cloud ? 'Cloud' : 'Local';
                });
              },
            ),

            const SizedBox(height: 30),

            // Record button
            RecordButton(
              isRecording: _isRecording,
              isTranscribing: _isTranscribing,
              onPressed: _toggleRecording,
            ),

            const SizedBox(height: 20),

            // Status text
            Text(
              _isRecording
                  ? 'Grabando...'
                  : _isTranscribing
                      ? 'Procesando...'
                      : _resultText.isEmpty
                          ? 'Listo para transcribir'
                          : '',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _isRecording ? kRecording : null,
                  ),
            ),

            // Processing indicator
            if (_isTranscribing) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                backgroundColor: cs.surfaceContainerHighest,
                color: cs.primary,
              ),
            ],

            if (_resultText.isNotEmpty && !_isTranscribing) ...[
              const SizedBox(height: 16),

              // Result card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _resultText,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _currentMode,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: _copyToClipboard,
                            tooltip: 'Copiar texto',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // History
            Expanded(
              child: HistoryList(
                transcriptions: _transcriptionService.history,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
