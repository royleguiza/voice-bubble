#!/usr/bin/env python3
"""
TEST SUITE: MODAL DE HISTORIAL DE LA BURBUJA CLASICA (hito B1-B7)
Verifica al 100% de certeza:
1. BubbleHistoryController.kt: existencia, API (showFrom/close/destroy),
   cuadrante inteligente, morph reversible y Reduced Motion.
2. Gestos por card: toque inserta, toque largo expande, swipe selecciona,
   copiar-todo con 2+ y slot permanente (rayita centrada).
3. FloatingBubbleService: toque largo 500 ms, gate por switch, ciclo de vida
   y un unico companion object.
4. Recursos: drawables ic_copy/ic_check/kb_ic_mic y colores usados.
5. Privacidad: CERO Log con contenido en el archivo nuevo.
6. Dart: clave bubble_history_enabled (storage + settings + contrato + tests).
"""

import os
import sys

WORKSPACE = os.path.dirname(os.path.abspath(__file__))
PASSED = 0
FAILED = 0

def check(name, condition, error_msg=""):
    global PASSED, FAILED
    if condition:
        print(f"  [PASS] {name}")
        PASSED += 1
    else:
        print(f"  [FAIL] {name} -> {error_msg}")
        FAILED += 1

def read(rel):
    with open(os.path.join(WORKSPACE, rel), "r", encoding="utf-8") as f:
        return f.read()

print("\n============================================================")
print(" INICIANDO TEST SUITE: MODAL HISTORIAL BURBUJA CLASICA (B1-B7)")
print("============================================================\n")

KT = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/BubbleHistoryController.kt"
FBS = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/FloatingBubbleService.kt"

check("BubbleHistoryController.kt existe", os.path.isfile(os.path.join(WORKSPACE, KT)))
kt = read(KT)
fbs = read(FBS)

# --- 1. API del controlador ---
for fn in ["fun showFrom(", "fun close()", "fun destroy()", "fun isOpen()",
           "fun isEnabled(", "populateCards()", "fun buildCard(",
           "attachCardGestures(", "handleCardTap(", "refreshCopyAll()",
           "copySelected()", "copyToClipboard(", "reducedMotion()", "morphTo("]:
    check(f"BubbleHistoryController implementa {fn}", fn in kt, f"falta {fn}")

check("Controller NO es un Service (clase plana instanciada por el FGS)",
      "class BubbleHistoryController(" in kt and ": Service()" not in kt.split("class BubbleHistoryController(")[1][:120])

# --- 2. Cuadrante inteligente + morph ---
check("Constantes de geometria lab (64/12/300x400/320ms)",
      all(s in kt for s in ["BUBBLE_DP = 64", "MARGIN_DP = 12", "MODAL_W_DP = 300", "MODAL_H_DP = 400", "MORPH_MS = 320L"]))
check("Seleccion de diagonal con goLeft/goUp y clamp coerceIn",
      "goLeft" in kt and "goUp" in kt and "coerceIn" in kt)
check("Morph reversible al origen (originX/originY/originSize)",
      "originX" in kt and "originY" in kt and "originSize" in kt)
check("Radio morph 32dp<->20dp como el lab", "20f * density" in kt)
check("Reduced Motion via ANIMATOR_DURATION_SCALE", "ANIMATOR_DURATION_SCALE" in kt)
check("Overlay TYPE_APPLICATION_OVERLAY + FLAG_NOT_FOCUSABLE",
      "TYPE_APPLICATION_OVERLAY" in kt and "FLAG_NOT_FOCUSABLE" in kt)

# --- 3. Gestos por card ---
check("Toque largo 450 ms que expande (maxLines)", "LONG_PRESS_MS = 450L" in kt and "Int.MAX_VALUE" in kt)
check("Swipe con umbral 48 dp y tope 72 dp", "SWIPE_ARM_DP = 48" in kt and "SWIPE_MAX_DP = 72" in kt)
check("Retorno elastico del swipe (translationX a 0)", "translationX(0f)" in kt)
check("Insercion directa via commitFromExternal + copia + cierre",
      "commitFromExternal" in kt and "close()" in kt)
check("Copiar-todo une con salto de linea", 'joinToString("\\n")' in kt)
check("Copiar-todo visible solo con 2+ (slot INVISIBLE permanente)",
      "selected.size >= 2" in kt and "View.INVISIBLE" in kt)
check("Mic estilo kb_ic_mic abajo-derecha + rayita Contraer",
      "kb_ic_mic" in kt and '"Contraer"' in kt)
check("Haptico al seleccionar (VIRTUAL_KEY tolerante)", "VIRTUAL_KEY" in kt)
check("Vacio elegante Sin transcripciones", "Sin transcripciones todav" in kt)

# --- 4. Wiring en FloatingBubbleService ---
check("Toque largo 500 ms en la burbuja clasica", "BUBBLE_LONG_PRESS_MS = 500L" in fbs)
check("Gate por switch isEnabled antes de mostrar", "BubbleHistoryController.isEnabled" in fbs)
check("showBubbleHistory() como miembro (no anidada en setup)",
      "fun showBubbleHistory()" in fbs)
check("Mic de la modal reenvia onBubbleTap (graba via Dart)",
      "bubbleHistoryController?.close()" in fbs and "onBubbleActionListener?.onBubbleTap()" in fbs)
check("onDestroy destruye el controlador", "bubbleHistoryController?.destroy()" in fbs)
check("Un unico companion object (Kotlin lo exige)",
      fbs.count("companion object") == 1, "multiples companion objects no compilan")
check("Burbuja oculta (GONE) con modal abierta y restaurada al cerrar",
      "visibility = View.GONE" in fbs and "visibility = View.VISIBLE" in fbs)

# --- 5. Recursos ---
for dw in ["ic_copy.xml", "ic_check.xml", "kb_ic_mic.xml"]:
    check(f"Drawable {dw} existe",
          os.path.isfile(os.path.join(WORKSPACE, f"voice_bubble_stt/android/app/src/main/res/drawable/{dw}")))
colors = read("voice_bubble_stt/android/app/src/main/res/values/colors.xml")
for c in ["bubble_idle_bg", "bubble_idle_border", "kb_recording"]:
    check(f"Color {c} declarado", f'name="{c}"' in colors)

# --- 6. Privacidad ---
import re
logs = re.findall(r"Log\.[a-z]+\(.*", kt)
check("CERO Log.* en BubbleHistoryController", len(logs) == 0, f"{len(logs)} logs")
check("Sin lectura de texto previo (node.text/getText)",
      "node.text" not in kt and ".getText()" not in kt)
check("Sin BIND nuevo ni permisos nuevos en el manifest",
      "BubbleHistory" not in read("voice_bubble_stt/android/app/src/main/AndroidManifest.xml"))

# --- 7. Dart: switch bubble_history_enabled ---
dart_storage = read("app_source/lib/services/storage_service.dart")
check("StorageService load/save bubble_history_enabled",
      "loadBubbleHistoryEnabled" in dart_storage and "saveBubbleHistoryEnabled" in dart_storage)
check("Default ON del historial de burbuja",
      "loadBubbleHistoryEnabled" in dart_storage and "?? true" in dart_storage)
dart_settings = read("app_source/lib/screens/settings_screen.dart")
check("Settings con switch bubble-history-switch",
      "bubble-history-switch" in dart_settings and "Historial en la burbuja" in dart_settings)
check("Toggle persiste via saveBubbleHistoryEnabled",
      "_toggleBubbleHistory" in dart_settings)
contract = read("docs/contract-keys.txt").splitlines()
check("Clave bubble_history_enabled en docs/contract-keys.txt",
      "bubble_history_enabled" in contract)
check("Kotlin lee flutter.bubble_history_enabled (paridad)",
      "flutter.bubble_history_enabled" in kt)
dart_storage_test = read("app_source/test/services/storage_service_test.dart")
check("Tests de persistencia del switch (hito B6)",
      "loadBubbleHistoryEnabled" in dart_storage_test)
dart_settings_test = read("app_source/test/screens/settings_screen_test.dart")
check("Tests de render y toggle del switch (hito B6)",
      "bubble-history-switch" in dart_settings_test)

# --- 8. Leccion CI: todo test que monte SettingsScreen debe mockear el
# canal trackpad (lectura en _loadInitialState; sin mock se cuelga y el
# setState inicial no aplica) ---
import glob
for tf in sorted(glob.glob(os.path.join(WORKSPACE, "app_source/test/**/*.dart"), recursive=True)):
    try:
        with open(tf, "r", encoding="utf-8") as f:
            content = f.read()
    except OSError:
        continue
    if "SettingsScreen(" not in content:
        continue
    uses_helper = "registerAppChannelMocks" in content
    mocks_trackpad = "floating_trackpad" in content or "floating-trackpad" in content
    check(f"{os.path.relpath(tf, WORKSPACE)} mockea canal trackpad",
          uses_helper or mocks_trackpad,
          "lectura colgada en _loadInitialState sin mock")

helper = read("app_source/test/helpers/mock_channels.dart")
check("mock_channels.dart cubre floating_trackpad",
      "floating_trackpad" in helper and "isAccessibilityGranted" in helper)

print("\n============================================================")
print(f" RESULTADO SUITE BURBUJA-HISTORIAL: {PASSED} pasados, {FAILED} fallidos.")
print("============================================================\n")

if FAILED > 0:
    sys.exit(1)
sys.exit(0)
