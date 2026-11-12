import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/models/transcription.dart';
import 'package:voice_bubble_stt/ui/design_tokens.dart';
import 'package:voice_bubble_stt/widgets/history_list.dart';

void main() {
  group('Color constants (Horizonte)', () {
    test('kAccent = brasa (relleno de acciones primarias)', () {
      expect(kAccentLight, const Color(0xFFF27A14));
      expect(kAccentDark, const Color(0xFFFF8A1F));
    });

    test('kRecording = brasa (grabar ya no es rojo)', () {
      expect(kRecording, const Color(0xFFF27A14));
      expect(kRecordingDark, const Color(0xFFFF8A1F));
      expect(kRecording, kEmberLight);
      expect(kRecordingDark, kEmberDark);
    });

    test('el rojo queda solo para borrar (danger)', () {
      expect(kDangerLight, const Color(0xFFC8372B));
      expect(kDangerDark, const Color(0xFFFF6A5C));
      expect(kRecording, isNot(kDangerLight));
      expect(kAccentLight, isNot(kDangerLight));
    });

    test('brasa de texto, suave, on-ember, destello, agujero y plasma', () {
      expect(kEmberTextLight, const Color(0xFFB84A06));
      expect(kEmberTextDark, const Color(0xFFFF9A3D));
      expect(kEmberSoftLight, const Color(0xFFFBE4CF));
      expect(kEmberSoftDark, const Color(0xFF3A2410));
      expect(kOnEmber, const Color(0xFF1A0E00));
      expect(kHot, const Color(0xFFFFC766));
      expect(kHoleLight, const Color(0xFF05060A));
      expect(kHoleDark, const Color(0xFF000000));
      expect(kOnHole, const Color(0xFFFFE9CF));
      expect(kPlasmaLight, const Color(0xFF3557C8));
      expect(kPlasmaDark, const Color(0xFF8FB0FF));
      expect(kOkLight, const Color(0xFF1F8A4C));
      expect(kOkDark, const Color(0xFF5FD38D));
    });

    test('teclado: kb, key y key2', () {
      expect(kKbLight, const Color(0xFFE3E4ED));
      expect(kKbDark, const Color(0xFF0E1016));
      expect(kKeyLight, const Color(0xFFFFFFFF));
      expect(kKeyDark, const Color(0xFF1E212D));
      expect(kKey2Light, const Color(0xFFCDCFDC));
      expect(kKey2Dark, const Color(0xFF151821));
    });

    test('background colors are correctly defined', () {
      expect(kBgBaseLight, const Color(0xFFEEEEF4));
      expect(kBgBaseDark, const Color(0xFF08090E));
      expect(kBgElevatedLight, const Color(0xFFFFFFFF));
      expect(kBgElevatedDark, const Color(0xFF12141C));
      expect(kBgSecondaryLight, const Color(0xFFFFFFFF));
      expect(kBgSecondaryDark, const Color(0xFF1B1E2A));
      expect(kFillLight, const Color(0xFFE3E4ED));
      expect(kFillDark, const Color(0xFF1B1E2A));
    });

    test('label colors are correctly defined', () {
      expect(kLabelPrimaryLight, const Color(0xFF10121A));
      expect(kLabelPrimaryDark, const Color(0xFFF2F0EC));
      expect(kLabelSecondaryLight, const Color(0xFF5C6072));
      expect(kLabelSecondaryDark, const Color(0xFF9A9DAB));
      expect(kLabelTertiaryLight, const Color(0x995C6072));
      expect(kLabelTertiaryDark, const Color(0x999A9DAB));
    });

    test('separators are correctly defined', () {
      expect(kSeparatorLight, const Color(0xFFD5D7E2));
      expect(kSeparatorDark, const Color(0xFF262A38));
    });
  });

  group('Superficie sólida (sin vidrio) y sombras', () {
    test('borde line de 1 px y 2 px accesible', () {
      expect(kGlassBorderLight, kSeparatorLight);
      expect(kGlassBorderDark, kSeparatorDark);
      expect(kSurfaceBorderWidth, 1.0);
      expect(kGlassBorderWidthAccessible, 2.0);
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

  group('Inicio 2026 layout tokens', () {
    test('la burbuja de dictado respeta el mínimo de design.md (≥ 72)', () {
      expect(kRecordButtonSize, greaterThanOrEqualTo(72.0));
      expect(kRecordPillHeight, lessThan(kRecordButtonSize));
      expect(kRecordPillMaxWidth, greaterThan(kRecordButtonSize));
    });

    test('las listas dejan lugar libre para la burbuja', () {
      expect(
        kRecordDockClearance,
        greaterThan(kRecordButtonSize + kRecordDockBottomGap),
      );
    });

    test('el título grande es Large Title (34 bold)', () {
      expect(kTextLargeTitle.fontSize, 34);
      expect(kTextLargeTitle.fontWeight, FontWeight.w700);
    });
  });

  group('Border radius tokens', () {
    test('border radius values match design specifications', () {
      expect(kBorderRadiusSmall, 8.0);
      expect(kBorderRadiusCard, 16.0);
      expect(kBorderRadiusCardLarge, 20.0);
      expect(kBorderRadiusPill, 20.0);
      expect(kBorderRadiusSheet, 24.0);
      expect(kBorderRadiusDock, 32.0);
      expect(kBorderRadiusSheetLarge, 32.0);
      expect(kBorderRadiusCapsule, 100.0);
    });

    test('radios Horizonte: tecla 7, tarjeta 14, hoja 22', () {
      expect(kRadiusKey, 7.0);
      expect(kRadiusCard, 14.0);
      expect(kRadiusSheet, 22.0);
    });
  });

  group('Snippet palette tokens', () {
    test('snippet palette stroke has 0.40 alpha per design.md §12', () {
      final stroke = snippetPaletteStroke('azul', isDark: false);
      expect(stroke, isNotNull);
      expect(stroke!.a, closeTo(0.40, 0.01));
    });

    test('snippet palette: mismos 6 ids con valores Horizonte', () {
      expect(
          snippetPaletteBase('azul', isDark: false), const Color(0xFF3557C8));
      expect(snippetPaletteBase('azul', isDark: true), const Color(0xFF8FB0FF));
      expect(
          snippetPaletteBase('verde', isDark: false), const Color(0xFF1F8A4C));
      expect(
          snippetPaletteBase('verde', isDark: true), const Color(0xFF5FD38D));
      expect(
          snippetPaletteBase('rojo', isDark: false), const Color(0xFFC8372B));
      expect(snippetPaletteBase('rojo', isDark: true), const Color(0xFFFF6A5C));
      expect(snippetPaletteBase('naranja', isDark: false),
          const Color(0xFFD9750F));
      expect(
          snippetPaletteBase('naranja', isDark: true), const Color(0xFFFFA24A));
      expect(snippetPaletteBase('violeta', isDark: false),
          const Color(0xFF8B4FD0));
      expect(
          snippetPaletteBase('violeta', isDark: true), const Color(0xFFC79BFF));
      expect(
          snippetPaletteBase('gris', isDark: false), const Color(0xFF7B7E8C));
      expect(snippetPaletteBase('gris', isDark: true), const Color(0xFF9A9DAB));
      expect(snippetPaletteBase('otro', isDark: false), isNull);
      expect(snippetPaletteBase(null, isDark: true), isNull);
    });

    test('snippet palette fill has 0.20 alpha per design.md §12', () {
      final fill = snippetPaletteFill('azul', isDark: false);
      expect(fill, isNotNull);
      expect(fill!.a, closeTo(0.20, 0.01));
    });
  });

  group('Typography styles', () {
    test('typography styles have correct font sizes and weights', () {
      expect(kTextTitle.fontSize, 22);
      expect(kTextTitle.fontWeight, FontWeight.bold);
      expect(kTextBody.fontSize, 17);
      expect(kTextCallout.fontSize, 16);
      expect(kTextSubhead.fontSize, 15);
      expect(kTextFootnote.fontSize, 13);
      expect(kTextCaption.fontSize, 12);
    });

    test('familias Horizonte: Sora títulos, Inter lectura, JetBrains Mono', () {
      expect(kFontDisplay, 'Sora');
      expect(kFontBody, 'Inter');
      expect(kFontMono, 'JetBrainsMono');
      expect(kTextTitle.fontFamily, kFontDisplay);
      expect(kTextLargeTitle.fontFamily, kFontDisplay);
      expect(kTextMono.fontFamily, kFontMono);
      // El cuerpo hereda Inter del tema (no fija familia propia).
      expect(kTextBody.fontFamily, isNull);
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
      expect(theme.colorScheme.primary, kEmberLight);
      expect(theme.colorScheme.onPrimary, kOnEmber);
      expect(theme.colorScheme.error, kDangerLight);
      expect(theme.textTheme.bodyMedium?.fontFamily, kFontBody);
      expect(theme.textTheme.headlineMedium?.fontFamily, kFontDisplay);
      expect(theme.textTheme.titleLarge?.fontFamily, kFontDisplay);
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
      expect(theme.colorScheme.primary, kEmberDark);
      expect(theme.colorScheme.onPrimary, kOnEmber);
      expect(theme.colorScheme.error, kDangerDark);
      expect(theme.textTheme.bodyMedium?.fontFamily, kFontBody);
      expect(theme.textTheme.headlineMedium?.fontFamily, kFontDisplay);
    });
  });

  group('Theme comparison', () {
    test('buildLightTheme returns different result than buildDarkTheme', () {
      final light = buildLightTheme();
      final dark = buildDarkTheme();
      expect(light, isNot(equals(dark)));
      expect(
          light.colorScheme.primary, isNot(equals(dark.colorScheme.primary)));
    });
  });

  group('Historial smoke en claro y oscuro (pump real)', () {
    Transcription makeT(String text) => Transcription(
          text: text,
          timestamp: DateTime(2026, 9, 5, 12, 0),
        );

    testWidgets('HistoryList se monta bajo buildLightTheme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: HistoryList(transcriptions: [makeT('hola claro')]),
            ),
          ),
        ),
      );
      expect(find.text('hola claro'), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });

    testWidgets('HistoryList se monta bajo buildDarkTheme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: HistoryList(transcriptions: [makeT('hola oscuro')]),
            ),
          ),
        ),
      );
      expect(find.text('hola oscuro'), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });

    testWidgets('tarjeta con tokens de texto se monta en ambos brillos',
        (tester) async {
      for (final theme in [buildLightTheme(), buildDarkTheme()]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: Card(
                child: Text('token smoke', style: kTextBody),
              ),
            ),
          ),
        );
        expect(find.text('token smoke'), findsOneWidget);
      }
    });
  });
}
