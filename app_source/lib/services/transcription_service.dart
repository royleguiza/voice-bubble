import 'dart:io';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import '../models/transcription.dart';
import 'cloud_stt_service.dart';
import 'keyboard_service.dart';
import 'storage_service.dart';

/// Exclusion mutua del microfono (C-05): el claim atomico vive en nativo
/// (`BackgroundWork`) y lo comparten TODOS los entrypoints (teclado, widget,
/// burbuja y Notas). Inyectable para tests; 0 = microfono ocupado.
typedef MicClaimer = Future<int> Function();
typedef MicClaimReleaser = Future<void> Function(int claim);

Future<int> _defaultMicClaimer() async {
  try {
    const channel = MethodChannel(KeyboardService.channelName);
    return await channel.invokeMethod<int>('claimMicrophone') ?? 0;
  } catch (_) {
    return 0;
  }
}

Future<void> _defaultMicClaimReleaser(int claim) async {
  if (claim == 0) return;
  try {
    const channel = MethodChannel(KeyboardService.channelName);
    await channel.invokeMethod<bool>(
      'releaseMicrophone',
      <String, Object?>{'claim': claim},
    );
  } catch (_) {}
}

class TranscriptionService {
  CloudSttService _cloudService;
  final StorageService _storageService;
  final AudioRecorder _recorder;
  final MicClaimer _claimMicrophone;
  final MicClaimReleaser _releaseMicrophone;
  int _activeClaim = 0;

  TranscriptionService({
    required CloudSttService cloudService,
    required StorageService storageService,
    AudioRecorder? recorder,
    MicClaimer? claimMicrophone,
    MicClaimReleaser? releaseMicrophone,
  })  : _cloudService = cloudService,
        _storageService = storageService,
        _recorder = recorder ?? AudioRecorder(),
        _claimMicrophone = claimMicrophone ?? _defaultMicClaimer,
        _releaseMicrophone = releaseMicrophone ?? _defaultMicClaimReleaser;

  StorageService get storageService => _storageService;
  CloudSttService get cloudService => _cloudService;

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
    _cloudService = _cloudService.copyWith(apiKey: apiKey);
  }

  Future<void> startRecording(String path) async {
    if (!await _recorder.hasPermission()) {
      throw const TranscriptionException('Permiso de micrófono denegado.');
    }
    final claim = await _claimMicrophone();
    if (claim == 0) {
      throw const TranscriptionException(
        'El micrófono está siendo usado por el teclado.',
      );
    }
    _activeClaim = claim;
    try {
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
    } catch (_) {
      await releaseMicrophoneClaim();
      rethrow;
    }
  }

  Future<String?> stopRecording() async {
    final claim = _activeClaim;
    _activeClaim = 0;
    try {
      return await _recorder.stop();
    } finally {
      await _releaseMicrophone(claim);
    }
  }

  /// Libera el claim sin cerrar el recorder (canceles y teardown de UI).
  Future<void> releaseMicrophoneClaim() async {
    final claim = _activeClaim;
    _activeClaim = 0;
    await _releaseMicrophone(claim);
  }

  /// Claim vivo de este servicio (false = microfono libre para los demas).
  bool get hasMicrophoneClaim => _activeClaim != 0;

  /// Transcribe el audio en [audioPath] con el motor cloud.
  ///
  /// En éxito el llamador decide si borra el archivo temporal. En fallo lo
  /// conserva para permitir reintento sin regrabar.
  ///
  /// Vuelo único (C-43): solo una subida a la vez en todo el proceso; un
  /// segundo intento concurrente recibe error ocupado en vez de golpear
  /// la cuota de Groq en paralelo. Se transcribe lo seleccionado, nada más.
  static bool _uploadInFlight = false;

  Future<Transcription> transcribe(
    String audioPath, {
    bool deleteAudioOnSuccess = true,
  }) async {
    if (_uploadInFlight) {
      throw const TranscriptionException(
        'Ya hay una transcripción en curso. Esperá a que termine.',
        kind: TranscriptionErrorKind.badRequest,
      );
    }
    _uploadInFlight = true;
    try {
      return await _transcribeGuarded(
        audioPath,
        deleteAudioOnSuccess: deleteAudioOnSuccess,
      );
    } finally {
      _uploadInFlight = false;
    }
  }

  Future<Transcription> _transcribeGuarded(
    String audioPath, {
    bool deleteAudioOnSuccess = true,
  }) async {
    final result = await _cloudService.transcribe(audioPath);

    if (result.text.isNotEmpty) {
      final saved = await _storageService.add(result);
      if (!saved) {
        throw const TranscriptionException(
          'No se pudo guardar la transcripción en el historial (disco lleno o error de almacenamiento).',
          kind: TranscriptionErrorKind.server,
        );
      }
    }

    // C-10: no borrar temporal si el texto devuelto es vacío para permitir reintento
    if (deleteAudioOnSuccess && result.text.isNotEmpty) {
      try {
        final file = File(audioPath);
        if (file.existsSync()) {
          _secureDeleteSync(file);
        }
      } catch (_) {}
    }

    return result;
  }

  /// Sobreescribe con ceros antes de borrar (C-35) para mitigar recuperación forense.
  static void _secureDeleteSync(File file) {
    try {
      if (file.existsSync()) {
        final length = file.lengthSync();
        if (length > 0) {
          final zeros = Uint8List(length < 65536 ? length : 65536);
          final raf = file.openSync(mode: FileMode.write);
          var remaining = length;
          while (remaining > 0) {
            final toWrite = remaining < zeros.length ? remaining : zeros.length;
            raf.writeFromSync(zeros, 0, toWrite);
            remaining -= toWrite;
          }
          raf.flushSync();
          raf.closeSync();
        }
        file.deleteSync();
      }
    } catch (_) {
      try {
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    }
  }

  Future<void> cleanupTempFile(String path) async {
    // IO sincrona segura: los futures de dart:io no corren bajo fakeAsync (tests).
    try {
      final file = File(path);
      if (file.existsSync()) {
        _secureDeleteSync(file);
      }
    } catch (_) {}
  }

  List<Transcription> get history => _storageService.transcriptions;
}
