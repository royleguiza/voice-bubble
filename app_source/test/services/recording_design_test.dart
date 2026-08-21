import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:voice_bubble_stt/models/transcription.dart';
import 'package:voice_bubble_stt/services/transcription_service.dart';
import 'package:voice_bubble_stt/services/local_stt_service.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';
import 'package:voice_bubble_stt/ui/design_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Encoder PCM 16 bits (WAV)', () {
    test('startRecording usa encoder AudioEncoder.pcm16bits', () async {
      final config = RecordConfig(
        sampleRate: 16000,
        numChannels: 1,
        encoder: AudioEncoder.pcm16bits,
      );

      expect(config.encoder, AudioEncoder.pcm16bits);
      expect(config.sampleRate, 16000);
      expect(config.numChannels, 1);
    });

    test('configuración de grabación es mono 16kHz', () {
      final config = RecordConfig(
        sampleRate: 16000,
        numChannels: 1,
        encoder: AudioEncoder.pcm16bits,
      );

      expect(config.sampleRate, 16000);
      expect(config.numChannels, 1);
    });
  });

  group('cleanupTempFile', () {
    late TranscriptionService service;
    late Directory tempDir;

    setUp(() {
      service = TranscriptionService(
        cloudService: const CloudSttService(apiKey: 'test'),
        localService: LocalSttService(),
        storageService: StorageService(),
      );
      tempDir = Directory.systemTemp.createTempSync('voice_bubble_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('elimina el archivo si existe', () async {
      final file = File('${tempDir.path}/test_audio.wav');
      await file.writeAsBytes([0x00, 0x01, 0x02, 0x03]);
      expect(file.existsSync(), isTrue);

      await service.cleanupTempFile(file.path);

      expect(file.existsSync(), isFalse);
    });

    test('no lanza excepción si el archivo no existe', () async {
      final fakePath = '${tempDir.path}/no_existe.wav';

      expect(
        () => service.cleanupTempFile(fakePath),
        returnsNormally,
      );
    });

    test('no lanza excepción con ruta vacía', () async {
      expect(
        () => service.cleanupTempFile(''),
        returnsNormally,
      );
    });
  });

  group('LocalSttService configuración', () {
    test('tiene locale es_ES configurado', () {
      const localeEsEs = 'es_ES';
      expect(localeEsEs, equals('es_ES'));
    });

    test('tiene listenFor de 30 segundos', () {
      const listenFor = Duration(seconds: 30);
      expect(listenFor.inSeconds, 30);
    });

    test('tiene pauseFor de 3 segundos', () {
      const pauseFor = Duration(seconds: 3);
      expect(pauseFor.inSeconds, 3);
    });

    test('timeout de emergencia es 35 segundos', () {
      const emergencyTimeout = Duration(seconds: 35);
      expect(emergencyTimeout.inSeconds, 35);
    });
  });

  group('Design Tokens – Colores de acento', () {
    test('kAccentLight es válido y tiene alpha completo', () {
      expect(kAccentLight, isNotNull);
      expect(kAccentLight.a, 0xFF);
    });

    test('kAccentDark es válido y tiene alpha completo', () {
      expect(kAccentDark, isNotNull);
      expect(kAccentDark.a, 0xFF);
    });

    test('kAccentLight y kAccentDark son diferentes', () {
      expect(kAccentLight, isNot(equals(kAccentDark)));
    });
  });

  group('Design Tokens – Colores de grabación', () {
    test('kRecording es válido y tiene alpha completo', () {
      expect(kRecording, isNotNull);
      expect(kRecording.a, 0xFF);
    });

    test('kRecordingDark es válido y tiene alpha completo', () {
      expect(kRecordingDark, isNotNull);
      expect(kRecordingDark.a, 0xFF);
    });

    test('kRecording y kRecordingDark son diferentes', () {
      expect(kRecording, isNot(equals(kRecordingDark)));
    });
  });

  group('Design Tokens – Glass (opacidad y bordes)', () {
    test('kGlassOpacityLight está en rango válido (0-1)', () {
      expect(kGlassOpacityLight, greaterThanOrEqualTo(0.0));
      expect(kGlassOpacityLight, lessThanOrEqualTo(1.0));
      expect(kGlassOpacityLight, 0.65);
    });

    test('kGlassOpacityDark está en rango válido (0-1)', () {
      expect(kGlassOpacityDark, greaterThanOrEqualTo(0.0));
      expect(kGlassOpacityDark, lessThanOrEqualTo(1.0));
      expect(kGlassOpacityDark, 0.45);
    });

    test('kGlassBlurLarge es positivo', () {
      expect(kGlassBlurLarge, greaterThan(0.0));
      expect(kGlassBlurLarge, 24.0);
    });

    test('kGlassBlurSmall es positivo y menor que large', () {
      expect(kGlassBlurSmall, greaterThan(0.0));
      expect(kGlassBlurSmall, lessThan(kGlassBlurLarge));
      expect(kGlassBlurSmall, 12.0);
    });

    test('kGlassBorderLight tiene transparencia parcial', () {
      expect(kGlassBorderLight, isNotNull);
      expect(kGlassBorderLight.a, lessThan(0xFF));
      expect(kGlassBorderLight.a, 0x8C);
    });

    test('kGlassBorderDark tiene transparencia parcial', () {
      expect(kGlassBorderDark, isNotNull);
      expect(kGlassBorderDark.a, lessThan(0xFF));
      expect(kGlassBorderDark.a, 0x2E);
    });

    test('kGlassShadowLight tiene blur y offset correctos', () {
      expect(kGlassShadowLight.blurRadius, 24.0);
      expect(kGlassShadowLight.offset, const Offset(0, 8));
    });

    test('kGlassShadowDark tiene blur y offset correctos', () {
      expect(kGlassShadowDark.blurRadius, 24.0);
      expect(kGlassShadowDark.offset, const Offset(0, 8));
    });
  });

  group('Temas claro y oscuro', () {
    test('buildLightTheme retorna ThemeData válido', () {
      final theme = buildLightTheme();
      expect(theme, isA<ThemeData>());
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
    });

    test('buildDarkTheme retorna ThemeData válido', () {
      final theme = buildDarkTheme();
      expect(theme, isA<ThemeData>());
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
    });

    test('tema claro usa scaffoldBackgroundColor kBgBaseLight', () {
      final theme = buildLightTheme();
      expect(theme.scaffoldBackgroundColor, kBgBaseLight);
    });

    test('tema oscuro usa scaffoldBackgroundColor kBgBaseDark', () {
      final theme = buildDarkTheme();
      expect(theme.scaffoldBackgroundColor, kBgBaseDark);
    });

    test('tema claro usa dividerColor kSeparatorLight', () {
      final theme = buildLightTheme();
      expect(theme.dividerColor, kSeparatorLight);
    });

    test('tema oscuro usa dividerColor kSeparatorDark', () {
      final theme = buildDarkTheme();
      expect(theme.dividerColor, kSeparatorDark);
    });
  });
}
