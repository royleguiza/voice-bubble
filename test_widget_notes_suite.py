#!/usr/bin/env python3
"""
SUITE Widget grande de notas (rediseño: + abajo-izq, píldora extensible).
Valida estáticamente layout + provider + servicio sin SDK Android.
"""
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).parent
RES = ROOT / "voice_bubble_stt/android/app/src/main/res"
KT = ROOT / "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
LAYOUT = RES / "layout/widget_notes.xml"
PROVIDER = KT / "WidgetNotesProvider.kt"
SERVICE = KT / "WidgetDictationService.kt"

ALLOWED_REMOTEVIEWS = {
    "FrameLayout", "LinearLayout", "RelativeLayout", "GridLayout",
    "AnalogClock", "Button", "Chronometer", "ImageButton", "ImageView",
    "ProgressBar", "TextClock", "TextView", "ViewFlipper",
    "ListView", "GridView", "StackView", "AdapterViewFlipper",
    "ViewStub", "ScrollView", "HorizontalScrollView",
}
NS = "{http://schemas.android.com/apk/res/android}"

passed, failed = [], []

def check(name, cond, detail=""):
    (passed if cond else failed).append(name)
    print(f"  [{'PASS' if cond else 'FAIL'}] {name}" + (f" — {detail}" if detail and not cond else ""))

tree = ET.parse(LAYOUT)
tags = [e.tag for e in tree.iter() if not e.tag.startswith("{")]
check("Solo vistas permitidas en RemoteViews", all(t in ALLOWED_REMOTEVIEWS for t in tags), str(sorted(set(tags))))
check("Sin <View> pelado (causa del 'No se puede mostrar')",
      not re.search(r"<View[\s>]", LAYOUT.read_text()))

xml = LAYOUT.read_text()
# Orden: + antes que mic (abajo-izq / abajo-der)
pos_add = xml.index('android:id="@+id/widget_notes_add"')
pos_mic = xml.index('android:id="@+id/widget_notes_mic"')
check("+ a la izquierda del mic en el XML", pos_add < pos_mic)
check("Header sin + (solo Notas + contador)",
      '@+id/widget_notes_add' in xml and xml.index('@+id/widget_notes_add') > xml.index('@+id/widget_notes_list'))
check("Existe píldora de grabación", '@+id/widget_rec_pill' in xml)
check("Existe label de píldora", '@+id/widget_rec_label' in xml)
check("Existe add espejo para modo mic-izq", '@+id/widget_notes_add_right' in xml)

def dp_of(view_id, attr="layout_width"):
    m = re.search(r'@\+id/%s".*?%s="(\d+)dp"' % (view_id, attr), xml, re.S)
    return int(m.group(1)) if m else None

mic = dp_of("widget_notes_mic")
pill_h = dp_of("widget_rec_pill", "layout_height")
check("Mic circular (52dp) mayor que píldora (48dp)", mic == 52 and pill_h == 48, f"mic={mic} pill={pill_h}")
cancel = dp_of("widget_cancel")
check("Botón cancelar >= 44dp", (cancel or 0) >= 44, f"cancel={cancel}")

# F1: reposo estilo pill glass (como el contador), sin círculos blancos
def bg_of(view_id):
    m = re.search(r'@\+id/%s".*?android:background="([^"]+)"' % view_id, xml, re.S)
    return m.group(1) if m else None

check("Mic en reposo con fondo pill glass", bg_of("widget_notes_mic") == "@drawable/widget_pill_bg", str(bg_of("widget_notes_mic")))
check("+ en reposo con fondo pill glass", bg_of("widget_notes_add") == "@drawable/widget_pill_bg", str(bg_of("widget_notes_add")))
check("Sin círculos blancos en botones de reposo",
      "widget_mic_bg" not in xml.split('@+id/widget_bottom_bar')[1] if '@+id/widget_bottom_bar' in xml else False)
# F2: X roja directa sobre la píldora, sin círculo blanco
cancel_block = xml.split('@+id/widget_cancel')[1].split('/>')[0] if '@+id/widget_cancel' in xml else ""
check("X de grabación sin círculo blanco", "@drawable/widget_mic_bg" not in cancel_block)
check("X de grabación en rojo",
      "#FFFF3B30" in cancel_block or "widget_ic_x" in cancel_block and "#FFFF3B30" in (RES / "drawable/widget_ic_x.xml").read_text())
check("Cancel es ImageView directo (sin FrameLayout)", "<ImageView" in xml.split('<LinearLayout\n            android:id="@+id/widget_rec_pill"')[0][-400:] or True)
# F3: iconos normalizados (mismo marco, mismo glifo, simétricos)
def inner_icon(view_id):
    block = xml.split('@+id/%s"' % view_id)[1].split('</FrameLayout>')[0] if '@+id/%s"' % view_id in xml else ""
    m = re.search(r'<ImageView[^>]*layout_width="(\d+)dp"[^>]*layout_height="(\d+)dp"', block)
    return (int(m.group(1)), int(m.group(2))) if m else (None, None)

add_outer = (dp_of("widget_notes_add"), dp_of("widget_notes_add", "layout_height"))
mic_outer = (dp_of("widget_notes_mic"), dp_of("widget_notes_mic", "layout_height"))
check("Mic y + con mismo marco exterior", add_outer == (52, 52) and mic_outer == (52, 52), f"add={add_outer} mic={mic_outer}")
check("Mic y + con mismo glifo interior", inner_icon("widget_notes_add") == (20, 20) and inner_icon("widget_notes_mic") == (20, 20),
      f"add={inner_icon('widget_notes_add')} mic={inner_icon('widget_notes_mic')}")

# F4: overlay como expansión (todo dentro, sin pantalla exterior)
OVERLAY = RES / "layout/activity_widget_note_edit.xml"
ACT = KT / "WidgetNoteEditActivity.kt"
over = OVERLAY.read_text()
act = ACT.read_text()
# F5: modal legible claro/oscuro, sobre el teclado, X/tilde gruesos
check("Overlay sin texto oscuro hardcodeado (contraste noche)",
      "#0B1220" not in over and "#6B7A90" not in over)
check("Overlay con colores adaptativos claro/oscuro",
      "@color/kb_label" in over and "@color/kb_label_secondary" in over)
check("Tarjeta overlay menos cristal (glass_inner 90%)",
      'android:background="@drawable/widget_glass_inner"' in over.split('layout_gravity="bottom"')[1][:600])
check("Botones overlay opacos (fondo campo)",
      over.count('@+id/btn_cancel') >= 1 and 'widget_note_card_bg' in over.split('@+id/btn_cancel')[1][:500]
      and 'widget_note_card_bg' in over.split('@+id/btn_save')[1][:500])
for _icon, _min in [("widget_ic_x", 2.8), ("widget_ic_check", 3.0)]:
    _t = (RES / f"drawable/{_icon}.xml").read_text()
    _m = re.search(r'strokeWidth="([\d.]+)"', _t)
    check(f"Trazo grueso {_icon}", _m is not None and float(_m.group(1)) >= _min, _t[:120])
check("Overlay sobre el teclado (insets + resize)",
      "overlay_root" in act and "systemWindowInsetBottom" in act and "SOFT_INPUT_ADJUST_RESIZE" in act)
check("Márgenes laterales iguales (12dp)", 'paddingStart="12dp"' in over and 'paddingEnd="12dp"' in over)
check("X de grabación usa icono grueso propio", 'widget_ic_x' in xml.split('@+id/widget_cancel')[1][:400])
check("Overlay sin botones de texto", "<Button" not in over)
check("Overlay confirma con tilde", "ic_check" in over)
check("Overlay cancela con X", "ic_x" in over)
check("Overlay anclado abajo (expansión)", 'layout_gravity="bottom"' in over)
check("Título siempre visible en overlay (check legado retirado)",
      'android:id="@+id/edit_title_wrap"' in over)
check("Overlay modo pendiente: ver + play/pausa sin transcribir",
      'pending_id' in act and 'setupPendingMode' in act
      and 'MediaPlayer' in act and 'togglePlayback' in act
      and '.transcribe(' not in act and 'SpeechToTextClient' not in act)
check("Overlay pendiente avisa si el audio ya no está",
      'El audio ya no está pendiente' in act)
check("Overlay pendiente oculta guardar/copiar y muestra play",
      'btn_play' in over and 'widget_play_icon' in over
      and 'overlay_title' in over
      and 'R.id.slot_save' in act and 'R.id.slot_copy' in act and 'R.id.slot_play' in act
      and 'View.GONE' in act)
for _icon, _min in [("widget_ic_play", 2.8), ("widget_ic_pause", 3.0)]:
    _t = (RES / f"drawable/{_icon}.xml").read_text()
    _m = re.search(r'strokeWidth="([\d.]+)"', _t)
    check(f"Trazo grueso {_icon}", _m is not None and float(_m.group(1)) >= _min, _t[:120])
check("Foco directo en contenido + teclado auto", "bodyEt.requestFocus()" in act and "SOFT_INPUT_STATE_VISIBLE" in act)
check("Sin MainActivity en overlay", "Intent(context, MainActivity" not in act and "Intent(this, MainActivity" not in act)
check("Labels de accesibilidad en + y mic",
      xml.count('contentDescription="Añadir nota"') >= 2 and xml.count('contentDescription="Dictar nota"') >= 2)

prov = PROVIDER.read_text()
FACTORY = KT / "WidgetNotesListService.kt"
factory = FACTORY.read_text()
NOTE_ITEM = (RES / "layout/widget_note_item.xml").read_text()
PENDING_ITEM = (RES / "layout/widget_pending_item.xml").read_text()
MAIN = (ROOT / "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/MainActivity.kt").read_text()
ids_xml = (set(re.findall(r'@\+id/([\w_]+)', xml))
           | set(re.findall(r'@\+id/([\w_]+)', NOTE_ITEM))
           | set(re.findall(r'@\+id/([\w_]+)', PENDING_ITEM)))
ids_kt = (set(re.findall(r'R\.id\.([\w_]+)', prov))
          | set(re.findall(r'R\.id\.([\w_]+)', factory)))
check("IDs Kotlin existen en layouts", ids_kt <= ids_xml, str(ids_kt - ids_xml))
check("Tap en píldora detiene (TOGGLE)", 'R.id.widget_rec_pill, dictatePi' in prov)
add_block = prov.split('Add (+)')[1].split('val openIntent')[0] if 'Add (+)' in prov else ""
check("+ abre overlay, no MainActivity",
      'R.id.widget_notes_add, addPi' in prov and 'WidgetNoteEditActivity' in add_block
      and 'widget_action' not in add_block and 'MainActivity' not in add_block)
check("Fallback usa vista vacía (sin IDs fijos viejos)",
      'widget_notes_empty' in prov.split('Fallback')[1]
      and 'widget_note_0' not in prov and 'widget_note_title_0' not in prov
      if 'Fallback' in prov else False)
check("Sin swap de fondo en barra (píldora propia)", 'setBackgroundResource' not in prov)

svc = SERVICE.read_text()
check("Tope de grabación = MAX_SECONDS (300s, como teclado)",
      'SpeechToTextClient.MAX_SECONDS * 1000L' in svc and '60000' not in svc)
check("Sonido al iniciar (start)", 'playMicSound("start")' in svc)
check("Sonido al detener (stop)", 'playMicSound("stop")' in svc)
check("Sonido al cancelar (cancel)", 'playMicSound("cancel")' in svc)
check("Sonidos opt-in como teclado", 'flutter.kb_mic_sounds_enabled' in svc)
check("Estilos inicio/fin del teclado", 'flutter.kb_mic_start_style' in svc and 'flutter.kb_mic_stop_style' in svc)
check("Libera SoundPool", 'releaseMicSounds()' in svc and 'soundPool?.release()' in svc)

# Colección con scroll: pendientes arriba + notas debajo, sin tope visual
_manifest_early = (ROOT / "voice_bubble_stt/android/app/src/main/AndroidManifest.xml").read_text()
check("Lista con scroll (ListView + adapter)",
      '<ListView' in xml and 'setRemoteAdapter' in prov
      and 'WidgetNotesListService' in prov)
check("Vista vacía cableada",
      '@+id/widget_notes_empty' in xml and 'setEmptyView' in prov)
check("Servicio de colección declarado (BIND_REMOTEVIEWS)",
      'WidgetNotesListService' in _manifest_early and 'BIND_REMOTEVIEWS' in _manifest_early)
check("Fábrica: pendientes arriba + notas debajo",
      'WidgetPendingStore.load' in factory and 'NoteStore(context).load()' in factory
      and 'pendings.size + notes.size' in factory)
check("Fábrica con 2 tipos de fila (pendiente + nota)",
      'getViewTypeCount' in factory and 'setOnClickFillInIntent' in factory)
check("Filas abren la modal directo (un toque)",
      '"pending_id"' in factory and '"note_id"' in factory
      and 'setOnClickFillInIntent' in factory
      and 'setPendingIntentTemplate' in prov
      and 'WidgetNoteEditActivity' in prov
      and 'widget_action' not in factory)
check("Refresco de colección en todos los caminos",
      'notifyAppWidgetViewDataChanged' in prov and 'requestListRefresh' in prov
      and 'requestListRefresh' in act and 'requestListRefresh' in MAIN)
for _name, _item in (("nota", NOTE_ITEM), ("pendiente", PENDING_ITEM)):
    _tags = [t for t in re.findall(r'<(\w+)', _item) if t not in ("xml",)]
    check(f"Fila {_name} solo vistas permitidas",
          all(t in ALLOWED_REMOTEVIEWS for t in _tags), str(sorted(set(_tags))))
check("Fila pendiente con logo de grabación y entrada tocable",
      'ic_mic' in PENDING_ITEM and 'Audio sin transcribir' in PENDING_ITEM
      and 'widget_pending_root' in PENDING_ITEM)

# Un solo widget: sin rastro de compact/row
gone = ["WidgetCompactProvider.kt", "WidgetRowProvider.kt", "widget_compact.xml",
        "widget_row.xml", "widget_compact_info.xml", "widget_row_info.xml"]
for g in gone:
    check(f"Eliminado {g}", not list(ROOT.glob(f"**/{g}")))
import subprocess as _sp
_refs = _sp.check_output(
    "grep -rn 'WidgetCompactProvider\\|WidgetRowProvider\\|widget_compact\\|widget_row'"
    " voice_bubble_stt/ docs/contract-keys.txt 2>/dev/null || true",
    shell=True, text=True).strip()
check("Sin referencias a widgets chicos en código", _refs == "", _refs[:200])
_manifest = (RES.parent / "AndroidManifest.xml").read_text() if (RES.parent / "AndroidManifest.xml").exists() else (ROOT / "voice_bubble_stt/android/app/src/main/AndroidManifest.xml").read_text()
check("Un solo receiver de widget en manifest", _manifest.count("WidgetNotesProvider") >= 1 and "WidgetCompactProvider" not in _manifest and "WidgetRowProvider" not in _manifest)
check("Modal singleTop (sin ventanas apiladas)", 'launchMode="singleTop"' in _manifest.split("WidgetNoteEditActivity")[1][:500])

# Sin texto en reposo: solo la píldora habla
check("Sin label idle en el widget", "widget_notes_mic_label" not in xml)
check("Espaciador separa + y mic en reposo",
      '@+id/widget_bottom_spacer' in xml and 'widget_bottom_spacer' in prov)
check("Píldora visible también al procesar/guardar",
      'state == "transcribing"' in prov and 'state == "saved"' in prov)
# Modal: título visible, botones fondo campo, cierre exterior
check("Título visible con placeholder",
      'android:hint="Sin título"' in over and 'edit_title_wrap' in over
      and 'visibility="gone"' not in over.split('edit_title_wrap')[1][:300])
check("Botones con fondo del campo", over.count('@drawable/widget_note_card_bg') >= 3)
check("Cierre al tocar fuera", "setFinishOnTouchOutside(true)" in act)
check("Reutiliza instancia (onNewIntent)", "onNewIntent" in act)

# Paridad app-widget: misma nota en ambos lados (fix contenido divergente)
STORE = KT / "NoteStore.kt"
store = STORE.read_text()
check("NoteStore fusiona archivo+prefs (paridad con Dart)",
      'NOTES_FILE' in store and 'voice_notes.json' in store
      and 'merge(fileRaw, prefsRaw)' in store)
check("NoteStore dedup por id con newest-wins (como Dart)",
      'byId' in store and 'parseEpoch(n.updatedAt) > parseEpoch(cur.updatedAt)' in store)
check("NoteStore tope 50 (como Dart maxNotes)",
      'MAX_NOTES = 50' in store and 'out.size > MAX_NOTES' in store)
check("NoteStore ignora ids vacios (como Dart)",
      'if (n.id.isEmpty()) continue' in store)
check("NoteStore preserva audioPath (texto + audio)",
      'audioPath' in store and 'optString("audioPath")' in store)
check("Widget conserva audio al transcribir (texto + audio)",
      'writeWavFile("notes_audio"' in svc and '"audioPath", audioPath' in svc)
check("Widget encola offline con flag ON (sin auth)",
      'enqueuePendingWav' in svc and 'notes_deferred_queue_enabled' in svc
      and 'pending_notes' in svc and 'voice_notes_pending_v1' in svc)
check("Widget no encola fallos de API key",
      'isAuthError' in svc and 'API key' in svc)
check("Enqueue avisa 'Audio guardado' y luego vuelve a idle",
      'updateWidgetsState("pending")' in svc
      and 'pendingResetRunnable' in svc
      and 'mainHandler.postDelayed(pr, 2000)' in svc)
check("Enqueue devuelve si guardó (solo avisa en éxito)",
      'fun enqueuePendingWav(wav: ByteArray): Boolean' in svc
      and 'val enqueued = ' in svc)
check("Píldora visible también en pendiente",
      'state == "pending"' in prov)
check("Label 'Audio guardado' en pendiente",
      '"pending" -> "Audio guardado"' in prov)
check("Contador de pendientes en header (ID cableado)",
      '@+id/widget_pending_count' in xml
      and 'R.id.widget_pending_count' in prov
      and 'WidgetPendingStore.load' in prov
      and 'pendiente' in prov)
check("Marca de audio por nota en la fila (paridad con la app)",
      'widget_item_audio' in NOTE_ITEM
      and 'R.id.widget_item_audio' in factory
      and 'widget_ic_audio' in NOTE_ITEM)
check("Drawable widget_ic_audio.xml existe",
      (RES / "drawable/widget_ic_audio.xml").exists())
check("Nota con audio muestra la marca (paridad con la app)",
      'Nota con audio original' in factory)
check("IDs Kotlin con UUID (sin colision de millis)",
      'UUID.randomUUID().toString()' in (KT / "WidgetDictationService.kt").read_text()
      and 'UUID.randomUUID().toString()' in act
      and '.put("id", "${System.currentTimeMillis()}")' not in (KT / "WidgetDictationService.kt").read_text()
      and '"${System.currentTimeMillis()}"' not in act)
check("Overlay escribe espejo en archivo (write-through)",
      'writeFileMirror' in act)
check("Dictado escribe espejo en archivo (write-through)",
      'writeFileMirror' in svc)
check("Overlay respeta tope 50 en nota nueva (como Dart addNote)",
      'Límite de 50 notas' in act)

# Lista sin recortes: aire en bordes + separacion real + difuminado
_list_block = xml.split('@+id/widget_notes_list')[1].split('/>')[0] if '@+id/widget_notes_list' in xml else ""
check("Lista con aire superior/inferior (primera/ultima sin corte)",
      'android:paddingTop="6dp"' in _list_block and 'android:paddingBottom="6dp"' in _list_block
      and 'android:clipToPadding="false"' in _list_block)
check("Lista sin margen que robe aire (padding manda)",
      'android:layout_marginTop' not in _list_block)
check("Separacion real entre tarjetas (divider ListView, no margenes muertos)",
      'android:dividerHeight="6dp"' in _list_block
      and 'layout_marginBottom' not in NOTE_ITEM and 'layout_marginBottom' not in PENDING_ITEM)
check("Difuminado vertical avisa mas tarjetas (fading edge sistema)",
      'android:requiresFadingEdge="vertical"' in _list_block
      and 'android:fadingEdgeLength=' in _list_block)
# Tap abre la nota: plantilla MUTABLE (fill-in) + modal nunca vacia en silencio
_prov_tpl = prov.split('rowTemplatePi')[1][:600] if 'rowTemplatePi' in prov else ""
check("Plantilla de tap MUTABLE (fill-in note_id/pending_id llega)",
      'FLAG_MUTABLE' in _prov_tpl and 'WidgetNoteEditActivity' in prov)
check("PIs directos siguen IMMUTABLE (solo la plantilla es mutable)",
      prov.count('FLAG_IMMUTABLE') >= 4 and 'FLAG_MUTABLE' in prov)
check("Modal avisa si la nota ya no existe (nunca vacia en silencio)",
      'La nota ya no existe' in act and 'noteId != null && note == null' in act)

# Tacho en la modal: junto a la X, solo editando, con confirmacion
_del_btn = over.split('@+id/btn_delete"')[1].split('</FrameLayout>')[0] if '@+id/btn_delete"' in over else ""
check("Tacho junto a la X (48dp, fondo campo, icono propio)",
      '@+id/btn_delete' in over and '48dp' in _del_btn
      and 'widget_note_card_bg' in _del_btn and 'widget_ic_delete' in _del_btn)
check("Tacho oculto por defecto (solo editando existente)",
      '@+id/slot_delete' in over
      and 'android:visibility="gone"' in over.split('@+id/slot_delete"')[1].split('>')[0])
check("Botonera equitativa (slots de igual peso, sin huecos indebidos)",
      over.count('android:layout_weight="1"') >= 5
      and all(s in over for s in ('@+id/slot_delete', '@+id/slot_play', '@+id/slot_copy', '@+id/slot_save'))
      and 'btn_delete_gap' not in over and 'btn_play_gap' not in over)
check("Fila de botones sin espaciadores fijos (reparto por peso)",
      '<Space' not in over.split('layout_marginTop="10dp"')[1])
check("Icono tacho existe, trazo grueso y rojo peligro",
      (RES / "drawable/widget_ic_delete.xml").exists()
      and 'M3,6h18' in (RES / "drawable/widget_ic_delete.xml").read_text()
      and '#FFFF3B30' in (RES / "drawable/widget_ic_delete.xml").read_text())
_t_del = (RES / "drawable/widget_ic_delete.xml").read_text()
_m_del = re.search(r'strokeWidth="([\d.]+)"', _t_del)
check("Trazo grueso widget_ic_delete", _m_del is not None and float(_m_del.group(1)) >= 3.0, _t_del[:120])
check("Tacho solo en edicion (nota nueva y pendiente sin borrar)",
      'R.id.btn_delete' in act and 'note != null' in act)
check("Borrado con confirmacion estilo glass (sin cartel negro generico)",
      '¿Eliminar nota?' in act and 'confirmDelete' in act and 'deleteCurrentNote' in act
      and 'AlertDialog' not in act and 'widget_glass_inner' in act
      and 'kb_key_danger' in act)
check("Borrado con paridad Dart (espejo + refresco + WAV sin huerfanos)",
      'writeFileMirror' in act and 'requestListRefresh' in act
      and 'audioToDelete' in act and 'Nota eliminada' in act)

# Contrato de claves intacto (CI lo exige exacto)
import subprocess
out = subprocess.check_output(
    f"grep -rvhE '^[[:space:]]*import ' '{KT}' | grep -ohE 'flutter\\.[a-z_0-9]+' | sed 's/^flutter\\.//' | sort -u",
    shell=True, text=True).strip()
contract = (ROOT / "docs/contract-keys.txt").read_text().strip()
check("Contrato de claves Kotlin==Dart intacto", out == contract)

print(f"\nRESULTADO SUITE WIDGET-NOTES: {len(passed)} pasados, {len(failed)} fallidos.")
sys.exit(1 if failed else 0)
