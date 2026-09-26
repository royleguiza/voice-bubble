import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/transcription.dart';
import '../services/floating_bubble_service.dart';
import '../services/transcription_service.dart';
import '../widgets/record_button.dart';

/// Controlador del flujo y máquina de estados de grabación extraído de HomeScreen (C-33).
///
/// Encapsula:
/// - Estados de grabación/transcripción (idle, starting, recording, stopping, transcribing).
/// - Gestión de audios temporales y filtrado por tamaño mínimo (≥8000 bytes).
/// - Reintentos diferidos sin regrabar ante fallos de red.
/// - Sincronización visual con el servicio nativo de burbuja flotante.
/// - Notificación desacoplada a observadores de UI mediante [ChangeNotifier].
class RecordingController extends ChangeNotifier {
  final TranscriptionService transcriptionService;
  final FloatingBubbleService floatingBubbleService;
  final VoidCallback? onHapticStart;
  final VoidCallback? onHapticStop;
  final Future<void> Function(Transcription result)? onTranscriptionResult;
  final void Function(Object error, {required bool canRetry})? onError;
  final Future<void> Function()? onBeforeTranscribe;

  RecordingController({
    required this.transcriptionService,
    required this.floatingBubbleService,
    this.onHapticStart,
    this.onHapticStop,
    this.onTranscriptionResult,
    this.onError,
    this.onBeforeTranscribe,
  });

  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isStartingRecording = false;
  bool _isStoppingRecording = false;
  bool _shouldStopAfterStart = false;
  String? _pendingAudioPath;
  DateTime? _holdStartedAt;

  bool get isRecording => _isRecording;
  bool get isTranscribing => _isTranscribing;
  bool get isStartingRecording => _isStartingRecording;
  bool get isStoppingRecording => _isStoppingRecording;
  String? get pendingAudioPath => _pendingAudioPath;
  DateTime? get holdStartedAt => _holdStartedAt;
  set holdStartedAt(DateTime? dt) {
    _holdStartedAt = dt;
    notifyListeners();
  }

  /// Tamaño mínimo de audio útil para llamar a Groq (≥8000 bytes, C-24).
  static const int minAudioBytes = 8000;
  static const int _minAudioBytes = minAudioBytes;

  RecordButtonState get buttonState {
    if (_isTranscribing || _isStoppingRecording) {
      return RecordButtonState.transcribing;
    }
    if (_isRecording || _isStartingRecording) {
      return RecordButtonState.recording;
    }
    return RecordButtonState.idle;
  }

  String getStatusText({bool hasResult = false}) {
    if (_isRecording || _isStartingRecording) return 'Grabando...';
    if (_isTranscribing || _isStoppingRecording) return 'Procesando...';
    if (_pendingAudioPath != null) return 'Error, toca para reintentar';
    if (!hasResult) return 'Listo para transcribir';
    return '';
  }

  bool hasUsableAudio(String path) {
    try {
      final file = File(path);
      return file.existsSync() && file.lengthSync() >= _minAudioBytes;
    } catch (_) {
      return false;
    }
  }

  bool audioFileExists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleRecording() async {
    if (_isRecording || _isStartingRecording) {
      await stopRecording();
    } else {
      await startRecording();
    }
  }

  Future<void> startRecording() async {
    if (_isStartingRecording ||
        _isStoppingRecording ||
        _isRecording ||
        _isTranscribing) {
      return;
    }
    _isStartingRecording = true;
    _shouldStopAfterStart = false;
    final previousPending = _pendingAudioPath;
    _pendingAudioPath = null;
    notifyListeners();

    try {
      if (previousPending != null) {
        await transcriptionService.cleanupTempFile(previousPending);
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      await floatingBubbleService.updateBubbleState(BubbleVisualState.recording);

      await transcriptionService.startRecording(path);
      _isStartingRecording = false;
      _isRecording = true;
      onHapticStart?.call();
      notifyListeners();

      if (_shouldStopAfterStart) {
        _shouldStopAfterStart = false;
        await stopRecording();
      }
    } catch (e) {
      _isStartingRecording = false;
      _shouldStopAfterStart = false;
      await floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
      notifyListeners();
      onError?.call(e, canRetry: false);
    }
  }

  Future<void> cancelHoldIfTooShort() async {
    final started = _holdStartedAt;
    _holdStartedAt = null;
    if (started == null) return;
    if (DateTime.now().difference(started) < const Duration(milliseconds: 300)) {
      if (_isStartingRecording) {
        _shouldStopAfterStart = true;
      } else if (_isRecording) {
        final path = await transcriptionService.stopRecording();
        if (path != null) {
          await transcriptionService.cleanupTempFile(path);
        }
        await floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
        _isRecording = false;
        notifyListeners();
      }
    }
  }

  Future<void> stopRecording() async {
    if (_isStartingRecording) {
      _shouldStopAfterStart = true;
      return;
    }
    if (_isStoppingRecording || !_isRecording) {
      return;
    }
    _isStoppingRecording = true;
    onHapticStop?.call();
    try {
      await floatingBubbleService
          .updateBubbleState(BubbleVisualState.transcribing);

      _isRecording = false;
      _isTranscribing = true;
      notifyListeners();

      final path = await transcriptionService.stopRecording();
      _isStoppingRecording = false;

      if (path == null) {
        await floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
        _isTranscribing = false;
        notifyListeners();
        return;
      }

      if (!hasUsableAudio(path)) {
        await transcriptionService.cleanupTempFile(path);
        await floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
        _isTranscribing = false;
        notifyListeners();
        return;
      }

      try {
        await onBeforeTranscribe?.call();
        final result = await transcriptionService.transcribe(path);
        _pendingAudioPath = null;
        _isTranscribing = false;
        notifyListeners();
        if (onTranscriptionResult != null) {
          await onTranscriptionResult!(result);
        }
      } catch (e) {
        await floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
        final stillExists = audioFileExists(path);
        _pendingAudioPath = stillExists ? path : null;
        _isTranscribing = false;
        notifyListeners();
        onError?.call(e, canRetry: stillExists);
      }
    } catch (e) {
      try {
        await floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
      } catch (_) {}
      _isTranscribing = false;
      notifyListeners();
      onError?.call(e, canRetry: false);
    } finally {
      _isStoppingRecording = false;
      notifyListeners();
    }
  }

  Future<void> retryPending() async {
    final path = _pendingAudioPath;
    if (path == null || _isTranscribing || _isRecording) return;
    if (!hasUsableAudio(path)) {
      await transcriptionService.cleanupTempFile(path);
      _pendingAudioPath = null;
      _isTranscribing = false;
      notifyListeners();
      onError?.call('El audio pendiente ya no está disponible', canRetry: false);
      return;
    }

    _isTranscribing = true;
    notifyListeners();
    try {
      await onBeforeTranscribe?.call();
      final result = await transcriptionService.transcribe(path);
      _pendingAudioPath = null;
      _isTranscribing = false;
      notifyListeners();
      if (onTranscriptionResult != null) {
        await onTranscriptionResult!(result);
      }
    } catch (e) {
      final stillExists = audioFileExists(path);
      _pendingAudioPath = stillExists ? path : null;
      _isTranscribing = false;
      notifyListeners();
      onError?.call(e, canRetry: stillExists);
    }
  }

  void reset() {
    _isRecording = false;
    _isTranscribing = false;
    _isStartingRecording = false;
    _isStoppingRecording = false;
    _shouldStopAfterStart = false;
    _pendingAudioPath = null;
    _holdStartedAt = null;
    notifyListeners();
  }
}
