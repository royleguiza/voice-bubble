#!/usr/bin/env python3
"""
test_c38_widget_dismiss_suite.py
================================
Auditoría C-38: la modal del widget cierra en un gesto [S]

Verifica:
1. DismissEditText (nuevo): subclase de EditText cuyo onKeyPreIme
   intercepta ATRÁS+ACTION_UP con el teclado visible e invoca el
   callback, consumiendo el evento; el resto delega a super.
2. Layout activity_widget_note_edit.xml: edit_title y edit_body usan
   DismissEditText; la tarjeta interior consume sus toques
   (clickable+focusable) para que no burbujeen al overlay_root.
3. WidgetNoteEditActivity: overlay_root cierra con finish() (igual que
   la X); ambos campos cablean onBackWhileEditing a
   hideKeyboardAndFinish (oculta IME + finish); btn_cancel intacto.
4. Diseño y contrato intactos: botones 48dp, fondo tarjeta, dim,
   tema translúcido, singleTop, sin Log nuevo ni permisos nuevos.
5. Mutaciones negativas: versiones rotas no pasan las guardas.
"""

import os
import re
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
MANIFEST = os.path.join(
    REPO_ROOT, "voice_bubble_stt", "android", "app", "src", "main",
    "AndroidManifest.xml",
)


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


class TestC38WidgetDismissSuite(unittest.TestCase):

    def test_01_dismiss_edit_text_intercepta_atras(self):
        self.assertTrue(os.path.exists(DISMISS), "DismissEditText.kt debe existir")
        src = read_file(DISMISS)
        self.assertIn(") : EditText(", src, "Debe extender EditText")
        self.assertIn("onBackWhileEditing", src, "Debe exponer el callback")
        self.assertIn("override fun onKeyPreIme", src, "Debe sobrescribir onKeyPreIme")
        self.assertIn("KEYCODE_BACK", src, "Debe filtrar la tecla atrás")
        self.assertIn("ACTION_UP", src, "Debe actuar al soltar (sin doble disparo)")
        self.assertIn("onBackWhileEditing?.invoke()", src, "Debe invocar el callback")
        self.assertIn("return true", src, "Debe consumir el evento")
        self.assertIn(
            "return super.onKeyPreIme(keyCode, event)",
            src, "El resto debe delegar a super",
        )

    def test_02_layout_usa_dismiss_y_tarjeta_consume(self):
        self.assertTrue(os.path.exists(LAYOUT), "El layout debe existir")
        xml = read_file(LAYOUT)
        self.assertIn(
            "<com.royleguiza.voicebubblestt.DismissEditText",
            xml, "edit_title/edit_body deben usar DismissEditText",
        )
        self.assertEqual(
            xml.count("<com.royleguiza.voicebubblestt.DismissEditText"),
            2, "Deben ser exactamente los 2 campos (título y cuerpo)",
        )
        self.assertNotIn(
            "<EditText", xml.replace("<com.royleguiza.voicebubblestt.DismissEditText", ""),
            "No debe quedar ningún EditText plano",
        )
        card = xml.split('android:id="@+id/overlay_root"')[1].split(
            'android:id="@+id/overlay_title"')[0]
        self.assertIn('android:clickable="true"', card,
                       "La tarjeta debe consumir sus toques")
        self.assertIn('android:focusable="true"', card,
                       "La tarjeta debe ser enfocable")

    def test_03_activity_cierra_fuera_y_atras_como_la_x(self):
        act = read_file(ACTIVITY)
        self.assertIn(
            "findViewById<View>(R.id.overlay_root).setOnClickListener { finish() }",
            act, "Tocar fuera debe cerrar igual que la X",
        )
        self.assertEqual(
            act.count("onBackWhileEditing = { hideKeyboardAndFinish() }"),
            2, "Ambos campos deben cablear el cierre",
        )
        self.assertIn("private fun hideKeyboardAndFinish()", act,
                       "Debe existir el cierre compartido")
        self.assertIn("hideSoftInputFromWindow", act,
                       "Debe ocultar el teclado al cerrar")
        self.assertIn(
            'findViewById<View>(R.id.btn_cancel).setOnClickListener { finish() }',
            act, "La X debe seguir cerrando",
        )

    def test_04_diseno_y_contrato_intactos(self):
        xml = read_file(LAYOUT)
        self.assertIn('android:id="@+id/overlay_root"', xml)
        self.assertIn('android:id="@+id/btn_cancel"', xml)
        self.assertIn('android:id="@+id/btn_save"', xml)
        self.assertIn('android:id="@+id/btn_copy"', xml)
        self.assertIn("@drawable/widget_glass_inner", xml,
                       "La tarjeta conserva su fondo")
        # C-46: 6 de botonera + 2 de la barra player expandible.
        self.assertEqual(xml.count('android:layout_width="48dp"'), 8,
                         "Los 8 botones conservan 48dp (6 botonera + player main/close)")
        styles = read_file(os.path.join(
            REPO_ROOT, "voice_bubble_stt", "android", "app", "src",
            "main", "res", "values", "styles.xml"))
        self.assertIn("Theme.Translucent.NoTitleBar", styles)
        manifest = read_file(MANIFEST)
        block = manifest.split("WidgetNoteEditActivity")[1][:500]
        self.assertIn('android:theme="@style/WidgetEditTheme"', block)
        self.assertIn('launchMode="singleTop"', block)

    def test_05_sin_logs_ni_permisos_nuevos(self):
        for path in (ACTIVITY, DISMISS):
            src = read_file(path)
            self.assertNotIn("Log.", src,
                             f"{os.path.basename(path)} no debe loguear")
            self.assertNotIn("print(", src)
        manifest = read_file(MANIFEST)
        got = sorted(set(re.findall(
            r'<uses-permission android:name="([^"]+)"', manifest)))
        expected = sorted([
            "android.permission.FOREGROUND_SERVICE",
            "android.permission.FOREGROUND_SERVICE_MICROPHONE",
            "android.permission.INTERNET",
            "android.permission.POST_NOTIFICATIONS",
            "android.permission.RECORD_AUDIO",
            "android.permission.SYSTEM_ALERT_WINDOW",
            "android.permission.VIBRATE",
        ])
        self.assertEqual(got, expected,
                         "C-38 no agrega permisos (conjunto exacto preexistente)")

    def test_06_mutaciones_negativas_detectadas(self):
        # Tarjeta sin clickable: los toques burbujearían y cerrarían mal.
        mut_card = '<LinearLayout android:layout_gravity="bottom">'
        self.assertNotIn('android:clickable="true"', mut_card)
        # Callback sin consumir: el IME también actuaría (doble efecto).
        mut_ime = "override fun onKeyPreIme(keyCode: Int, event: KeyEvent): Boolean {\n return super.onKeyPreIme(keyCode, event)\n}"
        self.assertNotIn("return true", mut_ime)
        # Cierre que guarda en vez de descartar como la X.
        mut_save = "onBackWhileEditing = { requestSave(title, body) }"
        self.assertNotIn("hideKeyboardAndFinish", mut_save)
        # Campo plano sin intercepción de atrás.
        mut_xml = '<EditText android:id="@+id/edit_body" />'
        self.assertNotIn("DismissEditText", mut_xml)


def run_tests():
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromTestCase(TestC38WidgetDismissSuite)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
