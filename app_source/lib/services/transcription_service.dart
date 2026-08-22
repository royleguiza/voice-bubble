import 'dart:io';
import 'package:record/record.dart';
import '../models/transcription.dart';
import 'cloud_stt_service.dart';
import 'local_stt_service.dart';
import 'storage_service.dart';

enum TranscriptionMode { cloud, local }

class TranscriptionService {
  CloudSttService _cloudService;
  final LocalSttService _localService;
  final StorageService _storageService;
  final AudioRecorder _recorder;

  TranscriptionMode _mode = TranscriptionMode.cloud;

  TranscriptionService({
    required CloudSttService cloudService,
    required LocalSttService localService,
    required StorageService storageService,
    AudioRecorder? recorder,
  })  : _cloudService = cloudService,
        _localService = localService,
        _storageService = storageService,
        _recorder = recorder ?? AudioRecorder();

  TranscriptionMode get mode => _mode;
  StorageService get storageService => _storageService;

  void setMode(TranscriptionMode newMode) {
    _mode = newMode;
  }

  Future<bool> requestPermissions() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  void updateApiKey(String apiKey) {
    _cloudService = CloudSttService(apiKey: apiKey);
  }

  Future<void> startRecording(String path) async {
    if (!await _recorder.hasPermission()) {
      throw const TranscriptionException('Permiso de micrófono denegado.');
    }

    await _recorder.start(
      RecordConfig(
        sampleRate: 16000,
        numChannels: 1,
        // AudioEncoder.wav = PCM 16 bits CON cabecera RIFF (WaveContainer).
        // pcm16bits escribe PCM crudo sin cabecera y Groq lo rechaza con 400.
        encoder: AudioEncoder.wav,
      ),
      path: path,
    );
  }

  Future<String?> stopRecording() async {
    return await _recorder.stop();
  }

  Future<Transcription> transcribe(String audioPath) async {
    try {
      final Transcription result;

      if (_mode == TranscriptionMode.cloud) {
        result = await _cloudService.transcribe(audioPath);
      } else {
        result = await _localService.transcribe();
      }

      if (result.text.isNotEmpty) {
        await _storageService.add(result);
      }

      return result;
    } finally {
      // Clean up temp audio file safely.
      // IO sincrona: los futures de dart:io no corren bajo fakeAsync (tests).
      try {
        final file = File(audioPath);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
  }

  Future<void> cleanupTempFile(String path) async {
    // IO sincrona: los futures de dart:io no corren bajo fakeAsync (tests).
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  List<Transcription> get history => _storageService.transcriptions;
}
