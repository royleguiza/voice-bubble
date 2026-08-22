import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/ui/design_tokens.dart';

void main() {
  group('Color constants', () {
    test('kAccentLight has correct color value', () {
      expect(kAccentLight, const Color(0xFF007AFF));
    });

    test('kAccentDark has correct color value', () {
      expect(kAccentDark, const Color(0xFF0A84FF));
    });

    test('kRecording has correct color value', () {
      expect(kRecording, const Color(0xFFFF3B30));
    });

    test('kRecordingDark has correct color value', () {
      expect(kRecordingDark, const Color(0xFFFF453A));
    });

    test('background colors are correctly defined', () {
      expect(kBgBaseLight, const Color(0xFFF2F2F7));
      expect(kBgBaseDark, const Color(0xFF000000));
      expect(kBgElevatedLight, const Color(0xFFFFFFFF));
      expect(kBgElevatedDark, const Color(0xFF1C1C1E));
      expect(kBgSecondaryLight, const Color(0xFFFFFFFF));
      expect(kBgSecondaryDark, const Color(0xFF2C2C2E));
    });

    test('label colors are correctly defined', () {
      expect(kLabelPrimaryLight, const Color(0xFF000000));
      expect(kLabelPrimaryDark, const Color(0xFFFFFFFF));
      expect(kLabelSecondaryLight, const Color(0x993C3C43));
      expect(kLabelSecondaryDark, const Color(0x99EBEBF5));
      expect(kLabelTertiaryLight, const Color(0x4D3C3C43));
      expect(kLabelTertiaryDark, const Color(0x4DEBEBF5));
    });

    test('separators are correctly defined', () {
      expect(kSeparatorLight, const Color(0x4A3C3C43));
      expect(kSeparatorDark, const Color(0x99545458));
    });
  });

  group('Glass tokens and shadows', () {
    test('opacities and blurs are within expected ranges', () {
      expect(kGlassOpacityLight, 0.65);
      expect(kGlassOpacityDark, 0.45);
      expect(kGlassBlurLarge, 24.0);
      expect(kGlassBlurSmall, 12.0);
      expect(kGlassBorderLight, const Color(0x8CFFFFFF));
      expect(kGlassBorderDark, const Color(0x2EFFFFFF));
    });

    test('shadow definitions have correct blur and offset', () {
      expect(kGlassShadowLight.blurRadius, 24.0);
      expect(kGlassShadowLight.offset, const Offset(0, 8));
      expect(kGlassShadowDark.blurRadius, 24.0);
      expect(kGlassShadowDark.offset, const Offset(0, 8));
      expect(kGlassShadowSmallLight.blurRadius, 12.0);
      expect(kGlassShadowSmallLight.offset, const Offset(0, 4));
      expect(kGlassShadowSmallDark.blurRadius, 12.0);
      expect(kGlassShadowSmallDark.offset, const Offset(0, 4));
    });
  });

  group('Home v2 layout tokens', () {
    test('history sheet can expand to 90% with 90% initial factor', () {
      expect(kHistorySheetMaxFactor, 0.90);
      expect(kHistorySheetInitialFactor, 0.90);
    });

    test('record cluster sits above the gesture inset', () {
      expect(kRecordClusterBottomFactor, 0.32);
      expect(kHistoryPillBottomGap, 72.0);
    });
  });

  group('Border radius tokens', () {
    test('border radius values match design specifications', () {
      expect(kBorderRadiusCapsule, 100.0);
      expect(kBorderRadiusChip, 12.0);
      expect(kBorderRadiusCard, 16.0);
      expect(kBorderRadiusSheet, 24.0);
    });
  });

  group('Typography styles', () {
    test('typography styles have correct font sizes and weights', () {
      expect(kTextLargeTitle.fontSize, 34);
      expect(kTextLargeTitle.fontWeight, FontWeight.bold);
      expect(kTextTitle.fontSize, 22);
      expect(kTextTitle.fontWeight, FontWeight.bold);
      expect(kTextBody.fontSize, 17);
      expect(kTextCallout.fontSize, 16);
      expect(kTextSubhead.fontSize, 15);
      expect(kTextFootnote.fontSize, 13);
      expect(kTextCaption.fontSize, 12);
    });
  });

  group('buildLightTheme', () {
    test('returns a ThemeData with light brightness and Material 3', () {
      final theme = buildLightTheme();
      expect(theme, isA<ThemeData>());
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme, isNotNull);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, kBgBaseLight);
      expect(theme.dividerColor, kSeparatorLight);
      expect(theme.cardTheme.color, kBgSecondaryLight);
      expect(theme.cardTheme.elevation, 0);
    });
  });

  group('buildDarkTheme', () {
    test('returns a ThemeData with dark brightness and Material 3', () {
      final theme = buildDarkTheme();
      expect(theme, isA<ThemeData>());
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme, isNotNull);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, kBgBaseDark);
      expect(theme.dividerColor, kSeparatorDark);
      expect(theme.cardTheme.color, kBgSecondaryDark);
      expect(theme.cardTheme.elevation, 0);
    });
  });

  group('Theme comparison', () {
    test('buildLightTheme returns different result than buildDarkTheme', () {
      final light = buildLightTheme();
      final dark = buildDarkTheme();
      expect(light, isNot(equals(dark)));
      expect(light.colorScheme.primary, isNot(equals(dark.colorScheme.primary)));
    });
  });
}
