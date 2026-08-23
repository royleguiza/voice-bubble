import 'dart:io';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import '../models/transcription.dart';
import 'cloud_stt_service.dart';
import 'storage_service.dart';

/// Sonda de ocupacion del microfono del teclado (exclusion mutua K3).
/// Inyectable para tests; por defecto consulta el canal nativo.
typedef MicBlockedProbe = Future<bool> Function();

Future<bool> _defaultMicBlockedProbe() async {
  try {
    const channel = MethodChannel('com.royleguiza.voicebubblestt/keyboard');
    return await channel.invokeMethod<bool>('isKeyboardRecording') ?? false;
  } catch (_) {
    return false;
  }
}

class TranscriptionService {
  CloudSttService _cloudService;
  final StorageService _storageService;
  final AudioRecorder _recorder;
  final MicBlockedProbe _isMicBlocked;

  TranscriptionService({
    required CloudSttService cloudService,
    required StorageService storageService,
    AudioRecorder? recorder,
    MicBlockedProbe? isMicBlocked,
  })  : _cloudService = cloudService,
        _storageService = storageService,
        _recorder = recorder ?? AudioRecorder(),
        _isMicBlocked = isMicBlocked ?? _defaultMicBlockedProbe;

  StorageService get storageService => _storageService;

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
    // Exclusion mutua burbuja<->teclado: si el teclado esta grabando, la
    // burbuja no inicia (y viceversa, el teclado chequea el estado burbuja).
    if (await _isMicBlocked()) {
      throw const TranscriptionException(
        'El micrófono está siendo usado por el teclado.',
      );
    }
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

  /// Transcribe el audio en [audioPath] con el motor cloud.
  ///
  /// En éxito borra el archivo temporal. En fallo lo CONSERVA para permitir
  /// reintento sin regrabar (la UI decide cuándo limpiarlo).
  Future<Transcription> transcribe(String audioPath) async {
    final result = await _cloudService.transcribe(audioPath);

    if (result.text.isNotEmpty) {
      await _storageService.add(result);
    }

    try {
      final file = File(audioPath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}

    return result;
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
