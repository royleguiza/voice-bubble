import 'dart:io';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import '../models/transcription.dart';
import 'cloud_stt_service.dart';
import 'keyboard_service.dart';
import 'storage_service.dart';

/// Sonda de ocupacion del microfono del teclado (exclusion mutua K3).
/// Inyectable para tests; por defecto consulta el canal nativo.
typedef MicBlockedProbe = Future<bool> Function();

Future<bool> _defaultMicBlockedProbe() async {
  try {
    const channel = MethodChannel(KeyboardService.channelName);
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

  /// Solicita el permiso de micrófono. SOLO debe llamarse en intención
  /// explícita de grabar (p.ej. al pulsar grabar y el permiso aún no está
  /// concedido): `hasPermission()` dispara el prompt del sistema, por lo
  /// que llamarlo en el arranque de la app molesta al usuario sin motivo.
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

    // Borrado async sin exists() previo (sin TOCTOU y sin
    // `avoid_slow_async_io`: delete no está en su lista): el sync atascaba
    // frames en eMMC lentas. Sin fakeAsync en los tests de estas rutas.
    try {
      await File(audioPath).delete();
    } catch (_) {}

    return result;
  }

  Future<void> cleanupTempFile(String path) async {
    // Idem: delete-en-try en vez de existsSync/deleteSync.
    try {
      await File(path).delete();
    } catch (_) {}
  }

  List<Transcription> get history => _storageService.transcriptions;
}
