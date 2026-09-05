import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
  });

  group('StorageService - Píldora e Isla Dinámica (MEJ-18)', () {
    test('Claves y defaults oficiales correctos', () async {
      expect(StorageService.bubbleDockingModeKey, 'bubble_docking_mode');
      expect(StorageService.defaultBubbleDockingMode, 'dynamic_island');
      expect(StorageService.bubbleDockingModes, ['dynamic_island', 'classic_bubble']);

      expect(StorageService.islandPosXKey, 'island_pos_x');
      expect(StorageService.defaultIslandPosX, 0);

      expect(StorageService.islandPosYKey, 'island_pos_y');
      expect(StorageService.defaultIslandPosY, 12);

      expect(StorageService.islandWidthKey, 'island_width');
      expect(StorageService.defaultIslandWidth, 184);

      expect(StorageService.islandHeightKey, 'island_height');
      expect(StorageService.defaultIslandHeight, 36);

      expect(StorageService.islandSlotOrderKey, 'island_slot_order');
      expect(StorageService.defaultIslandSlotOrder, 'trackpad_camera_mic');
      expect(StorageService.islandSlotOrders, ['trackpad_camera_mic', 'mic_camera_trackpad']);

      expect(StorageService.islandThemeKey, 'island_theme');
      expect(StorageService.defaultIslandTheme, 'dark');
      expect(StorageService.islandThemes, ['glass', 'dark', 'light']);

      expect(StorageService.islandWaveformEnabledKey, 'island_waveform_enabled');
      expect(StorageService.defaultIslandWaveformEnabled, true);

      expect(await storage.getBubbleDockingMode(), 'dynamic_island');
      expect(await storage.getIslandPosX(), 0);
      expect(await storage.getIslandPosY(), 12);
      expect(await storage.getIslandWidth(), 184);
      expect(await storage.getIslandHeight(), 36);
      expect(await storage.getIslandSlotOrder(), 'trackpad_camera_mic');
      expect(await storage.getIslandTheme(), 'dark');
      expect(await storage.getIslandWaveformEnabled(), true);
    });

    test('Persistencia y clamping de coordenadas X e Y', () async {
      await storage.setIslandPosX(50);
      expect(await storage.getIslandPosX(), 50);

      // Clamping X a [-160, 160]
      await storage.setIslandPosX(300);
      expect(await storage.getIslandPosX(), 160);
      await storage.setIslandPosX(-300);
      expect(await storage.getIslandPosX(), -160);

      // Y a [-100, 120]
      await storage.setIslandPosY(45);
      expect(await storage.getIslandPosY(), 45);
      await storage.setIslandPosY(-20);
      expect(await storage.getIslandPosY(), -20);
      await storage.setIslandPosY(-150);
      expect(await storage.getIslandPosY(), -100);
      await storage.setIslandPosY(200);
      expect(await storage.getIslandPosY(), 120);
    });

    test('Persistencia y clamping de Ancho y Altura', () async {
      await storage.setIslandWidth(200);
      expect(await storage.getIslandWidth(), 200);
      await storage.setIslandWidth(50);
      expect(await storage.getIslandWidth(), 130);
      await storage.setIslandWidth(500);
      expect(await storage.getIslandWidth(), 320);

      await storage.setIslandHeight(40);
      expect(await storage.getIslandHeight(), 40);
      await storage.setIslandHeight(10);
      expect(await storage.getIslandHeight(), 28);
      await storage.setIslandHeight(90);
      expect(await storage.getIslandHeight(), 48);
    });

    test('Persistencia y validación de Modos, Ranuras, Temas y Waveform', () async {
      await storage.setBubbleDockingMode('classic_bubble');
      expect(await storage.getBubbleDockingMode(), 'classic_bubble');
      await storage.setBubbleDockingMode('invalido');
      expect(await storage.getBubbleDockingMode(), 'classic_bubble');

      await storage.setIslandSlotOrder('mic_camera_trackpad');
      expect(await storage.getIslandSlotOrder(), 'mic_camera_trackpad');
      await storage.setIslandSlotOrder('desconocido');
      expect(await storage.getIslandSlotOrder(), 'mic_camera_trackpad');

      await storage.setIslandTheme('dark');
      expect(await storage.getIslandTheme(), 'dark');
      await storage.setIslandTheme('light');
      expect(await storage.getIslandTheme(), 'light');
      await storage.setIslandTheme('invalido');
      expect(await storage.getIslandTheme(), 'light');

      await storage.setIslandWaveformEnabled(false);
      expect(await storage.getIslandWaveformEnabled(), false);
      await storage.setIslandWaveformEnabled(true);
      expect(await storage.getIslandWaveformEnabled(), true);
    });
  });
}
