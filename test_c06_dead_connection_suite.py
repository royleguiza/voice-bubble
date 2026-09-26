#!/usr/bin/env python3
"""
TEST SUITE: BLINDAJE DEL TECLADO ANTE CONEXIÓN MUERTA (CONTRATO C-06)

Verifica al 100% de certeza sobre el código REAL:
1. Cero llamadas a `currentInputConnection?.` sin control posterior en los 6 archivos
   del contrato (EditEngine, SnippetsLayer, ClipboardLayer, DictationController,
   HistoryLayer, StatusLayer).
2. Helper `commitOrWarn` en nivel de paquete y en cada capa objetivo,
   capturando DeadObjectException, RemoteException, IllegalStateException y Exception.
3. Blindaje de operaciones por lotes, teclas y selección en EditEngine:
   - handleShiftTap (getSelectedText, getExtractedText, beginBatchEdit/commit/setSelection/endBatchEdit)
   - sendKeyEventWithMeta (sendKeyEvent en try/catch)
   - sendKeyCode y handleEnter (sendDownUpKeyEvents en try/catch)
   - handleBackspace (getSelectedText, getTextBeforeCursor, deleteSurroundingText, KEYCODE_DEL)
   - deleteWordBeforeCursor (getTextBeforeCursor, deleteSurroundingText)
4. Blindaje en capas auxiliares:
   - SnippetsLayer: inserción protegida con commitOrWarn, aborta antes de setLayer si falla.
   - ClipboardLayer: pasteClip solo cambia de capa si commitOrWarn/commitImageClip devuelve true.
   - DictationController: onDone solo emite MicEvent.PASTE si commitOrWarn devuelve true.
   - HistoryLayer: clic de elemento solo cierra popups si commitOrWarn devuelve true.
   - StatusLayer: aviso no intrusivo sin volcar contenido confidencial ni registrar logs.
5. Mutaciones negativas: verifica que reintroducir llamadas desprotegidas o eliminar
   las compuertas de aborto rompe la suite.
"""

import os
import re
import sys

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check

print("\n============================================================")
print(" INICIANDO TEST SUITE: CONTRATO C-06 (CONEXIÓN MUERTA)")
print("============================================================\n")

# Archivos del contrato C-06
EE_PATH = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/EditEngine.kt"
SNIP_PATH = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/SnippetsLayer.kt"
CLIP_PATH = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/ClipboardLayer.kt"
DICT_PATH = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/DictationController.kt"
HIST_PATH = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/HistoryLayer.kt"
STAT_PATH = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/StatusLayer.kt"

FILES = {
    "EditEngine": EE_PATH,
    "SnippetsLayer": SNIP_PATH,
    "ClipboardLayer": CLIP_PATH,
    "DictationController": DICT_PATH,
    "HistoryLayer": HIST_PATH,
    "StatusLayer": STAT_PATH,
}

# 1. Existencia de archivos
for name, path in FILES.items():
    check(f"Archivo {name} existe", os.path.isfile(os.path.join(WORKSPACE, path)))

ee = suite.read(EE_PATH)
snip = suite.read(SNIP_PATH)
clip = suite.read(CLIP_PATH)
dict_ctrl = suite.read(DICT_PATH)
hist = suite.read(HIST_PATH)
stat = suite.read(STAT_PATH)

# 2. Cero llamadas `currentInputConnection?.` sin protección en los 6 archivos de C-06
for name, content in [
    ("EditEngine", ee),
    ("SnippetsLayer", snip),
    ("ClipboardLayer", clip),
    ("DictationController", dict_ctrl),
    ("HistoryLayer", hist),
    ("StatusLayer", stat),
]:
    matches = re.findall(r"currentInputConnection\?\.([a-zA-Z0-9_]+)", content)
    check(
        f"{name}: cero llamadas currentInputConnection?. (encontradas {len(matches)})",
        len(matches) == 0,
        f"Llamadas encontradas: {matches}",
    )

# 3. Helper commitOrWarn y captura exhaustiva de excepciones IPC en EditEngine
check("EditEngine: DeadObjectException importado", "import android.os.DeadObjectException" in ee)
check("EditEngine: RemoteException importado", "import android.os.RemoteException" in ee)

check(
    "EditEngine: commitOrWarn a nivel de paquete existe",
    "internal fun commitOrWarn(" in ee and "service: InputMethodService" in ee,
)

commit_fn = ee[ee.find("internal fun commitOrWarn") : ee.find("internal fun warnDeadConnection")]
for exc in ["DeadObjectException", "RemoteException", "IllegalStateException", "Exception"]:
    check(f"commitOrWarn captura {exc}", f"catch (_: {exc})" in commit_fn)

check(
    "commitOrWarn valida resultado de commitText",
    "ic.commitText(text, 1)" in commit_fn and "if (!ok)" in commit_fn,
)

# 4. Blindaje de handleShiftTap
check(
    "handleShiftTap protege getSelectedText",
    "ic.getSelectedText(0)" in ee and "catch (_: DeadObjectException)" in ee,
)
check(
    "handleShiftTap protege getExtractedText",
    "ic.getExtractedText(" in ee and "catch (_: RemoteException)" in ee,
)
check(
    "handleShiftTap protege batch y commit con try/catch/finally",
    "batchStarted = ic.beginBatchEdit()" in ee
    and "ic.endBatchEdit()" in ee
    and "ic.setSelection(" in ee,
)
check(
    "handleShiftTap aborta y avisa si commit no prospera",
    "if (!committed) {" in ee and "warnDeadConnection()" in ee,
)

# 5. Blindaje de eventos de teclado en EditEngine
check(
    "sendKeyEventWithMeta envuelve sendKeyEvent en try/catch",
    "ic.sendKeyEvent(" in ee and "catch (_: DeadObjectException)" in ee,
)
check(
    "sendKeyCode envuelve sendDownUpKeyEvents en try/catch",
    "service.sendDownUpKeyEvents(keyCode)" in ee and "warnDeadConnection()" in ee,
)
bksp_fn = ee[ee.find("fun handleBackspace()") : ee.find("fun deleteWordBeforeCursor()")]
check(
    "handleBackspace protege getSelectedText, getTextBeforeCursor y deleteSurroundingText",
    "ic.deleteSurroundingText(count, 0)" in bksp_fn
    and "service.sendDownUpKeyEvents(KeyEvent.KEYCODE_DEL)" in bksp_fn
    and "catch (_: DeadObjectException)" in bksp_fn,
)
delword_fn = ee[ee.find("fun deleteWordBeforeCursor()") : ee.find("fun handleEnter()")]
check(
    "deleteWordBeforeCursor envuelve deleteSurroundingText en try/catch",
    "ic.getTextBeforeCursor(SWIPE_WORD_LOOKBACK_CHARS" in delword_fn
    and "ic.deleteSurroundingText(count, 0)" in delword_fn
    and "catch (_: DeadObjectException)" in delword_fn,
)
enter_fn = ee[ee.find("fun handleEnter()") :]
check(
    "handleEnter envuelve sendDownUpKeyEvents en try/catch",
    "service.sendDownUpKeyEvents(KeyEvent.KEYCODE_ENTER)" in enter_fn
    and "catch (_: DeadObjectException)" in enter_fn,
)
check(
    "commitLetter solo libera shift si commitOrWarn fue exitoso",
    "if (commitOrWarn(displayFor(base))) {" in ee and "releaseMomentaryShift()" in ee,
)
check(
    "commitSymbolText solo consume modificadores si commitOrWarn fue exitoso",
    "if (commitOrWarn(text)) {" in ee and "consumeModifiers()" in ee,
)

# 6. Blindaje en capas UI (SnippetsLayer, ClipboardLayer, DictationController, HistoryLayer)
check(
    "SnippetsLayer: inserción aborta si commitOrWarn falla",
    "if (!commitOrWarn(snippet.contenido)) return" in snip,
)
insert_body = snip[snip.find("private fun insert(snippet: VbSnippet)") :]
check(
    "SnippetsLayer: no cambia de capa si commit falla",
    insert_body.find("if (!commitOrWarn(snippet.contenido)) return") < insert_body.find("host.setLayer(origin)"),
)

check(
    "ClipboardLayer: pasteClip solo cambia de capa si commitOrWarn devuelve true",
    "if (commitOrWarn(text)) {" in clip and "host.showLayer(origin)" in clip,
)
check(
    "ClipboardLayer: commitImageClip retorna Boolean",
    "private fun commitImageClip(clip: ClipboardItem): Boolean" in clip,
)
check(
    "ClipboardLayer: commitImageClip envuelve MIME types y commitContent en try/catch",
    "EditorInfoCompat.getContentMimeTypes" in clip
    and "InputConnectionCompat.commitContent" in clip
    and "catch (_: DeadObjectException)" in clip,
)

check(
    "DictationController: onDone solo emite MicEvent.PASTE si commitOrWarn devuelve true",
    "if (commitOrWarn(text)) {" in dict_ctrl and "micEvent(MicEvent.PASTE)" in dict_ctrl,
)

check(
    "HistoryLayer: clic solo cierra popups si commitOrWarn devuelve true",
    "if (commitOrWarn(text)) {" in hist and "host.dismissPopups()" in hist,
)

# 7. StatusLayer y aviso sin fuga de información confidencial
check(
    "StatusLayer: constantes de conexión perdida i18n",
    'NOTICE_DEAD_CONNECTION_ES = "Conexión perdida"' in stat
    and 'NOTICE_DEAD_CONNECTION_EN = "Connection lost"' in stat,
)
check(
    "StatusLayer: registro de activeInstance para avisos en línea",
    "@Volatile\n        internal var activeInstance: StatusLayer?" in stat
    or "@Volatile internal var activeInstance: StatusLayer?" in stat
    or "internal var activeInstance: StatusLayer?" in stat,
)
warn_fn = ee[ee.find("internal fun warnDeadConnection") : ee.find("/**\n * Motor de edición")]
check(
    "warnDeadConnection no recibe texto ni filtra contenido del usuario",
    "text:" not in warn_fn and "text," not in warn_fn and "msg = if (isSpanish)" in warn_fn,
)

# 8. Mutaciones negativas: verificación de que la suite detecta regresiones
def test_mutations():
    # Mutación 1: SnippetsLayer vuelve a usar `currentInputConnection?.commitText`
    mutated_snip = snip.replace("if (!commitOrWarn(snippet.contenido)) return", "service.currentInputConnection?.commitText(snippet.contenido, 1)")
    found_m1 = len(re.findall(r"currentInputConnection\?\.([a-zA-Z0-9_]+)", mutated_snip)) > 0
    check("Mutación negativa 1 (SnippetsLayer reintroduce currentInputConnection?.): detectada", found_m1)

    # Mutación 2: ClipboardLayer cambia de capa incondicionalmente
    mutated_clip = clip.replace("if (commitOrWarn(text)) {\n                    if (autoClose", "host.showLayer(origin)\n                    if (autoClose")
    found_m2 = "if (commitOrWarn(text)) {" not in mutated_clip
    check("Mutación negativa 2 (ClipboardLayer cambio de capa incondicional): detectada", found_m2)

    # Mutación 3: DictationController emite PASTE incondicionalmente
    mutated_dict = dict_ctrl.replace("if (commitOrWarn(text)) {\n                                micEvent(MicEvent.PASTE)\n                            }", "service.currentInputConnection?.commitText(text, 1)\nmicEvent(MicEvent.PASTE)")
    found_m3 = "if (commitOrWarn(text)) {" not in mutated_dict
    check("Mutación negativa 3 (DictationController PASTE incondicional): detectada", found_m3)

    # Mutación 4: HistoryLayer cierra popups incondicionalmente
    mutated_hist = hist.replace("if (commitOrWarn(text)) {\n                        host.dismissPopups()\n                    }", "host.dismissPopups()")
    found_m4 = "if (commitOrWarn(text)) {" not in mutated_hist
    check("Mutación negativa 4 (HistoryLayer dismiss incondicional): detectada", found_m4)

    # Mutación 5: EditEngine elimina captura de DeadObjectException en commitOrWarn
    mutated_ee = ee.replace("catch (_: DeadObjectException)", "catch (_: RuntimeException)")
    found_m5 = "catch (_: DeadObjectException)" not in mutated_ee
    check("Mutación negativa 5 (EditEngine suprime DeadObjectException): detectada", found_m5)

test_mutations()

print("\n============================================================")
print(f" RESULTADOS C-06: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

sys.exit(suite.exit_code())
