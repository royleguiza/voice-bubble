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
  });

  group('buildLightTheme', () {
    test('returns a ThemeData', () {
      final theme = buildLightTheme();
      expect(theme, isA<ThemeData>());
    });

    test('uses useMaterial3', () {
      final theme = buildLightTheme();
      expect(theme.useMaterial3, isTrue);
    });

    test('has non-null colorScheme', () {
      final theme = buildLightTheme();
      expect(theme.colorScheme, isNotNull);
    });

    test('does not have Brightness.dark', () {
      final theme = buildLightTheme();
      expect(theme.colorScheme.brightness, isNot(Brightness.dark));
    });
  });

  group('buildDarkTheme', () {
    test('returns a ThemeData', () {
      final theme = buildDarkTheme();
      expect(theme, isA<ThemeData>());
    });

    test('uses useMaterial3', () {
      final theme = buildDarkTheme();
      expect(theme.useMaterial3, isTrue);
    });

    test('has non-null colorScheme', () {
      final theme = buildDarkTheme();
      expect(theme.colorScheme, isNotNull);
    });

    test('has Brightness.dark', () {
      final theme = buildDarkTheme();
      expect(theme.colorScheme.brightness, Brightness.dark);
    });
  });

  group('Theme comparison', () {
    test('buildLightTheme returns different result than buildDarkTheme', () {
      final light = buildLightTheme();
      final dark = buildDarkTheme();
      expect(light, isNot(equals(dark)));
    });
  });
}
