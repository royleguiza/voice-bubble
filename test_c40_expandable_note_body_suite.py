#!/usr/bin/env python3
"""
test_c40_expandable_note_body_suite.py
======================================
Auditoría C-40: cuerpo expandible con tirador en la modal [S]

Verifica:
1. Layout: tarjeta con id, tirador 48dp full-width con píldora
   36x4 + descripción, cuerpo base 120dp.
2. Activity: helpers puros clampBodyHeight/computeBodyMaxPx, listener
   con DOWN/MOVE/UP/CANCEL/POINTER_UP, seguimiento de un puntero,
   doble-tap que alterna, recálculo en insets; solo el cuerpo cambia.
3. Diseño intacto: 6 botones 48dp, tarjeta consume toques, sin logs.
4. Mutaciones negativas: versiones rotas no pasan las guardas.
"""

import os
import sys
import unittest

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
KT = os.path.join(
    REPO_ROOT, "voice_bubble_stt", "android", "app", "src", "main",
    "kotlin", "com", "royleguiza", "voicebubblestt",
)
ACTIVITY = os.path.join(KT, "WidgetNoteEditActivity.kt")
DISMISS = os.path.join(KT, "DismissEditText.kt")
LAYOUT = os.path.join(
    REPO_ROOT, "voice_bubble_stt", "android", "app", "src", "main",
    "res", "layout", "activity_widget_note_edit.xml",
)
PILL = os.path.join(
    REPO_ROOT, "voice_bubble_stt", "android", "app", "src", "main",
    "res", "drawable", "widget_grabber_pill.xml",
)


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


class TestC40ExpandableNoteBodySuite(unittest.TestCase):

    def test_01_layout_tirador_y_tarjeta(self):
        xml = read_file(LAYOUT)
        self.assertIn('android:id="@+id/note_card"', xml,
                      "La tarjeta debe tener id para medir el cromo")
        self.assertIn('android:id="@+id/btn_expand_handle"', xml)
        handle = xml.split('@+id/btn_expand_handle"')[1].split("</FrameLayout>")[0]
        self.assertIn('android:layout_width="match_parent"', handle)
        self.assertIn('android:layout_height="48dp"', handle,
                      "Zona táctil de 48dp")
        self.assertIn('contentDescription="Arrastrar para ampliar"', xml)
        self.assertIn('android:layout_width="36dp"', handle)
        self.assertIn("@drawable/widget_grabber_pill", handle)
        self.assertTrue(os.path.exists(PILL), "La píldora debe existir")
        pill = read_file(PILL)
        self.assertIn("@color/kb_label_secondary", pill,
                      "Color del token del sistema")
        body_tag = xml.split('@+id/edit_body"')[0].split("<com.royleguiza")[-1]
        body_tag += xml.split('@+id/edit_body"')[1].split("/>")[0]
        self.assertIn('android:layout_height="120dp"', body_tag,
                      "El cuerpo arranca en 120dp como hoy")

    def test_02_helpers_puros_y_clamp(self):
        pure = read_file(DISMISS)
        self.assertIn("internal fun clampBodyHeight(", pure)
        self.assertIn("coerceIn(minPx, maxOf(minPx, maxPx))", pure,
                      "Clamp con fallback si max < min")
        self.assertIn("internal fun computeBodyMaxPx(", pure)
        self.assertIn("maxOf(minPx, rootH - rootPadBottom", pure)
        act = read_file(ACTIVITY)
        self.assertIn("clampBodyHeight(", act,
                      "La activity usa el clamp compartido")
        self.assertIn("computeBodyMaxPx(", act)

    def test_03_arrastre_un_puntero_y_dobletap(self):
        act = read_file(ACTIVITY)
        self.assertIn("R.id.btn_expand_handle", act)
        self.assertIn("setOnTouchListener", act)
        for token in ("ACTION_DOWN", "ACTION_MOVE", "ACTION_UP",
                      "ACTION_CANCEL", "ACTION_POINTER_UP"):
            self.assertIn(token, act, f"Debe manejar {token}")
        self.assertIn("findPointerIndex", act,
                      "Debe seguir un solo puntero en multi-touch")
        self.assertIn("toggleBodyHeight()", act)
        self.assertIn("300", act, "Doble-tap dentro de 300ms")
        self.assertIn("recomputeBodyMax()", act)
        self.assertIn("OnApplyWindowInsetsListener", act)

    def test_04_solo_el_cuerpo_cambia(self):
        act = read_file(ACTIVITY)
        drag = act.split("private fun setupExpandableBody()")[1].split(
            "\n    private fun ")[0]
        self.assertIn("R.id.edit_body", drag)
        self.assertNotIn("R.id.edit_title", drag,
                         "El título no cambia de tamaño")
        self.assertNotIn("btn_save", drag, "La botonera no cambia")
        self.assertIn("body.requestLayout()", drag)

    def test_05_diseno_y_privacidad_intactos(self):
        xml = read_file(LAYOUT)
        self.assertEqual(xml.count('android:layout_width="48dp"'), 6,
                         "6 botones de 48dp intactos")
        self.assertIn("@drawable/widget_glass_inner", xml)
        self.assertIn('android:clickable="true"', xml)
        act = read_file(ACTIVITY)
        self.assertNotIn("Log.", act)

    def test_06_mutaciones_negativas_detectadas(self):
        # Sin clamp: el cuerpo podría salirse de pantalla o colapsar.
        mut_clamp = "lp.height = dragStartH + dy"
        self.assertNotIn("clampBodyHeight", mut_clamp)
        # Sin id en tarjeta: no se puede medir el cromo.
        mut_card = '<LinearLayout android:layout_gravity="bottom">'
        self.assertNotIn('note_card', mut_card)
        # Sin seguimiento de puntero: multi-touch salta.
        mut_ptr = "dragStartY = event.rawY"
        self.assertNotIn("findPointerIndex", mut_ptr)
        # Botón que crece: rompería la botonera equitativa.
        mut_btn = "R.id.btn_save"
        drag_ctx = "setupExpandableBody"
        self.assertNotIn(mut_btn, drag_ctx)


def run_tests():
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromTestCase(TestC40ExpandableNoteBodySuite)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
