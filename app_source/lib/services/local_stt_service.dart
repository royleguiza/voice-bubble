import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../models/transcription.dart';

class LocalSttService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  Future<void> init() async {
    if (!_initialized) {
      _initialized = await _speech.initialize();
    }
  }

  bool get isAvailable => _speech.isAvailable;

  Future<Transcription> transcribe() async {
    if (!_initialized) {
      await init();
    }

    if (!_speech.isAvailable) {
      throw const LocalSttException(
          'Reconocimiento de voz no disponible en este dispositivo.');
    }

    final completer = Completer<Transcription>();

    _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.finalWords.isNotEmpty && !completer.isCompleted) {
          completer.complete(Transcription(
            text: result.finalWords,
            timestamp: DateTime.now(),
            isLocal: true,
          ));
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'es_ES',
    );

    Future.delayed(const Duration(seconds: 35), () {
      if (!completer.isCompleted) {
        _speech.stop();
        completer.complete(Transcription(
          text: '',
          timestamp: DateTime.now(),
          isLocal: true,
        ));
      }
    });

    return completer.future;
  }

  Future<void> stop() async {
    await _speech.stop();
  }
}

class LocalSttException implements Exception {
  final String message;
  const LocalSttException(this.message);

  @override
  String toString() => message;
}
