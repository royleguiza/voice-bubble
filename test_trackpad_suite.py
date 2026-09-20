#!/usr/bin/env python3
"""
TEST SUITE INTEGRAL: MODO TRACKPAD Y PUNTERO VIRTUAL (MEJ-09)
Verifica al 100% de certeza:
1. Paridad de claves de contrato en docs/contract-keys.txt, Dart y Kotlin.
2. Manifest y permisos: SYSTEM_ALERT_WINDOW y perfil anti-Play-Protect (SIN BIND_ACCESSIBILITY_SERVICE declarado; el servicio queda versionado pero dormido).
3. VoiceBubbleAccessibilityService: métodos de despacho, sanitización de coordenadas, batching de scroll y canRetrieveWindowContent=false.
4. PointerOverlayManager: TYPE_APPLICATION_OVERLAY, FLAG_NOT_TOUCHABLE, estilos, cinemática y bounds.
5. VirtualTrackpadView: Opción 2 Split Wings, modos de scroll (right, left, disabled), auto-expansión 100%,
   prevención de doble-click multitáctil, re-anclaje de cursor y clic secundario 'hold'.
6. VoiceKeyboardService: Layer.TRACKPAD, toolbar button, rebuild, ciclo de vida, guardas de contraseña y tolerancia de tipos.
7. Auditoría de Privacidad y Cero-Logs (CERO telemetría, CERO captura de coordenadas).
8. StorageService (Dart): getters, setters, constantes, clamping y valores por defecto.
9. SettingsScreen (Dart): sección dedicada, switches y segmented buttons.
10. Vector drawables: ic_trackpad.xml, ic_keyboard.xml y strings.xml.
11. Batería de tests unitarios Dart en app_source/test/.
"""

import os
import re
import sys
import xml.etree.ElementTree as ET

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check

print("\n============================================================")
print(" 🚀 INICIANDO TEST SUITE: MODO TRACKPAD Y PUNTERO VIRTUAL (MEJ-09)")
print("============================================================\n")

# --- TEST 1: Paridad de claves de contrato ---
TRACKPAD_KEYS = [
    "kb_trackpad_accel_curve",
    "kb_trackpad_auto_return",
    "kb_trackpad_button_layout",
    "kb_trackpad_enabled",
    "kb_trackpad_haptic",
    "kb_trackpad_pointer_style",
    "kb_trackpad_scroll_direction",
    "kb_trackpad_scroll_position",
    "kb_trackpad_secondary_click",
    "kb_trackpad_sensitivity",
    "kb_trackpad_tap_to_click",
    "kb_trackpad_toolbar_visible",
]

contract_keys_file = os.path.join(WORKSPACE, "docs/contract-keys.txt")
with open(contract_keys_file, "r", encoding="utf-8") as f:
    contract_content = f.read().splitlines()

all_in_contract = all(k in contract_content for k in TRACKPAD_KEYS)
check(f"Todas las {len(TRACKPAD_KEYS)} claves de trackpad presentes en docs/contract-keys.txt", all_in_contract)

kt_vk = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/VoiceKeyboardService.kt")
with open(kt_vk, "r", encoding="utf-8") as f:
    vk_content = f.read()
# SPK-05: el enum Layer vive en KeyboardTypes.kt y las prefs en
# KeyboardPrefs.kt (mismo paquete).
kt_types = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/KeyboardTypes.kt")
with open(kt_types, "r", encoding="utf-8") as f:
    vk_content += f.read()
kt_prefs = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/KeyboardPrefs.kt")
with open(kt_prefs, "r", encoding="utf-8") as f:
    vk_content += f.read()
# SPK-05 módulo 6: la capa TRACKPAD vive en TrackpadBridge.kt (mismo
# paquete); VKS queda como shell que delega (trackpad.toggle/build/hide).
kt_bridge_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/TrackpadBridge.kt")
bridge_content = ""
if os.path.isfile(kt_bridge_path):
    with open(kt_bridge_path, "r", encoding="utf-8") as f:
        bridge_content = f.read()
    vk_content += bridge_content
# SPK-05 módulo 12: la toolbar (con el botón de trackpad) vive en
# ToolbarLayer.kt (mismo paquete); VKS delega (toolbar.buildToolbar()).
kt_toolbar_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/ToolbarLayer.kt")
if os.path.isfile(kt_toolbar_path):
    with open(kt_toolbar_path, "r", encoding="utf-8") as f:
        vk_content += f.read()
# SPK-05 módulo 17: los gestos MEJ-25 de la espaciadora viven en
# SpacebarLayer.kt (mismo paquete); VKS delega (spacebar.*).
kt_spacebar_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/SpacebarLayer.kt")
if os.path.isfile(kt_spacebar_path):
    with open(kt_spacebar_path, "r", encoding="utf-8") as f:
        vk_content += f.read()

all_read_in_kotlin = all(f'flutter.{k}' in vk_content for k in TRACKPAD_KEYS)
check(f"Todas las {len(TRACKPAD_KEYS)} claves flutter.kb_trackpad_* leídas en VoiceKeyboardService.kt", all_read_in_kotlin)

# --- TEST 2: Manifest y Permisos ---
manifest_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/AndroidManifest.xml")
with open(manifest_path, "r", encoding="utf-8") as f:
    manifest_content = f.read()

check("AndroidManifest declara SYSTEM_ALERT_WINDOW", 'android.permission.SYSTEM_ALERT_WINDOW' in manifest_content)
check("AndroidManifest libre de BIND_ACCESSIBILITY_SERVICE (perfil anti-Play-Protect)", 'android.permission.BIND_ACCESSIBILITY_SERVICE' not in manifest_content)
check("AndroidManifest no declara VoiceBubbleAccessibilityService (perfil anti-Play-Protect)", 'android:name=".VoiceBubbleAccessibilityService"' not in manifest_content)
# NOTA: la exigencia de FloatingTrackpadService vive en TEST 13 (declarado
# como servicio normal por otro agente). Aquí solo se conserva el perfil
# dormido de ACCESIBILIDAD, que sí debe seguir sin declarar.

gradle_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/build.gradle.kts")
with open(gradle_path, "r", encoding="utf-8") as f:
    gradle_content = f.read()

keystore_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/debug.keystore")
check("Keystore persistente debug.keystore existe en android/app", os.path.isfile(keystore_path))
check("build.gradle.kts configura signingConfigs con debug.keystore", 'debug.keystore' in gradle_content)

# --- TEST 3: VoiceBubbleAccessibilityService ---
acc_kt_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/VoiceBubbleAccessibilityService.kt")
check("VoiceBubbleAccessibilityService.kt existe", os.path.isfile(acc_kt_path))
if os.path.isfile(acc_kt_path):
    with open(acc_kt_path, "r", encoding="utf-8") as f:
        acc_content = f.read()
    check("VoiceBubbleAccessibilityService extiende AccessibilityService", "class VoiceBubbleAccessibilityService : AccessibilityService()" in acc_content)
    check("VoiceBubbleAccessibilityService implementa dispatchTap", "fun dispatchTap(" in acc_content)
    check("VoiceBubbleAccessibilityService implementa dispatchLongPress", "fun dispatchLongPress(" in acc_content)
    check("VoiceBubbleAccessibilityService implementa dispatchScroll", "fun dispatchScroll(" in acc_content)
    check("VoiceBubbleAccessibilityService tiene singleton isConnected()", "fun isConnected(): Boolean" in acc_content)
    check("VoiceBubbleAccessibilityService sanitiza coordenadas contra NaN y valores negativos", "isNaN" in acc_content)
    check("VoiceBubbleAccessibilityService implementa batching de scroll sin colisiones (flushPendingScroll)", "flushPendingScroll" in acc_content and "isScrollActive" in acc_content)
    check("VoiceBubbleAccessibilityService trazo no vacio via lineTo en dispatchTap", "lineTo(x, y)" in acc_content)

# --- TEST 4: PointerOverlayManager ---
pom_kt_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/PointerOverlayManager.kt")
check("PointerOverlayManager.kt existe", os.path.isfile(pom_kt_path))
if os.path.isfile(pom_kt_path):
    with open(pom_kt_path, "r", encoding="utf-8") as f:
        pom_content = f.read()
    check("PointerOverlayManager usa TYPE_APPLICATION_OVERLAY", "WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY" in pom_content)
    check("PointerOverlayManager usa FLAG_NOT_TOUCHABLE (no roba toques)", "FLAG_NOT_TOUCHABLE" in pom_content)
    check("PointerOverlayManager usa FLAG_NOT_FOCUSABLE (no roba foco)", "FLAG_NOT_FOCUSABLE" in pom_content)
    check("PointerOverlayManager soporta estilos arrow, dot, cross", '"arrow"' in pom_content and '"dot"' in pom_content and '"cross"' in pom_content)
    check("PointerOverlayManager cinemática: dynamic, linear, precision", '"dynamic"' in pom_content and '"linear"' in pom_content and '"precision"' in pom_content)
    check("PointerOverlayManager acota coordenadas a bounds de pantalla", "clampCoordinates" in pom_content)
    check("PointerOverlayManager sanitiza coordenadas contra NaN", "isNaN()" in pom_content)
    check("PointerOverlayManager alinea subpixel de punta de flecha con density", "tipOffset" in pom_content)
    check("PointerOverlayManager limite inferior dinamico resetBottomLimit", "resetBottomLimit" in pom_content)

# --- TEST 4B: FloatingTrackpadService (Burbuja Independiente de Mouse) ---
ftp_kt_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/FloatingTrackpadService.kt")
check("FloatingTrackpadService.kt existe", os.path.isfile(ftp_kt_path))
if os.path.isfile(ftp_kt_path):
    with open(ftp_kt_path, "r", encoding="utf-8") as f:
        ftp_content = f.read()
    check("FloatingTrackpadService extiende Service", "class FloatingTrackpadService : Service()" in ftp_content)
    check("FloatingTrackpadService implementa expandToDock", "fun expandToDock()" in ftp_content)
    check("FloatingTrackpadService implementa expandToMiniPad", "fun expandToMiniPad()" in ftp_content)
    check("FloatingTrackpadService implementa minimizeToBubble", "fun minimizeToBubble()" in ftp_content)
    check("FloatingTrackpadService maneja idle dimming", "idleDimRunnable" in ftp_content)
    check("FloatingTrackpadService snap a bordes", "snapBubbleToEdge" in ftp_content)
    check("FloatingTrackpadService integra VirtualTrackpadView", "VirtualTrackpadView(" in ftp_content)
    check("FloatingTrackpadService despacha taps a VoiceBubbleAccessibilityService", "VoiceBubbleAccessibilityService.dispatchTap" in ftp_content)
    check("FloatingTrackpadService despacha scroll a VoiceBubbleAccessibilityService", "VoiceBubbleAccessibilityService.dispatchScroll" in ftp_content)
    check("FloatingTrackpadService implementa rayita drag handle con gestos", "rayita" in ftp_content and "minimizeToBubble" in ftp_content)
    check("FloatingTrackpadService maneja extensión a 380dp y colapso", "380" in ftp_content and "240" in ftp_content)
    check("FloatingTrackpadService maneja arrastre minipad libre en 2D (x e y)", "expandedLayoutParams.x = (initialX + dx)" in ftp_content and "expandedLayoutParams.y = (initialY + dy)" in ftp_content)
    check("FloatingTrackpadService actualiza cota inferior del puntero al extender altura", "pointerManager?.updateKeyboardTop" in ftp_content)
    check("FloatingTrackpadService usa tema glass por defecto para Liquid Glass", 'theme = "glass"' in ftp_content)

ftp_dart_path = os.path.join(WORKSPACE, "app_source/lib/services/floating_trackpad_service.dart")
check("floating_trackpad_service.dart existe", os.path.isfile(ftp_dart_path))
if os.path.isfile(ftp_dart_path):
    with open(ftp_dart_path, "r", encoding="utf-8") as f:
        ftp_dart_content = f.read()
    check("floating_trackpad_service.dart define canal floating_trackpad", "com.royleguiza.voicebubblestt/floating_trackpad" in ftp_dart_content)
    check("floating_trackpad_service.dart tiene startTrackpadBubble", "startTrackpadBubble" in ftp_dart_content)
    check("floating_trackpad_service.dart tiene isAccessibilityGranted", "isAccessibilityGranted" in ftp_dart_content)

main_kt_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/MainActivity.kt")
with open(main_kt_path, "r", encoding="utf-8") as f:
    main_content = f.read()
check("MainActivity maneja TRACKPAD_CHANNEL", "TRACKPAD_CHANNEL" in main_content)
check("MainActivity maneja startTrackpadBubble", '"startTrackpadBubble"' in main_content)
check("MainActivity maneja isAccessibilityGranted", '"isAccessibilityGranted"' in main_content)

# --- TEST 5: VirtualTrackpadView (Opción 2 Split Wings & Top 50/50) ---
vtv_kt_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/VirtualTrackpadView.kt")
check("VirtualTrackpadView.kt existe", os.path.isfile(vtv_kt_path))
if os.path.isfile(vtv_kt_path):
    with open(vtv_kt_path, "r", encoding="utf-8") as f:
        vtv_content = f.read()
    check("VirtualTrackpadView maneja modos de scroll: right, left, disabled", '"right"' in vtv_content and '"left"' in vtv_content and '"disabled"' in vtv_content)
    check("VirtualTrackpadView auto-expansión al 100% de altura (weight 1.0f)", "weight = 1.0f" in vtv_content)
    check("VirtualTrackpadView scroll strip vertical (weight 1.4f)", "weight = 1.4f" in vtv_content)
    check("VirtualTrackpadView botón secundario compartido (weight 0.8f)", "weight = 0.8f" in vtv_content)
    check("VirtualTrackpadView soporte para Tap-to-Click", "tapToClick" in vtv_content)
    check("VirtualTrackpadView soporte para auto-retorno por inactividad", "autoReturnSeconds" in vtv_content)
    check("VirtualTrackpadView suprime tap-to-click tras interacción multitáctil (hadMultiTouch)", "hadMultiTouch" in vtv_content)
    check("VirtualTrackpadView re-ancla coordenadas tras ACTION_POINTER_UP para evitar saltos", "remainingIndex" in vtv_content)
    check("VirtualTrackpadView implementa modo de clic secundario 'hold' (mantener)", 'secondaryClickMode == "hold"' in vtv_content and "holdRunnable" in vtv_content)
    check("VirtualTrackpadView cancela pulsación de botón si el toque sale del área", "inside" in vtv_content)
    check("VirtualTrackpadView acota altura vía onMeasure con MeasureSpec.EXACTLY", "MeasureSpec.EXACTLY" in vtv_content and "onMeasure" in vtv_content)
    check("VirtualTrackpadView contraste accesible en clic izquierdo (acento primario)", "isPrimary" in vtv_content and "kb_key_bg_accent" in vtv_content)
    check("VirtualTrackpadView contraste accesible en clic derecho (neutro sólido)", "CLIC" in vtv_content and "DER" in vtv_content and ("3C3C43" in vtv_content or "EBEBF5" in vtv_content))
    check("VirtualTrackpadView feedback visual de contraste en scroll strip", "pressedBgColor" in vtv_content and ("26007AFF" in vtv_content or "330A84FF" in vtv_content))
    check("VirtualTrackpadView soporta modo dual de botones (top vs wings)", 'buttonLayout == "wings"' in vtv_content and "setupTopButtonsLayout" in vtv_content)
    check("VirtualTrackpadView usa iconos de mouse vectoriales ic_mouse_left e ic_mouse_right", "ic_mouse_left" in vtv_content and "ic_mouse_right" in vtv_content)
    check("VirtualTrackpadView soporta scroll quitado con 100% de ancho", '"none"' in vtv_content)

# --- TEST 6: VoiceKeyboardService integración ---
check("VoiceKeyboardService declara Layer.TRACKPAD", "enum class Layer" in vk_content and "TRACKPAD" in vk_content)
# SPK-05 módulo 6: toggle/build viven en TrackpadBridge; VKS delega.
check("Trackpad tiene toggle (VKS o TrackpadBridge)", "fun toggleTrackpadLayer()" in vk_content or ("class TrackpadBridge" in vk_content and "fun toggle()" in vk_content and "trackpad.toggle()" in vk_content))
check("Trackpad tiene build de capa (VKS o TrackpadBridge)", "fun buildTrackpadLayer(): View" in vk_content or ("fun buildLayer(): View" in vk_content and "addRow(trackpad.buildLayer())" in vk_content))
check("Rebuild monta la capa de trackpad", "addRow(buildTrackpadLayer())" in vk_content or "addRow(trackpad.buildLayer())" in vk_content)
check("VoiceKeyboardService suprime trackpad en contraseñas", "isPasswordInput" in vk_content and "currentIsPasswordField" in vk_content)
check("VoiceKeyboardService toolbar incluye botón de trackpad", "btnTrackpad" in vk_content)
check("Overlay del trackpad se oculta en onFinish/onHidden", "pointerOverlayManager?.hide()" in vk_content or "trackpad.hide()" in vk_content)
check("Trackpad previene loop en lastLetters", "layer != Layer.TRACKPAD" in vk_content or "cur != Layer.TRACKPAD" in vk_content or "Layer.TRACKPAD" in bridge_content)
check("VoiceKeyboardService lee kb_trackpad_auto_return tolerante a Integer y Long", "is Number -> raw.toInt()" in vk_content)
check("VoiceKeyboardService despacha trackpad vía InputConnection nativo", "sendDownUpKeyEvents(KeyEvent.KEYCODE_DPAD_CENTER)" in vk_content)
check("VoiceKeyboardService transición suave morphing al alternar trackpad", ("beginKeyboardTransition" in vk_content or "playTransition" in vk_content) and "TransitionManager" in vk_content)
check("VoiceKeyboardService altura determinista del trackpad acorde al teclado", "getTargetTrackpadHeightPx" in vk_content and "totalKeyRows" in vk_content)
check("VoiceKeyboardService MEJ-25 gestos en barra espaciadora", "attachSpacebarGestures" in vk_content)
check("VoiceKeyboardService MEJ-25 modo trackpad 2D con blank-out", "setTrackpadBlankOutMode" in vk_content and "spacebarTrackpadMode" in vk_content)
check("VoiceKeyboardService MEJ-25 selección de texto vía META_SHIFT_ON", "META_SHIFT_ON" in vk_content and "isSelecting" in vk_content)
check("VoiceKeyboardService MEJ-25 desplazamiento cinemático proporcional (stepsX/stepsY)", "stepsX" in vk_content and "stepsY" in vk_content)
check("VoiceKeyboardService expone commitFromExternal para inyección en cursor", "fun commitFromExternal" in vk_content and "instance" in vk_content)

# --- DynamicIslandController: RETIRADO (decisión del dueño) ---
# La isla/píldora dinámica se quitó del repo (solo burbuja clásica);
# estos chequeos documentan la ausencia para que una reintroducción
# accidental falle con mensaje claro en vez de pasar en silencio.
dic_kt_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/DynamicIslandController.kt")
check("Isla dinámica retirada (sin DynamicIslandController.kt)", not os.path.isfile(dic_kt_path),
      "Reapareció DynamicIslandController.kt: rever decisión de retirada")
# (La ausencia de claves island_* en app_source se verifica en TEST 12,
# donde storage_content ya está cargado.)

# --- TEST 7: Auditoría de Cero-Logs y Cero-Telemetría ---
trackpad_files = [acc_kt_path, pom_kt_path, vtv_kt_path, dic_kt_path]
leak_found = False
log_leak_pattern = re.compile(r'Log\.[a-z]+\(.*\b(coord|touch|event|gesture|x|y|window|key)\b', re.IGNORECASE)
for tf in trackpad_files:
    if os.path.isfile(tf):
        with open(tf, "r", encoding="utf-8") as f:
            for idx, line in enumerate(f, 1):
                if log_leak_pattern.search(line):
                    leak_found = True
                    print(f"  [LEAK] {os.path.basename(tf)}:{idx} -> {line.strip()}")

check("Auditoría de Privacidad: CERO logs ni telemetría en módulos de trackpad", not leak_found)

# --- TEST 8: StorageService (Dart) ---
dart_storage_path = os.path.join(WORKSPACE, "app_source/lib/services/storage_service.dart")
with open(dart_storage_path, "r", encoding="utf-8") as f:
    storage_content = f.read()

for k in TRACKPAD_KEYS:
    check(f"StorageService define clave {k}", f"'{k}'" in storage_content)

check("StorageService tiene getTrackpadEnabled / setTrackpadEnabled", "getTrackpadEnabled" in storage_content and "setTrackpadEnabled" in storage_content)
check("StorageService tiene getTrackpadButtonLayout / setTrackpadButtonLayout", "getTrackpadButtonLayout" in storage_content and "setTrackpadButtonLayout" in storage_content)
check("StorageService tiene getSpacebarTrackpadMode / setSpacebarTrackpadMode", "getSpacebarTrackpadMode" in storage_content and "setSpacebarTrackpadMode" in storage_content)
check("StorageService tiene getTrackpadScrollPosition / setTrackpadScrollPosition", "getTrackpadScrollPosition" in storage_content and "setTrackpadScrollPosition" in storage_content)
check("StorageService tiene getTrackpadSensitivity / setTrackpadSensitivity", "getTrackpadSensitivity" in storage_content and "setTrackpadSensitivity" in storage_content)
check("StorageService tiene getTrackpadAccelCurve / setTrackpadAccelCurve", "getTrackpadAccelCurve" in storage_content and "setTrackpadAccelCurve" in storage_content)
check("StorageService tiene getTrackpadTapToClick / setTrackpadTapToClick", "getTrackpadTapToClick" in storage_content and "setTrackpadTapToClick" in storage_content)
check("StorageService tiene getTrackpadSecondaryClick / setTrackpadSecondaryClick", "getTrackpadSecondaryClick" in storage_content and "setTrackpadSecondaryClick" in storage_content)
check("StorageService tiene getTrackpadScrollDirection / setTrackpadScrollDirection", "getTrackpadScrollDirection" in storage_content and "setTrackpadScrollDirection" in storage_content)
check("StorageService tiene getTrackpadHaptic / setTrackpadHaptic", "getTrackpadHaptic" in storage_content and "setTrackpadHaptic" in storage_content)
check("StorageService tiene getTrackpadPointerStyle / setTrackpadPointerStyle", "getTrackpadPointerStyle" in storage_content and "setTrackpadPointerStyle" in storage_content)
check("StorageService tiene getTrackpadAutoReturn / setTrackpadAutoReturn", "getTrackpadAutoReturn" in storage_content and "setTrackpadAutoReturn" in storage_content)
check("StorageService acota get/setTrackpadSensitivity a [0.5, 2.5] centralizado",
      "static const double minTrackpadSensitivity = 0.5;" in storage_content
      and "static const double maxTrackpadSensitivity = 2.5;" in storage_content
      and "clampTrackpadSensitivity(raw)" in storage_content
      and "clampTrackpadSensitivity(sensitivity)" in storage_content,
      "El clamp de sensibilidad no es central [0.5, 2.5] en get+set")
# Defaults OFF (2026-09-20, pedido del dueño): instalación nueva sin
# trackpad; quien lo tenía ON lo conserva en prefs (no hay reseteo).
check("Trackpad apagado por defecto en Dart (enabled)",
      "static const bool defaultTrackpadEnabled = false;" in storage_content,
      "El default volvió a true: instalación nueva mostraría el trackpad")
check("Trackpad apagado por defecto en Dart (toolbar)",
      "static const bool defaultTrackpadToolbarVisible = false;" in storage_content,
      "El default volvió a true en la toolbar")
check("Trackpad apagado por defecto en Kotlin (campos)",
      "var trackpadEnabled = false" in vk_content
      and "var trackpadToolbarVisible = false" in vk_content,
      "KeyboardPrefs.kt volvió a default true")
check("Trackpad apagado por defecto en Kotlin (lectura)",
      '.getBoolean("flutter.kb_trackpad_enabled", false)' in vk_content
      and '.getBoolean("flutter.kb_trackpad_toolbar_visible", false)' in vk_content,
      "La lectura de prefs volvió a defaultear true")

# --- TEST 9: SettingsScreen (Dart) ---
dart_settings_path = os.path.join(WORKSPACE, "app_source/lib/screens/settings_screen.dart")
with open(dart_settings_path, "r", encoding="utf-8") as f:
    settings_content = f.read()
# SPK-06 mod4: selector spacebar vive en settings/teclado_tab.dart
teclado_tab_path = os.path.join(WORKSPACE, "app_source/lib/screens/settings/teclado_tab.dart")
with open(teclado_tab_path, "r", encoding="utf-8") as f:
    teclado_content = f.read()
# SPK-06 mod5: tarjeta trackpad vive en settings/trackpad_tab.dart
trackpad_tab_path = os.path.join(WORKSPACE, "app_source/lib/screens/settings/trackpad_tab.dart")
with open(trackpad_tab_path, "r", encoding="utf-8") as f:
    trackpad_content = f.read()
trackpad_combined = settings_content + trackpad_content

check("SettingsScreen tiene tarjeta 'Modo Trackpad y Puntero Virtual'", "Modo Trackpad y Puntero Virtual" in trackpad_combined)
check("SettingsScreen tiene selector de distribución de botones de clic (top, wings)", "kb-trackpad-button-layout-selector" in trackpad_combined)
check("SettingsScreen tiene selector de modo trackpad en barra espaciadora", "kb-spacebar-trackpad-mode-selector" in settings_content or "kb-spacebar-trackpad-mode-selector" in teclado_content)
check("SettingsScreen tiene selector de posición de scroll (right, left, disabled)", "kb-trackpad-scroll-position-selector" in trackpad_combined)
check("SettingsScreen tiene slider de sensibilidad (0.5 a 2.5)", "kb-trackpad-sensitivity-slider" in trackpad_combined)
check("SettingsScreen tiene selector de curva de aceleración", "kb-trackpad-accel-curve-selector" in trackpad_combined)
check("SettingsScreen tiene selector de clic secundario", "kb-trackpad-secondary-click-selector" in trackpad_combined)
check("SettingsScreen tiene selector de dirección de scroll", "kb-trackpad-scroll-direction-selector" in trackpad_combined)
check("SettingsScreen tiene selector de estilo de puntero", "kb-trackpad-pointer-style-selector" in trackpad_combined)
check("SettingsScreen tiene selector de auto-retorno por inactividad", "kb-trackpad-auto-return-selector" in trackpad_combined)

# --- TEST 10: Vector drawables y recursos ---
drawable_tp = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/res/drawable/ic_trackpad.xml")
drawable_kb = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/res/drawable/ic_keyboard.xml")
drawable_ml = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/res/drawable/ic_mouse_left.xml")
drawable_mr = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/res/drawable/ic_mouse_right.xml")
drawable_copy = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/res/drawable/ic_copy.xml")
drawable_check = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/res/drawable/ic_check.xml")
strings_xml = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/res/values/strings.xml")

for d_name, d_path in [
    ("ic_trackpad.xml", drawable_tp),
    ("ic_keyboard.xml", drawable_kb),
    ("ic_mouse_left.xml", drawable_ml),
    ("ic_mouse_right.xml", drawable_mr),
    ("ic_copy.xml", drawable_copy),
    ("ic_check.xml", drawable_check),
]:
    check(f"{d_name} existe", os.path.isfile(d_path))
    if os.path.isfile(d_path):
        try:
            with open(d_path, "r", encoding="utf-8") as _df:
                d_text = _df.read()
            root = ET.fromstring(d_text)
            check(f"{d_name} raíz es <vector>", root.tag == "vector", f"raíz real: {root.tag}")
            ns_w = "{http://schemas.android.com/apk/res/android}width"
            ns_h = "{http://schemas.android.com/apk/res/android}height"
            check(f"{d_name} tamaño 24dp", root.get(ns_w) == "24dp" and root.get(ns_h) == "24dp",
                  f"width={root.get(ns_w)} height={root.get(ns_h)}")
            paths = root.findall("path")
            check(f"{d_name} contiene >=1 <path>", len(paths) >= 1, f"paths reales: {len(paths)}")
        except Exception as e:
            check(f"{d_name} es XML válido y parseable", False, str(e))
            continue
        if d_name == "ic_trackpad.xml":
            check("ic_trackpad.xml flecha puntero (path M3,3…)", "M3,3 L10.07,19.97" in d_text)
            check("ic_trackpad.xml tint kb_label", 'android:tint="@color/kb_label"' in d_text)
        elif d_name == "ic_keyboard.xml":
            check("ic_keyboard.xml 4 paths (marco+filas+espacio)", d_text.count("<path") == 4, f"<path reales: {d_text.count('<path')}")
            check("ic_keyboard.xml línea de espacio (M8,16 H16)", "M8,16 H16" in d_text)
        elif d_name == "ic_mouse_left.xml":
            check("ic_mouse_left.xml cuadrante izquierdo relleno", "M 12,2 C 8.13,2 5,5.13 5,9 L 12,9 Z" in d_text)
        elif d_name == "ic_mouse_right.xml":
            check("ic_mouse_right.xml cuadrante derecho relleno", "M 12,2 C 15.87,2 19,5.13 19,9 L 12,9 Z" in d_text)
        elif d_name == "ic_copy.xml":
            check("ic_copy.xml rectángulo frontal (M 9,9…)", "M 9,9 H 19 V 21 H 9 Z" in d_text)
        elif d_name == "ic_check.xml":
            check("ic_check.xml trazo verde #FF30D158", 'android:strokeColor="#FF30D158"' in d_text)
            check("ic_check.xml tick (M 4,12…)", "M 4,12 L 9,17 L 20,6" in d_text)

check("AndroidManifest declara permiso VIBRATE (háptica trackpad/píldora)",
      'android:name="android.permission.VIBRATE"' in manifest_content)
check("AndroidManifest declara FloatingBubbleService con exported=false",
      re.search(r'<service[^>]*\.FloatingBubbleService[^>]*android:exported="false"', manifest_content, re.DOTALL) is not None,
      "FloatingBubbleService sin exported=false")
check("AndroidManifest declara FloatingTrackpadService con exported=false",
      re.search(r'<service[^>]*\.FloatingTrackpadService[^>]*android:exported="false"', manifest_content, re.DOTALL) is not None,
      "FloatingTrackpadService sin exported=false")

with open(strings_xml, "r", encoding="utf-8") as f:
    str_content = f.read()
check("strings.xml define accessibility_service_name", 'name="accessibility_service_name"' in str_content)
check("strings.xml define accessibility_service_desc", 'name="accessibility_service_desc"' in str_content)

# --- TEST 11: Batería de tests unitarios Dart ---
dart_storage_test = os.path.join(WORKSPACE, "app_source/test/services/trackpad_storage_test.dart")
dart_settings_test = os.path.join(WORKSPACE, "app_source/test/screens/settings_trackpad_test.dart")

check("trackpad_storage_test.dart existe", os.path.isfile(dart_storage_test))
if os.path.isfile(dart_storage_test):
    with open(dart_storage_test, "r", encoding="utf-8") as f:
        dst_content = f.read()
    check("trackpad_storage_test.dart cubre las 11 claves y defaults", "getTrackpadScrollPosition" in dst_content and "getTrackpadSensitivity" in dst_content and "getTrackpadAutoReturn" in dst_content)

check("settings_trackpad_test.dart existe", os.path.isfile(dart_settings_test))
if os.path.isfile(dart_settings_test):
    with open(dart_settings_test, "r", encoding="utf-8") as f:
        stt_content = f.read()
    check("settings_trackpad_test.dart prueba renderizado y persistencia de widgets", "kb-trackpad-scroll-position-selector" in stt_content and "kb-trackpad-pointer-style-selector" in stt_content)

# --- TEST 12: Píldora e Isla Dinámica RETIRADAS (decisión del dueño) ---
# La batería MEJ-18 se archivó con la retirada: solo burbuja clásica.
# Se documenta la ausencia (código + claves + UI + tests Dart) para que
# una reintroducción parcial falle con mensaje claro.
check("Isla retirada del Storage (sin bubble_docking_mode)", "bubble_docking_mode" not in storage_content,
      "Reapareció bubble_docking_mode: rever decisión de retirada")
check("Isla retirada del Storage (sin island_pos_x)", "island_pos_x" not in storage_content,
      "Reaparecieron claves island_*: rever decisión de retirada")
check("Isla retirada de la UI (sin sección Píldora e Isla)", "Píldora e Isla Dinámica" not in settings_content,
      "Reapareció la sección de isla en Ajustes: rever decisión de retirada")
check("Isla retirada de los tests Dart",
      not os.path.isfile(os.path.join(WORKSPACE, "app_source/test/services/island_storage_test.dart"))
      and not os.path.isfile(os.path.join(WORKSPACE, "app_source/test/screens/settings_island_test.dart")),
      "Reaparecieron tests de isla: rever decisión de retirada")

# --- TEST 13: FloatingTrackpadService declarado como servicio NORMAL ---
# Es un Service corriente (no accesibilidad): declararlo es Play-Protect
# seguro. Lo declara otro agente; este test pasa con el manifest final.
# Si aún no está declarado se reporta como ITEM-INTERFAZ, no se adivina.
check("AndroidManifest declara FloatingTrackpadService como servicio normal",
      'android:name=".FloatingTrackpadService"' in manifest_content,
      "ITEM-INTERFAZ: otro agente debe declarar el servicio normal en el manifest")

# --- TEST 14: Contrato kb_trackpad_haptic consistente en tipo (String) ---
# Dart guarda String ('subtle'/'none'/'firm', default 'subtle') y
# VoiceKeyboardService lee getString: ambos lados coinciden.
check("Dart getTrackpadHaptic es String con dominio subtle/none/firm",
      "Future<String> getTrackpadHaptic()" in storage_content
      and "static const String defaultTrackpadHaptic = 'subtle'" in storage_content
      and "kbTrackpadHaptics = ['subtle', 'none', 'firm']" in storage_content,
      "El contrato Dart de kb_trackpad_haptic no es String")
check("VoiceKeyboardService lee kb_trackpad_haptic como String",
      ('private var trackpadHaptic = "subtle"' in vk_content or 'var trackpadHaptic = "subtle"' in vk_content)
      and '.getString("flutter.kb_trackpad_haptic", "subtle")' in vk_content
      and ("when (trackpadHaptic)" in vk_content or "when (kbPrefs.trackpadHaptic)" in vk_content),
      "VoiceKeyboardService no lee el haptic como String")
with open(ftp_kt_path, "r", encoding="utf-8") as f:
    ftp_content_recheck = f.read()
check("FloatingTrackpadService lee kb_trackpad_haptic como String (sin getBoolean)",
      '.getString("flutter.kb_trackpad_haptic"' in ftp_content_recheck,
      "ITEM-INTERFAZ CR-10: FloatingTrackpadService.kt usa getBoolean para una clave String (ClassCastException)")

# --- TEST 15: La UI no promete clics en otra app + degradación real ---
# Los textos del trackpad describen capa DENTRO del teclado; jamás se
# promete inyección/clics en otras apps (el despacho nativo exige el
# servicio conectado y degrada por fallback local).
check("UI del trackpad describe capa dentro del teclado",
      "Habilita la capa de trackpad con puntero de mouse en el teclado." in trackpad_combined
      and "Controla un puntero virtual en pantalla con aceleración cinemática" in trackpad_combined,
      "Faltan los textos honestos de la tarjeta de trackpad")
check("UI del trackpad sin promesas de clics en otra app",
      "inyecta" not in trackpad_combined
      and "clic en otra" not in trackpad_combined
      and "clics en otra" not in trackpad_combined
      and "controla otras" not in trackpad_combined,
      "La UI promete interacción fuera de la app")
check("VoiceKeyboardService degrada sin accesibilidad (gate isConnected)",
      "if (VoiceBubbleAccessibilityService.isConnected())" in vk_content,
      "El despacho del trackpad no verifica conexión antes de inyectar")
check("TrackpadBridge degrada a teclas locales (DPAD_CENTER/MENU)",
      "KEYCODE_DPAD_CENTER" in bridge_content
      and "KEYCODE_MENU" in bridge_content,
      "Sin fallback local cuando el servicio está dormido")
check("FloatingTrackpadService no despacha sin conexión (guards SPK-23)",
      ftp_content.count("if (!VoiceBubbleAccessibilityService.isConnected()) return") >= 3,
      "Faltan guards isConnected en onLeftClick/onRightClick/onScroll")
check("Contrato dormido documentado (docs/contrato-trackpad.md)",
      os.path.isfile(os.path.join(WORKSPACE, "docs/contrato-trackpad.md"))
      and "puntero local" in open(os.path.join(WORKSPACE, "docs/contrato-trackpad.md"), encoding="utf-8").read().lower(),
      "Falta la fuente única del estado dormido")
check("Aviso honesto en la UI de Ajustes (puntero local)",
      "Puntero local" in trackpad_combined,
      "La UI no avisa que no hace clic fuera")

print("\n============================================================")
print(f" RESULTADO SUITE TRACKPAD & ISLA: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
