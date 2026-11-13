import 'package:flutter/material.dart';

// ===========================================================================
// HORIZONTE (design.md): superficies sólidas, un solo acento "brasa" tomado
// del ícono, micrófono como agujero negro con anillo de brasa, rojo SOLO
// para borrar/destructivo y monoespaciada para código, horas y contadores.
// Fuente de verdad de los valores: design.md §4 (tabla de tokens).
// ===========================================================================

// ---------------------------------------------------------------------------
// Paleta base Horizonte (claro / oscuro)
// ---------------------------------------------------------------------------

/// Fondo de la app (bg).
const Color kHzBgLight = Color(0xFFEEEEF4);
const Color kHzBgDark = Color(0xFF08090E);

/// Superficie: tarjetas, hojas, campos (surf).
const Color kHzSurfLight = Color(0xFFFFFFFF);
const Color kHzSurfDark = Color(0xFF12141C);

/// Relleno: buscador, segmentados, botones secundarios (surf2).
const Color kHzSurf2Light = Color(0xFFE3E4ED);
const Color kHzSurf2Dark = Color(0xFF1B1E2A);

/// Línea: bordes de 1 px y separadores (line).
const Color kHzLineLight = Color(0xFFD5D7E2);
const Color kHzLineDark = Color(0xFF262A38);

/// Texto principal (fg) y secundario (fg2).
const Color kHzFgLight = Color(0xFF10121A);
const Color kHzFgDark = Color(0xFFF2F0EC);
const Color kHzFg2Light = Color(0xFF5C6072);
const Color kHzFg2Dark = Color(0xFF9A9DAB);

/// Brasa (ember): relleno de acciones primarias, Enter y estado grabando.
const Color kEmberLight = Color(0xFFF27A14);
const Color kEmberDark = Color(0xFFFF8A1F);

/// Brasa para texto e íconos (ember-t): cumple contraste sobre superficie.
const Color kEmberTextLight = Color(0xFFB04706);
const Color kEmberTextDark = Color(0xFFFF9A3D);

/// Brasa suave (ember-soft): fondo de chip / estado activo.
const Color kEmberSoftLight = Color(0xFFFBE4CF);
const Color kEmberSoftDark = Color(0xFF3A2410);

/// Texto/ícono sobre relleno brasa (on-ember), igual en ambos modos.
const Color kOnEmber = Color(0xFF1A0E00);

/// Destello (hot): brillo del disco del ícono, igual en ambos modos.
const Color kHot = Color(0xFFFFC766);

/// Enlace / información (plasma). El azul ya no es acento.
const Color kPlasmaLight = Color(0xFF3557C8);
const Color kPlasmaDark = Color(0xFF8FB0FF);

/// Borrar / destructivo (danger): ÚNICO uso del rojo.
const Color kDangerLight = Color(0xFFC8372B);
const Color kDangerDark = Color(0xFFFF6A5C);

/// Listo / éxito (ok).
const Color kOkLight = Color(0xFF1E874A);
const Color kOkDark = Color(0xFF5FD38D);

/// Agujero (hole): el micrófono es un objeto negro puro con anillo brasa.
const Color kHoleLight = Color(0xFF05060A);
const Color kHoleDark = Color(0xFF000000);

/// Glifo sobre el agujero (on-hole), igual en ambos modos.
const Color kOnHole = Color(0xFFFFE9CF);

/// Teclado: fondo (kb), tecla (key) y tecla alternativa (key2).
const Color kKbLight = Color(0xFFE3E4ED);
const Color kKbDark = Color(0xFF0E1016);
const Color kKeyLight = Color(0xFFFFFFFF);
const Color kKeyDark = Color(0xFF1E212D);
const Color kKey2Light = Color(0xFFCDCFDC);
const Color kKey2Dark = Color(0xFF151821);

// ---------------------------------------------------------------------------
// Accent & Semantic Colors (nombres históricos, valores Horizonte)
// ---------------------------------------------------------------------------

/// Acento de acciones primarias = brasa (relleno). Para texto/ícono sobre
/// superficie usar [kTintTextLight]/[kTintTextDark] (brasa-t).
const Color kAccentLight = kEmberLight;
const Color kAccentDark = kEmberDark;

/// Estado grabando = brasa (decisión del dueño: grabar ya no es rojo).
const Color kRecording = kEmberLight;
const Color kRecordingDark = kEmberDark;

/// Éxito (SPK-13: reemplaza Colors.green suelto) = ok.
const Color kSuccessLight = kOkLight;
const Color kSuccessDark = kOkDark;

/// Aviso (píldoras de estado intermedias) = destello.
const Color kWarning = kHot;

// ---------------------------------------------------------------------------
// Snippet Palette – 6 ids fijos (design.md §12); sin color libre.
// Base = token del tema; fill/stroke derivados con alfa de teñido.
// ---------------------------------------------------------------------------

/// Resolve el color base de la paleta de snippets para el modo [isDark].
Color? snippetPaletteBase(String? id, {required bool isDark}) {
  switch (id) {
    case 'azul':
      return isDark ? kPlasmaDark : kPlasmaLight;
    case 'verde':
      return isDark ? kOkDark : kOkLight;
    case 'rojo':
      return isDark ? kDangerDark : kDangerLight;
    case 'naranja':
      return isDark ? const Color(0xFFFFA24A) : const Color(0xFFD9750F);
    case 'violeta':
      return isDark ? const Color(0xFFC79BFF) : const Color(0xFF8B4FD0);
    case 'gris':
      return isDark ? kHzFg2Dark : const Color(0xFF7B7E8C);
    default:
      return null;
  }
}

/// Fondo teñido del snippet (~20% de opacidad) para chips/cards.
Color? snippetPaletteFill(String? id, {required bool isDark}) =>
    snippetPaletteBase(id, isDark: isDark)?.withValues(alpha: 0.20);

/// Stroke teñido (~40%) del snippet (design.md §12: alpha 0.40 / 0x66).
Color? snippetPaletteStroke(String? id, {required bool isDark}) =>
    snippetPaletteBase(id, isDark: isDark)?.withValues(alpha: 0.40);

// ---------------------------------------------------------------------------
// Background Colors
// ---------------------------------------------------------------------------

/// Fondo de la app (capa contenido) = bg.
const Color kBgBaseLight = kHzBgLight;
const Color kBgBaseDark = kHzBgDark;

/// Superficies elevadas (hojas de ajustes) = surf.
const Color kBgElevatedLight = kHzSurfLight;
const Color kBgElevatedDark = kHzSurfDark;

/// Superficies secundarias (tarjetas dentro de hojas) = surf / surf2 en
/// oscuro, para conservar el escalón hoja > tarjeta.
const Color kBgSecondaryLight = kHzSurfLight;
const Color kBgSecondaryDark = kHzSurf2Dark;

// ---------------------------------------------------------------------------
// Label Colors
// ---------------------------------------------------------------------------

/// Texto principal = fg (≥ 4.5:1 sobre bg y surf en ambos modos).
const Color kLabelPrimaryLight = kHzFgLight;
const Color kLabelPrimaryDark = kHzFgDark;

/// Texto secundario (timestamps, hints) = fg2, opaco.
const Color kLabelSecondaryLight = kHzFg2Light;
const Color kLabelSecondaryDark = kHzFg2Dark;

/// Terciario (placeholders, glifos deshabilitados): fg2 al 60%.
const Color kLabelTertiaryLight = Color(0x995C6072);
const Color kLabelTertiaryDark = Color(0x999A9DAB);

/// Separadores = line.
const Color kSeparatorLight = kHzLineLight;
const Color kSeparatorDark = kHzLineDark;

// ---------------------------------------------------------------------------
// Superficie sólida (ex "vidrio"). Horizonte prohíbe el desenfoque en la
// app: GlassContainer es surf + borde line de 1 px (design.md §7).
// ---------------------------------------------------------------------------

/// Borde de superficies sólidas (1 px, line).
const Color kGlassBorderLight = kHzLineLight;
const Color kGlassBorderDark = kHzLineDark;

/// Ancho de borde normal de una superficie.
const double kSurfaceBorderWidth = 1.0;

/// Ancho de borde con alto contraste o transparencia reducida (design.md §9).
const double kGlassBorderWidthAccessible = 2.0;

// ---------------------------------------------------------------------------
// Shadows – profundidad sutil (sin vidrio)
// ---------------------------------------------------------------------------

/// Shadow for large elements (blur 24, offset y: 8).
const BoxShadow kGlassShadowLight = BoxShadow(
  color: Color(0x1F000000), // rgba(0,0,0,.12)
  blurRadius: 24.0,
  offset: Offset(0, 8),
);

/// Shadow for large elements – dark context (deeper).
const BoxShadow kGlassShadowDark = BoxShadow(
  color: Color(0x73000000), // rgba(0,0,0,.45)
  blurRadius: 24.0,
  offset: Offset(0, 8),
);

/// Shadow for small elements (blur 12, offset y: 4).
const BoxShadow kGlassShadowSmallLight = BoxShadow(
  color: Color(0x1A000000), // rgba(0,0,0,.10)
  blurRadius: 12.0,
  offset: Offset(0, 4),
);

const BoxShadow kGlassShadowSmallDark = BoxShadow(
  color: Color(0x4D000000), // rgba(0,0,0,.30)
  blurRadius: 12.0,
  offset: Offset(0, 4),
);

// ---------------------------------------------------------------------------
// Border Radius – Consistent Scale
// ---------------------------------------------------------------------------

/// Horizonte: tecla 7, tarjeta 14, hoja 22; círculo solo para el agujero
/// y los botones de ícono. Los radios históricos de abajo siguen vigentes
/// hasta que cada fase rehaga su pantalla.
const double kRadiusKey = 7.0;
const double kRadiusCard = 14.0;
const double kRadiusSheet = 22.0;

/// Small elements, badges, key previews, indicator borders (8px).
const double kBorderRadiusSmall = 8.0;

/// Cards, history items, secondary surfaces (16px).
const double kBorderRadiusCard = 16.0;

/// Pill-shaped card elements, tab items (20px).
const double kBorderRadiusCardLarge = 20.0;
const double kBorderRadiusPill = 20.0;

/// Elevated sheets, dialogs (24px).
const double kBorderRadiusSheet = 24.0;

/// Dock containers, large floating bars (32px).
const double kBorderRadiusDock = 32.0;
const double kBorderRadiusSheetLarge = 32.0;

/// Capsule / pill-shaped controls (primary button, segmented control, drag handles).
const double kBorderRadiusCapsule = 100.0;

// ---------------------------------------------------------------------------
// Typography – Horizonte: Sora (títulos), Inter (lectura), JetBrains Mono
// (código, horas, contadores). Empaquetadas en app_source/fonts (OFL 1.1).
// ---------------------------------------------------------------------------

/// Familia de títulos (600/700).
const String kFontDisplay = 'Sora';

/// Familia de lectura, por defecto en todo el tema (400/500/600).
const String kFontBody = 'Inter';

/// Familia monoespaciada (400/500).
const String kFontMono = 'JetBrainsMono';

const TextStyle kTextTitle = TextStyle(
  fontFamily: kFontDisplay,
  fontSize: 22,
  fontWeight: FontWeight.bold,
  letterSpacing: 0.35,
);

const TextStyle kTextBody = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.normal,
  letterSpacing: -0.41,
);

const TextStyle kTextCallout = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.normal,
  letterSpacing: -0.32,
);

const TextStyle kTextSubhead = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.normal,
  letterSpacing: -0.24,
);

const TextStyle kTextFootnote = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.normal,
  letterSpacing: -0.08,
);

const TextStyle kTextCaption = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.normal,
  letterSpacing: 0.0,
);

/// Monoespaciada: código, horas, contadores y duraciones.
const TextStyle kTextMono = TextStyle(
  fontFamily: kFontMono,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  letterSpacing: 0.0,
);

// SPK-14: 3 roles con nombre para énfasis (prohíbe TextStyle suelto).
// Tab bar: 12sp mínimo (antes 11sp fuera de escala).
const TextStyle kTextSelected = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.1,
);

const TextStyle kTextUnselected = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  letterSpacing: -0.1,
);

const TextStyle kTextMeta = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w400,
);

/// Aplica Sora a los estilos de título del tema (display/headline/title
/// grande); el resto hereda Inter de [ThemeData.fontFamily].
TextTheme _horizonteTextTheme(TextTheme base) {
  TextStyle? display(TextStyle? s) => s?.copyWith(fontFamily: kFontDisplay);
  return base.copyWith(
    displayLarge: display(base.displayLarge),
    displayMedium: display(base.displayMedium),
    displaySmall: display(base.displaySmall),
    headlineLarge: display(base.headlineLarge),
    headlineMedium: display(base.headlineMedium),
    headlineSmall: display(base.headlineSmall),
    titleLarge: display(base.titleLarge),
  );
}

// ---------------------------------------------------------------------------
// Theme Data – Light
// ---------------------------------------------------------------------------

ThemeData buildLightTheme() {
  final colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: kAccentLight,
    onPrimary: kOnEmber,
    error: kDangerLight,
    onError: kLabelPrimaryDark,
    primaryContainer: kEmberSoftLight,
    onPrimaryContainer: kEmberTextLight,
    secondary: kEmberTextLight,
    onSecondary: kLabelPrimaryDark,
    secondaryContainer: kEmberSoftLight,
    onSecondaryContainer: kEmberTextLight,
    tertiary: kPlasmaLight,
    onTertiary: kLabelPrimaryDark,
    tertiaryContainer: kPlasmaLight.withValues(alpha: 0.12),
    onTertiaryContainer: kPlasmaLight,
    surface: kBgBaseLight,
    onSurface: kLabelPrimaryLight,
    surfaceContainerHighest: kBgElevatedLight,
    surfaceContainerHigh: kBgSecondaryLight,
    surfaceContainer: kBgSecondaryLight,
    surfaceContainerLow: kBgBaseLight,
    surfaceContainerLowest: kBgBaseLight,
    outline: kSeparatorLight,
    outlineVariant: kLabelTertiaryLight,
  );

  final theme = ThemeData(
    useMaterial3: true,
    fontFamily: kFontBody,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: kBgBaseLight,
    dividerColor: kSeparatorLight,
    cardTheme: const CardThemeData(
      color: kBgSecondaryLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(kBorderRadiusCard)),
      ),
    ),
  );
  return theme.copyWith(textTheme: _horizonteTextTheme(theme.textTheme));
}

// ---------------------------------------------------------------------------
// Theme Data – Dark
// ---------------------------------------------------------------------------

ThemeData buildDarkTheme() {
  final colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: kAccentDark,
    onPrimary: kOnEmber,
    error: kDangerDark,
    onError: kLabelPrimaryLight,
    primaryContainer: kEmberSoftDark,
    onPrimaryContainer: kEmberTextDark,
    secondary: kEmberTextDark,
    onSecondary: kLabelPrimaryLight,
    secondaryContainer: kEmberSoftDark,
    onSecondaryContainer: kEmberTextDark,
    tertiary: kPlasmaDark,
    onTertiary: kLabelPrimaryLight,
    tertiaryContainer: kPlasmaDark.withValues(alpha: 0.15),
    onTertiaryContainer: kPlasmaDark,
    surface: kBgBaseDark,
    onSurface: kLabelPrimaryDark,
    surfaceContainerHighest: kBgElevatedDark,
    surfaceContainerHigh: kBgSecondaryDark,
    surfaceContainer: kBgSecondaryDark,
    surfaceContainerLow: kBgBaseDark,
    surfaceContainerLowest: kBgBaseDark,
    outline: kSeparatorDark,
    outlineVariant: kLabelTertiaryDark,
  );

  final theme = ThemeData(
    useMaterial3: true,
    fontFamily: kFontBody,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: kBgBaseDark,
    dividerColor: kSeparatorDark,
    cardTheme: const CardThemeData(
      color: kBgSecondaryDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(kBorderRadiusCard)),
      ),
    ),
  );
  return theme.copyWith(textTheme: _horizonteTextTheme(theme.textTheme));
}

// ---------------------------------------------------------------------------
// Inicio 2026 – Notas como pantalla principal + burbuja de dictado
// (laboratorio_ui/inicio-notas.html)
// ---------------------------------------------------------------------------

/// Diámetro de la burbuja de dictado en reposo (design.md §6: ≥ 72).
const double kRecordButtonSize = 76.0;

/// Tamaño del glifo del micrófono dentro de la burbuja.
const double kRecordIconSize = 32.0;

/// Alto de la burbuja convertida en pastilla mientras graba.
const double kRecordPillHeight = 68.0;

/// Ancho máximo de la pastilla de grabación.
const double kRecordPillMaxWidth = 340.0;

/// Separación entre la burbuja y el borde inferior (sobre el inset del sistema).
const double kRecordDockBottomGap = 24.0;

/// Espacio libre al pie de las listas para que la última tarjeta no quede
/// debajo de la burbuja: alto de la burbuja + su separación + aire.
const double kRecordDockClearance =
    kRecordButtonSize + kRecordDockBottomGap + 48.0;

/// Título grande de la pantalla principal (design.md §5, Large Title).
const TextStyle kTextLargeTitle = TextStyle(
  fontFamily: kFontDisplay,
  fontSize: 34,
  fontWeight: FontWeight.w700,
  height: 41 / 34,
  letterSpacing: 0.2,
);

/// Desplazamiento a partir del cual aparece la barra compacta superior.
const double kLargeTitleCollapseOffset = 44.0;

/// Relleno de controles de contenido (segmentado, buscador) = surf2.
const Color kFillLight = kHzSurf2Light;
const Color kFillDark = kHzSurf2Dark;

/// Pastilla seleccionada del segmentado en oscuro (en claro es kBgElevatedLight).
const Color kSegmentThumbDark = kHzLineDark;

/// Sombra de la pastilla seleccionada del segmentado.
const BoxShadow kSegmentThumbShadow = BoxShadow(
  color: Color(0x1F000000),
  blurRadius: 8,
  offset: Offset(0, 3),
);

/// Radio de las tarjetas de nota en la lista principal.
const double kBorderRadiusNoteCard = 18.0;

/// Duración del resaltado de una nota recién dictada.
const Duration kAnimNewNote = Duration(milliseconds: 1400);

/// SPK-24: una curva por trabajo. Enter-scale con overshoot suave;
/// decoración/fades sin overshoot; exit instantáneo (ver botón).
const Curve kCurveEnter = Curves.easeOutBack;
const Curve kCurveFade = Curves.easeOutCubic;
const Curve kCurveExit = Curves.easeOut;

/// Morph entre estados del botón de grabar.
const Duration kAnimMorph = Duration(milliseconds: 350);

/// Scrim sobre el contenido cuando hay sheet abierto.
const Color kScrimColor = Color(0x9905060A); // hole al 60% (maqueta)

// ---------------------------------------------------------------------------
// Settings v2 – Rediseño laboratorio_ui/settings-redesign-v2.html
// ---------------------------------------------------------------------------

/// Título de página de Ajustes (28/800, tracking -0.5).
const TextStyle kSettingsPageTitle = TextStyle(
  fontFamily: kFontDisplay,
  fontSize: 28,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.5,
);

/// Título de grupo semántico (12/600, mayúsculas en uso).
const TextStyle kSettingsGroupTitle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.5,
);

/// Título de fila de ajuste (15/500).
const TextStyle kSettingRowTitle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w500,
);

/// Altura mínima de fila de ajuste.
const double kSettingRowMinHeight = 52.0;

/// Pastilla de icono de fila: 30x30, radio 8.
const double kSettingIconSize = 30.0;
const double kSettingIconRadius = 8.0;
const double kSettingIconGlyph = 16.0;

/// Tintes de pastilla de icono (idénticos en claro/oscuro, como el lab).
/// Ajustados a contraste >= 3:1 con glifo blanco (C-30).
const Color kTileBlue = Color(0xFF0A84FF);
const Color kTileGreen = Color(0xFF1A7A2E);
const Color kTileOrange = Color(0xFF9A5B00);
const Color kTileRed = Color(0xFFFF453A);
const Color kTilePurple = Color(0xFFBF5AF2);
const Color kTileGray = Color(0xFF8E8E93);
const Color kTilePink = Color(0xFFFF375F);
const Color kTileIndigo = Color(0xFF5856D6);
const Color kTileYellow = Color(0xFFA66A00);

// ---------------------------------------------------------------------------
// Ajustes 2026 (lista agrupada estilo iOS 26)
// ---------------------------------------------------------------------------

/// Radio de los grupos de filas (inset grouped de iOS 26).
const double kSettingsGroupRadius = 26.0;

/// Separación vertical entre grupos.
const double kSettingsGroupGap = 28.0;

/// Botón circular de vidrio de la barra superior (volver / agregar).
const double kSettingsNavButtonSize = 44.0;

/// Altura de la barra superior de las subpáginas.
const double kSettingsNavBarHeight = 64.0;

/// Título grande de la raíz de Ajustes (34/700).
const TextStyle kSettingsLargeTitle = TextStyle(
  fontFamily: kFontDisplay,
  fontSize: 34,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.6,
  height: 1.2,
);

/// Título centrado de la barra de subpágina (17/600).
const TextStyle kSettingsNavTitle = TextStyle(
  fontFamily: kFontDisplay,
  fontSize: 17,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.41,
);

/// Encabezado de grupo (15/600, sin mayúsculas).
const TextStyle kSettingsSectionHeader = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.24,
);

/// Texto secundario legible (pie de grupo, valor de fila) = fg2:
/// >= 4.5:1 sobre bg y surf en ambos modos.
const Color kSettingsSecondaryLight = kHzFg2Light;
const Color kSettingsSecondaryDark = kHzFg2Dark;

/// Chevron y asa del sheet (decorativos) = terciario.
const Color kSettingsChevronLight = kLabelTertiaryLight;
const Color kSettingsChevronDark = kLabelTertiaryDark;

/// Separador fino entre filas de un grupo = line.
const Color kSettingsSeparatorLight = kHzLineLight;
const Color kSettingsSeparatorDark = kHzLineDark;

/// Pista del interruptor apagado / encendido (encendido = brasa).
const Color kSwitchOffLight = kKey2Light;
const Color kSwitchOffDark = kHzLineDark;
const Color kSwitchOn = kEmberLight;

/// Brasa de texto (acciones de fila, enlaces de acción) = ember-t.
const Color kTintTextLight = kEmberTextLight;
const Color kTintTextDark = kEmberTextDark;

/// Aviso "Falta" en la raíz = ember-t (legible sobre surf).
const Color kSettingsAlertLight = kEmberTextLight;
const Color kSettingsAlertDark = kEmberTextDark;

/// Botones circulares y menú desplegable: superficie sólida + line.
const Color kSettingsGlassLight = kHzSurfLight;
const Color kSettingsGlassDark = kHzSurfDark;
const Color kSettingsGlassBorderLight = kHzLineLight;
const Color kSettingsGlassBorderDark = kHzLineDark;
const Color kSettingsMenuLight = kHzSurfLight;
const Color kSettingsMenuDark = kHzSurf2Dark;

/// Vista previa del teclado en Ajustes › Teclado (= tokens kb/key/key2).
const Color kKbPreviewSurfaceLight = kKbLight;
const Color kKbPreviewSurfaceDark = kKbDark;
const Color kKbPreviewKeyLight = kKeyLight;
const Color kKbPreviewKeyDark = kKeyDark;
const Color kKbPreviewKeyAltLight = kKey2Light;
const Color kKbPreviewKeyAltDark = kKey2Dark;
