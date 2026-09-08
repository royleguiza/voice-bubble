import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Accent & Semantic Colors
// ---------------------------------------------------------------------------

/// Accent color for primary actions (Copy, links) – Light mode.
const Color kAccentLight = Color(0xFF007AFF);

/// Accent color for primary actions (Copy, links) – Dark mode.
const Color kAccentDark = Color(0xFF0A84FF);

/// Recording state color – Light mode.
const Color kRecording = Color(0xFFFF3B30);

/// Recording state color – Dark mode.
const Color kRecordingDark = Color(0xFFFF453A);

/// Success state color – Light/Dark (SPK-13: reemplaza Colors.green suelto).
const Color kSuccessLight = Color(0xFF248A3D);
const Color kSuccessDark = Color(0xFF30D158);

// ---------------------------------------------------------------------------
// Background Colors
// ---------------------------------------------------------------------------

/// App base background (content layer). Light: #F2F2F7, Dark: #000000.
const Color kBgBaseLight = Color(0xFFF2F2F7);
const Color kBgBaseDark = Color(0xFF000000);

/// Elevated surfaces (settings sheets). Light: #FFFFFF, Dark: #1C1C1E.
const Color kBgElevatedLight = Color(0xFFFFFFFF);
const Color kBgElevatedDark = Color(0xFF1C1C1E);

/// Secondary surfaces (history cards). Light: #FFFFFF, Dark: #2C2C2E.
const Color kBgSecondaryLight = Color(0xFFFFFFFF);
const Color kBgSecondaryDark = Color(0xFF2C2C2E);

// ---------------------------------------------------------------------------
// Label Colors
// ---------------------------------------------------------------------------

/// Primary text (contraste ≥ 7:1 ideal, mínimo 4.5:1).
const Color kLabelPrimaryLight = Color(0xFF000000);
const Color kLabelPrimaryDark = Color(0xFFFFFFFF);

/// Secondary text (timestamps, hints). ~60% opacity.
const Color kLabelSecondaryLight = Color(0x993C3C43); // rgba(60,60,67,.6)
const Color kLabelSecondaryDark = Color(0x99EBEBF5); // rgba(235,235,245,.6)

/// Tertiary text (placeholders, subtle dividers). ~30% opacity.
const Color kLabelTertiaryLight = Color(0x4D3C3C43); // rgba(60,60,67,.3)
const Color kLabelTertiaryDark = Color(0x4DEBEBF5); // rgba(235,235,245,.3)

/// Separator lines.
const Color kSeparatorLight = Color(0x4A3C3C43); // rgba(60,60,67,.29)
const Color kSeparatorDark = Color(0x99545458); // rgba(84,84,88,.6)

// ---------------------------------------------------------------------------
// Glass Material – Opacity & Blur
// ---------------------------------------------------------------------------

/// Fill opacity for glass elements in light context.
const double kGlassOpacityLight = 0.65;

/// Fill opacity for glass elements in dark context.
const double kGlassOpacityDark = 0.45;

/// Blur radius (sigma) for large glass elements (sheets, bars).
const double kGlassBlurLarge = 24.0;

/// Blur radius (sigma) for small glass elements (chips, buttons).
const double kGlassBlurSmall = 12.0;

/// Specular border color on glass – light context (white 55%).
const Color kGlassBorderLight = Color(0x8CFFFFFF); // rgba(255,255,255,.55)

/// Specular border color on glass – dark context (white 18%).
const Color kGlassBorderDark = Color(0x2EFFFFFF); // rgba(255,255,255,.18)

// ---------------------------------------------------------------------------
// Shadows – Simulated Glass Depth
// ---------------------------------------------------------------------------

/// Shadow for large glass elements (blur 24, offset y: 8).
const BoxShadow kGlassShadowLight = BoxShadow(
  color: Color(0x1F000000), // rgba(0,0,0,.12)
  blurRadius: 24.0,
  offset: Offset(0, 8),
);

/// Shadow for large glass elements – dark context (deeper).
const BoxShadow kGlassShadowDark = BoxShadow(
  color: Color(0x73000000), // rgba(0,0,0,.45)
  blurRadius: 24.0,
  offset: Offset(0, 8),
);

/// Shadow for small glass elements (blur 12, offset y: 4).
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

/// Capsule / pill-shaped controls (primary button, segmented control).
const double kBorderRadiusCapsule = 100.0;

/// Cards, history items, secondary surfaces.
const double kBorderRadiusCard = 16.0;

/// Elevated sheets, dialogs.
const double kBorderRadiusSheet = 24.0;

// ---------------------------------------------------------------------------
// Typography – Apple HIG Approximation for Android (Roboto)
// ---------------------------------------------------------------------------

const TextStyle kTextTitle = TextStyle(
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

// ---------------------------------------------------------------------------
// Theme Data – Light
// ---------------------------------------------------------------------------

ThemeData buildLightTheme() {
  final colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: kAccentLight,
    onPrimary: Colors.white,
    error: const Color(0xFFB3261E),
    onError: Colors.white,
    primaryContainer: kAccentLight.withValues(alpha: 0.12),
    onPrimaryContainer: kAccentLight,
    secondary: kAccentLight,
    onSecondary: Colors.white,
    secondaryContainer: kAccentLight.withValues(alpha: 0.12),
    onSecondaryContainer: kAccentLight,
    tertiary: kRecording,
    onTertiary: Colors.white,
    tertiaryContainer: kRecording.withValues(alpha: 0.12),
    onTertiaryContainer: kRecording,
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

  return ThemeData(
    useMaterial3: true,
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
}

// ---------------------------------------------------------------------------
// Theme Data – Dark
// ---------------------------------------------------------------------------

ThemeData buildDarkTheme() {
  final colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: kAccentDark,
    onPrimary: Colors.black,
    error: const Color(0xFFF2B8B5),
    onError: const Color(0xFF601410),
    primaryContainer: kAccentDark.withValues(alpha: 0.15),
    onPrimaryContainer: kAccentDark,
    secondary: kAccentDark,
    onSecondary: Colors.black,
    secondaryContainer: kAccentDark.withValues(alpha: 0.15),
    onSecondaryContainer: kAccentDark,
    tertiary: kRecordingDark,
    onTertiary: Colors.black,
    tertiaryContainer: kRecordingDark.withValues(alpha: 0.15),
    onTertiaryContainer: kRecordingDark,
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

  return ThemeData(
    useMaterial3: true,
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
}

// ---------------------------------------------------------------------------
// Home v2 – Layout & Motion (Hito 2)
// ---------------------------------------------------------------------------

/// Diámetro del botón de grabar principal.
const double kRecordButtonSize = 104.0;

/// Tamaño del glifo dentro del botón de grabar.
const double kRecordIconSize = 42.0;

/// Ancho máximo de la tarjeta emergente de transcripción.
const double kPopupMaxWidth = 480.0;

/// Altura máxima de la tarjeta emergente como fracción del alto de pantalla.
const double kPopupMaxHeightFactor = 0.35;

/// Altura máxima del sheet de historial como fracción del alto de pantalla.
const double kHistorySheetMaxFactor = 0.90;

/// Altura inicial (y primer snap) del sheet de historial (se despliega al 90%).
const double kHistorySheetInitialFactor = 0.90;

/// Fracción del alto del body desde el borde inferior hasta el cluster
/// del botón de grabar. 0.32 sitúa todo el botón (Ø104) y el texto de estado
/// en la zona óptima de alcance del pulgar (bajado un 10% adicional).
const double kRecordClusterBottomFactor = 0.32;

/// Holgura extra sobre el inset del sistema para el pill de historial.
/// 72.0 dp asegura que el botón quede totalmente despegado de la barra de
/// navegación por gestos de Android para evitar toques accidentales con el sistema.
const double kHistoryPillBottomGap = 72.0;

/// Duración de expansión de la tarjeta emergente.
const Duration kAnimPopupExpand = Duration(milliseconds: 320);

/// SPK-24: una curva por trabajo. Enter-scale con overshoot suave;
/// decoración/fades sin overshoot; exit instantáneo (ver botón).
const Curve kCurveEnter = Curves.easeOutBack;
const Curve kCurveFade = Curves.easeOutCubic;
const Curve kCurveExit = Curves.easeOut;

/// Morph entre estados del botón de grabar.
const Duration kAnimMorph = Duration(milliseconds: 350);

/// Scrim sobre el contenido cuando hay sheet abierto.
const Color kScrimColor = Color(0x4D000000); // black 30%
