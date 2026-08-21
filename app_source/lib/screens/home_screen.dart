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
import 'package:path_provider/path_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TranscriptionService _transcriptionService;
  late final StorageService _storageService;

  bool _isRecording = false;
  bool _isTranscribing = false;
  String _resultText = '';
  String _currentMode = 'Cloud';

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    _transcriptionService = TranscriptionService(
      cloudService: const CloudSttService(apiKey: ''),
      localService: LocalSttService(),
      storageService: _storageService,
    );
    _init();
  }

  Future<void> _init() async {
    await _storageService.load();
    await _transcriptionService.requestPermissions();
    setState(() {});
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _transcriptionService.startRecording(path);
      setState(() => _isRecording = true);
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
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });

    if (path == null) {
      setState(() => _isTranscribing = false);
      return;
    }

    try {
      final result = await _transcriptionService.transcribe(path);
      setState(() {
        _resultText = result.text;
        _isTranscribing = false;
      });
    } catch (e) {
      await _transcriptionService.cleanupTempFile(path);
      setState(() => _isTranscribing = false);
      if (mounted) {
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
                  _transcriptionService.mode = modes.first;
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
