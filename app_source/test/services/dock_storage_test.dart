import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/services/floating_bubble_service.dart';
import 'package:voice_bubble_stt/services/floating_trackpad_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

/// Barra flotante: preferencias que lee Kotlin (DockController /
/// FloatingTrackpadService) y canales nativos nuevos.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('StorageService - barra flotante', () {
    test('valores por defecto: barra, micrófono sí, puntero no, panel', () async {
      final s = StorageService();
      expect(await s.getDockForm(), 'edge');
      expect(await s.getDockToolMic(), isTrue);
      expect(await s.getDockToolPointer(), isFalse);
      expect(await s.getPointerOpenMode(), 'panel');
    });

    test('guarda y relee forma, herramientas y modo', () async {
      final s = StorageService();
      await s.setDockForm('bubble');
      await s.setDockToolMic(false);
      await s.setDockToolPointer(true);
      await s.setPointerOpenMode('window');
      expect(await s.getDockForm(), 'bubble');
      expect(await s.getDockToolMic(), isFalse);
      expect(await s.getDockToolPointer(), isTrue);
      expect(await s.getPointerOpenMode(), 'window');
    });

    test('valores fuera de dominio no se escriben', () async {
      final s = StorageService();
      await s.setDockForm('cometa');
      await s.setPointerOpenMode('pantalla');
      final p = await SharedPreferences.getInstance();
      expect(p.containsKey(StorageService.dockFormKey), isFalse);
      expect(p.containsKey(StorageService.pointerOpenModeKey), isFalse);
    });

    test('basura guardada cae al valor por defecto', () async {
      SharedPreferences.setMockInitialValues({
        'dock_form': 'cometa',
        'pointer_open_mode': 7,
        'dock_tool_mic': 'false',
      });
      final s = StorageService();
      expect(await s.getDockForm(), 'edge');
      expect(await s.getPointerOpenMode(), 'panel');
      expect(await s.getDockToolMic(), isFalse);
    });

    test('las claves nuevas están en el contrato del puente', () {
      for (final k in [
        StorageService.dockFormKey,
        StorageService.dockToolMicKey,
        StorageService.dockToolPointerKey,
        StorageService.pointerOpenModeKey,
      ]) {
        expect(StorageService.bridgeKeys, contains(k));
      }
    });

    test('los dominios coinciden con lo que entiende Kotlin', () {
      // DockGeometry.Form.fromPref ("edge"/"bubble") y
      // FloatingTrackpadService.MODE_PANEL/MODE_WINDOW.
      expect(StorageService.dockForms, ['edge', 'bubble']);
      expect(StorageService.pointerOpenModes, ['panel', 'window']);
    });
  });

  group('FloatingTrackpadService - complemento', () {
    const channel = MethodChannel(FloatingTrackpadService.channelName);
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    for (final status in FloatingTrackpadService.pointerStatuses) {
      test('devuelve el estado "$status" del nativo', () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getPointerStatus') return status;
          return null;
        });
        expect(await FloatingTrackpadService().getPointerStatus(), status);
      });
    }

    test('un estado desconocido o nulo cuenta como no instalado', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => 'raro');
      expect(await FloatingTrackpadService().getPointerStatus(),
          FloatingTrackpadService.pointerMissing);
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      expect(await FloatingTrackpadService().getPointerStatus(),
          FloatingTrackpadService.pointerMissing);
    });

    test('un error de canal no rompe: no instalado', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'BROKEN');
      });
      expect(await FloatingTrackpadService().getPointerStatus(),
          FloatingTrackpadService.pointerMissing);
    });

    test('abre la información del complemento', () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return true;
      });
      expect(await FloatingTrackpadService().openCompanionDetails(), isTrue);
      expect(calls, ['openCompanionDetails']);
    });
  });

  group('FloatingBubbleService - recarga de la barra', () {
    const channel = MethodChannel(FloatingBubbleService.channelName);
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('reloadDock invoca el método nativo', () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return true;
      });
      expect(await FloatingBubbleService().reloadDock(), isTrue);
      expect(calls, ['reloadDock']);
    });

    test('sin barra viva devuelve false sin lanzar', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => false);
      expect(await FloatingBubbleService().reloadDock(), isFalse);
    });
  });
}
