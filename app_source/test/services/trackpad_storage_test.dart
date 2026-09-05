import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StorageService - Trackpad Preferences', () {
    test('default values match contract specifications', () async {
      final storage = StorageService();

      expect(await storage.getTrackpadEnabled(), isTrue);
      expect(await storage.getTrackpadToolbarVisible(), isTrue);
      expect(await storage.getTrackpadScrollPosition(), 'right');
      expect(await storage.getTrackpadSensitivity(), 1.2);
      expect(await storage.getTrackpadAccelCurve(), 'dynamic');
      expect(await storage.getTrackpadTapToClick(), isTrue);
      expect(await storage.getTrackpadSecondaryClick(), '2fingers');
      expect(await storage.getTrackpadScrollDirection(), 'natural');
      expect(await storage.getTrackpadHaptic(), 'subtle');
      expect(await storage.getTrackpadPointerStyle(), 'arrow');
      expect(await storage.getTrackpadAutoReturn(), 0);
      expect(await storage.getTrackpadButtonLayout(), 'top');
      expect(await storage.getSpacebarTrackpadMode(), 'ios_2d');
    });

    test('trackpad enabled setter persists in SharedPreferences', () async {
      final storage = StorageService();
      await storage.setTrackpadEnabled(false);

      expect(await storage.getTrackpadEnabled(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(StorageService.kbTrackpadEnabledKey), isFalse);
    });

    test('trackpad toolbar visible setter persists in SharedPreferences', () async {
      final storage = StorageService();
      await storage.setTrackpadToolbarVisible(false);

      expect(await storage.getTrackpadToolbarVisible(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(StorageService.kbTrackpadToolbarVisibleKey), isFalse);
    });

    test('scroll position setter accepts valid options and rejects invalid', () async {
      final storage = StorageService();

      await storage.setTrackpadScrollPosition('left');
      expect(await storage.getTrackpadScrollPosition(), 'left');

      await storage.setTrackpadScrollPosition('disabled');
      expect(await storage.getTrackpadScrollPosition(), 'disabled');

      // Invalid value ignored by setter
      await storage.setTrackpadScrollPosition('invalid_mode');
      expect(await storage.getTrackpadScrollPosition(), 'disabled');

      // Corrupted value in SharedPreferences falls back to default
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageService.kbTrackpadScrollPositionKey, 'corrupt');
      expect(await storage.getTrackpadScrollPosition(), 'right');
    });

    test('sensitivity setter and getter clamp values between 0.5 and 2.5', () async {
      final storage = StorageService();

      await storage.setTrackpadSensitivity(1.8);
      expect(await storage.getTrackpadSensitivity(), 1.8);

      // Clamp lower bound
      await storage.setTrackpadSensitivity(0.1);
      expect(await storage.getTrackpadSensitivity(), 0.5);

      // Clamp upper bound
      await storage.setTrackpadSensitivity(3.5);
      expect(await storage.getTrackpadSensitivity(), 2.5);

      // Corrupted value in storage is clamped on read
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(StorageService.kbTrackpadSensitivityKey, 9.9);
      expect(await storage.getTrackpadSensitivity(), 2.5);
    });

    test('acceleration curve setter persists valid curves and falls back on corrupt', () async {
      final storage = StorageService();

      await storage.setTrackpadAccelCurve('linear');
      expect(await storage.getTrackpadAccelCurve(), 'linear');

      await storage.setTrackpadAccelCurve('precision');
      expect(await storage.getTrackpadAccelCurve(), 'precision');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageService.kbTrackpadAccelCurveKey, 'unknown');
      expect(await storage.getTrackpadAccelCurve(), 'dynamic');
    });

    test('tap to click setter persists boolean in SharedPreferences', () async {
      final storage = StorageService();
      await storage.setTrackpadTapToClick(false);

      expect(await storage.getTrackpadTapToClick(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(StorageService.kbTrackpadTapToClickKey), isFalse);
    });

    test('secondary click setter persists valid modes', () async {
      final storage = StorageService();

      await storage.setTrackpadSecondaryClick('button');
      expect(await storage.getTrackpadSecondaryClick(), 'button');

      await storage.setTrackpadSecondaryClick('hold');
      expect(await storage.getTrackpadSecondaryClick(), 'hold');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageService.kbTrackpadSecondaryClickKey, 'invalid');
      expect(await storage.getTrackpadSecondaryClick(), '2fingers');
    });

    test('scroll direction setter persists natural and standard', () async {
      final storage = StorageService();

      await storage.setTrackpadScrollDirection('standard');
      expect(await storage.getTrackpadScrollDirection(), 'standard');

      await storage.setTrackpadScrollDirection('natural');
      expect(await storage.getTrackpadScrollDirection(), 'natural');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageService.kbTrackpadScrollDirectionKey, 'reverse');
      expect(await storage.getTrackpadScrollDirection(), 'natural');
    });

    test('haptic setter persists subtle, none, firm', () async {
      final storage = StorageService();

      await storage.setTrackpadHaptic('firm');
      expect(await storage.getTrackpadHaptic(), 'firm');

      await storage.setTrackpadHaptic('none');
      expect(await storage.getTrackpadHaptic(), 'none');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageService.kbTrackpadHapticKey, 'crazy');
      expect(await storage.getTrackpadHaptic(), 'subtle');
    });

    test('pointer style setter persists arrow, dot, cross', () async {
      final storage = StorageService();

      await storage.setTrackpadPointerStyle('dot');
      expect(await storage.getTrackpadPointerStyle(), 'dot');

      await storage.setTrackpadPointerStyle('cross');
      expect(await storage.getTrackpadPointerStyle(), 'cross');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageService.kbTrackpadPointerStyleKey, 'hand');
      expect(await storage.getTrackpadPointerStyle(), 'arrow');
    });

    test('auto return setter persists 0, 5, 15, 30 seconds', () async {
      final storage = StorageService();

      await storage.setTrackpadAutoReturn(5);
      expect(await storage.getTrackpadAutoReturn(), 5);

      await storage.setTrackpadAutoReturn(15);
      expect(await storage.getTrackpadAutoReturn(), 15);

      await storage.setTrackpadAutoReturn(30);
      expect(await storage.getTrackpadAutoReturn(), 30);

      // Invalid value rejected
      await storage.setTrackpadAutoReturn(60);
      expect(await storage.getTrackpadAutoReturn(), 30);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(StorageService.kbTrackpadAutoReturnKey, 999);
      expect(await storage.getTrackpadAutoReturn(), 0);
    });

    test('trackpad button layout setter persists top and wings', () async {
      final storage = StorageService();

      expect(await storage.getTrackpadButtonLayout(), 'top');

      await storage.setTrackpadButtonLayout('wings');
      expect(await storage.getTrackpadButtonLayout(), 'wings');

      await storage.setTrackpadButtonLayout('invalid_layout');
      expect(await storage.getTrackpadButtonLayout(), 'wings');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageService.kbTrackpadButtonLayoutKey, 'corrupt');
      expect(await storage.getTrackpadButtonLayout(), 'top');
    });

    test('spacebar trackpad mode setter persists ios_2d and gboard_horizontal', () async {
      final storage = StorageService();

      expect(await storage.getSpacebarTrackpadMode(), 'ios_2d');

      await storage.setSpacebarTrackpadMode('gboard_horizontal');
      expect(await storage.getSpacebarTrackpadMode(), 'gboard_horizontal');

      await storage.setSpacebarTrackpadMode('invalid_mode');
      expect(await storage.getSpacebarTrackpadMode(), 'gboard_horizontal');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageService.kbSpacebarTrackpadModeKey, 'corrupt');
      expect(await storage.getSpacebarTrackpadMode(), 'ios_2d');
    });
  });
}
