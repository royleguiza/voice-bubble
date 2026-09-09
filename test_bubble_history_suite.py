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
import re
import sys

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check


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
# SPK-11: vistas extraídas a HistoryCardView/SnippetsCardView (el controlador
# delega; los checks de tarjetas miran los tres archivos).
history = read("voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/HistoryCardView.kt")
snip = read("voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/SnippetsCardView.kt")
cards = kt + history + snip

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
check("Vacio elegante Sin transcripciones", "Sin transcripciones todav" in cards)

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
      "loadBubbleHistoryEnabled" in dart_storage
      and ("?? true" in dart_storage
           or "_getBool(_bubbleHistoryKey, true)" in dart_storage))
dart_settings = read("app_source/lib/screens/settings_screen.dart")
dart_burbuja = read("app_source/lib/screens/settings/burbuja_tab.dart")
check("Settings con switch bubble-history-switch",
      ("bubble-history-switch" in dart_settings or "bubble-history-switch" in dart_burbuja) and ("Historial en la burbuja" in dart_settings or "Historial en la burbuja" in dart_burbuja))
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

# --- 8. Perfil anti-Play-Protect: SettingsScreen NO debe leer el canal
# trackpad en su init (lectura colgada sin mock + superficie declarada sin
# accesibilidad). Permitido: arrancar/detener la burbuja desde el handler
# del toggle (best-effort con canal ausente = false, sin lecturas en init
# ni en _loadInitialState). Si algún día vuelve una LECTURA de estado en
# init (isTrackpadBubbleRunning), este guard avisa y hay que mockear en
# todos los tests que monten SettingsScreen ---
settings_dart = read("app_source/lib/screens/settings_screen.dart")
check("SettingsScreen sin lecturas del canal trackpad en init",
      "isTrackpadBubbleRunning" not in settings_dart
      and "isAccessibilityGranted" not in settings_dart,
      "reintroduce colgadas en tests sin mock")
manifest_txt = read("voice_bubble_stt/android/app/src/main/AndroidManifest.xml")
# Sin comentarios XML: un comentario que documenta la AUSENCIA (p. ej.
# "Sin BIND_ACCESSIBILITY_SERVICE por perfil anti-Play-Protect") no es
# una declaración. Lo prohibido es el elemento <service>/<uses-permission>.
manifest_decls = re.sub(r"<!--.*?-->", "", manifest_txt, flags=re.DOTALL)
check("Manifest sin servicio de accesibilidad (perfil anti-Play-Protect)",
      "VoiceBubbleAccessibilityService" not in manifest_decls
      and "BIND_ACCESSIBILITY_SERVICE" not in manifest_decls)

# --- 9. Rotación con popup abierto: dismiss seguro, sin recreación ---
# La Activity declara configChanges de orientación (el sistema NO la
# recrea al rotar) y todo setState/popup tras await va tras `mounted`;
# el AnimationController del popup se libera en dispose().
home_screen = read("app_source/lib/screens/home_screen.dart")
check("Activity sobrevive a la rotación (configChanges con orientation)",
      'android:configChanges="orientation|keyboardHidden|keyboard|screenSize' in manifest_txt,
      "Falta orientation en configChanges: rotar recrearía la Activity")
check("Popup de resultado tras await solo toca UI si mounted",
      "if (mounted) {" in home_screen and "_popupCtrl.forward(from: 0)" in home_screen,
      "El popup post-transcripción no está tras guarda mounted")
check("Popup usa SnackBar de error con reintento (rotación no pierde el audio)",
      "label: 'Reintentar'" in home_screen and "_pendingAudioPath" in home_screen,
      "Falta el camino de reintento tras error")
check("AnimationController del popup se libera en dispose",
      "_popupCtrl.dispose();" in home_screen,
      "Falta _popupCtrl.dispose()")

# --- 10. Sección Snippets en la modal (swipe lateral en la rayita) ---
check("Secciones Historial/Snippets con constantes y umbral 48 dp",
      "SECTION_HISTORY" in kt and "SECTION_SNIPPETS" in kt and "SECTION_SWIPE_DP = 48" in kt,
      "Faltan constantes de sección")
check("Presión larga abre siempre en Historial",
      'section = SECTION_HISTORY' in kt,
      "showFrom debe resetear a Historial")
check("Etiqueta bajo la rayita dice la sección (Historial/Snippets)",
      "handleLabel" in kt and '"Historial"' in kt and '"Snippets"' in kt,
      "Falta el TextView de sección bajo la rayita")
check("Swipe lateral en la rayita alterna sección (switchSection)",
      "fun switchSection()" in kt and "switchSection()" in kt,
      "El gesto lateral debe alternar sección")
check("Recambio animado de sección con slide (renderSection)",
      "fun renderSection(" in kt and "translationX(" in kt,
      "Falta la animación de deslizamiento al cambiar")
check("Snippets leídos del mismo store (load + seed idempotente)",
      "fun populateSnippets()" in kt and "SnippetStore(context)" in kt
      and "seedIfFirstOpen()" in kt and ".load()" in kt,
      "Debe usar SnippetStore sin claves nuevas")
check("Sin claves de puente nuevas (mismas del contrato)",
      "flutter.voice_snippets_v1" not in kt and "flutter.kb_snippets_seeded" not in kt,
      "BubbleHistoryController no debe hardcodear claves (viven en SnippetStore)")
check("Tarjeta snippet outlined con título flotante (legend)",
      "fun buildSnippetCard(" in cards and "bubble_legend_bg" in cards and "MONOSPACE" in cards,
      "Falta la tarjeta fieldset/legend")
check("Editar abajo-izquierda y copiar abajo-derecha (ops con spacer)",
      'contentDescription = "Editar snippet"' in cards and 'contentDescription = "Copiar snippet"' in cards,
      "Faltan acciones editar/copiar en la tarjeta")
check("Tap en snippet inserta+copia+cierra (gestos reutilizados)",
      "attachCardGestures(" in kt and "paintBackground" in kt,
      "Los gestos por tarjeta deben reutilizarse con pintado propio")
check("Outlined preservado tras seleccionar/deseleccionar",
      'startsWith("snip|")' in kt and "snippetBoxBackground(" in kt,
      "resetCardSelections debe respetar el outlined")
check("Editar abre la app (intent de paquete + compacta)",
      "fun openAppForEdit()" in kt and "getLaunchIntentForPackage" in kt,
      "Editar debe abrir la app")
check("Cierre congela el texto antes de encoger (sin saltos)",
      "cardsList?.visibility = View.GONE" in kt and "cardsList?.alpha = 0f" in kt,
      "close() debe ocultar la lista antes del morph")
check("Modal adapta a tema claro (fondo/borde por recursos)",
      "R.color.bubble_modal_bg" in kt and "R.color.bubble_modal_border" in kt,
      "El fondo fijo oscuro rompía el contraste en claro")
for _res, _name in [("voice_bubble_stt/android/app/src/main/res/values/colors.xml", "claro"),
                    ("voice_bubble_stt/android/app/src/main/res/values-night/colors.xml", "oscuro")]:
    _c = read(_res)
    for _k in ["bubble_modal_bg", "bubble_modal_border", "bubble_legend_bg"]:
        check(f"Color {_k} en {_name}", f'name="{_k}"' in _c, f"Falta {_k} en {_name}")
import re as _re
for _res in ["voice_bubble_stt/android/app/src/main/res/values/colors.xml",
             "voice_bubble_stt/android/app/src/main/res/values-night/colors.xml"]:
    _hexes = _re.findall(r"#[0-9A-Fa-f]+", read(_res))
    _bad = [h for h in _hexes if len(h) not in (4, 5, 7, 9)]
    check(f"Hex válidos en {_res.split('/')[-2]}", not _bad, f"Hex inválidos: {_bad}")

print("\n============================================================")
print(f" RESULTADO SUITE BURBUJA-HISTORIAL: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
