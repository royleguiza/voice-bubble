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
check("Labels de accesibilidad en + y mic",
      xml.count('contentDescription="Añadir nota"') >= 2 and xml.count('contentDescription="Dictar nota"') >= 2)

prov = PROVIDER.read_text()
ids_xml = set(re.findall(r'@\+id/([\w_]+)', xml))
ids_kt = set(re.findall(r'R\.id\.([\w_]+)', prov))
check("IDs Kotlin existen en layout", ids_kt <= ids_xml, str(ids_kt - ids_xml))
check("Tap en píldora detiene (TOGGLE)", 'R.id.widget_rec_pill, dictatePi' in prov)
add_block = prov.split('Add (+)')[1].split('val openIntent')[0] if 'Add (+)' in prov else ""
check("+ abre overlay, no MainActivity",
      'R.id.widget_notes_add, addPi' in prov and 'WidgetNoteEditActivity' in add_block
      and 'widget_action' not in add_block and 'MainActivity' not in add_block)
check("Fallback usa IDs nuevos", 'widget_rec_pill' in prov.split('Fallback')[1] if 'Fallback' in prov else False)
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

# Contrato de claves intacto (CI lo exige exacto)
import subprocess
out = subprocess.check_output(
    f"grep -rvhE '^[[:space:]]*import ' '{KT}' | grep -ohE 'flutter\\.[a-z_0-9]+' | sed 's/^flutter\\.//' | sort -u",
    shell=True, text=True).strip()
contract = (ROOT / "docs/contract-keys.txt").read_text().strip()
check("Contrato de claves Kotlin==Dart intacto", out == contract)

print(f"\nRESULTADO SUITE WIDGET-NOTES: {len(passed)} pasados, {len(failed)} fallidos.")
sys.exit(1 if failed else 0)
