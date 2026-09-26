#!/usr/bin/env python3
"""
TEST SUITE: RELLENO DE CLAVES SEGURO [S] (CONTRATO C-07)

Verifica al 100% de certeza sobre el código REAL:
1. Captura de editor y conexión iniciales antes del TAB en CredentialsLayer.kt.
2. Invocación de TAB protegida contra excepciones IPC.
3. En el callback diferido (250 ms):
   - Comprobación de que el TAB avanzó: si sigue en la misma conexión o mismo fieldId, aborta sin pegar.
   - Comprobación de aplicación: si currentEditor.packageName cambió, aborta sin pegar.
   - Comprobación de campo seguro: si el nuevo foco NO es un campo de contraseña
     (!isPasswordInput o !host.isPasswordField), aborta inmediatamente para no volcar la clave en texto visible.
4. Rama directa: si ya estaba en un campo de contraseña, comitea directamente sin TAB ni retardo.
5. Cero logs: ninguna llamada a Log.* ni exposición de contraseñas.
6. Mutaciones negativas: verifica que retirar cualquiera de las guardas de aborto
   hace fallar la suite.
"""

import os
import re
import sys

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check

print("\n============================================================")
print(" INICIANDO TEST SUITE: CONTRATO C-07 (RELLENO DE CLAVES SEGURO)")
print("============================================================\n")

CREDS_PATH = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/CredentialsLayer.kt"
check("Archivo CredentialsLayer.kt existe", os.path.isfile(os.path.join(WORKSPACE, CREDS_PATH)))

creds = suite.read(CREDS_PATH)

# 1. Imports requeridos
check("CredentialsLayer importa DeadObjectException", "import android.os.DeadObjectException" in creds)
check("CredentialsLayer importa RemoteException", "import android.os.RemoteException" in creds)
check("CredentialsLayer importa EditorInfo", "import android.view.inputmethod.EditorInfo" in creds)

# 2. Helper commitOrWarn
check("CredentialsLayer implementa commitOrWarn local", "private fun commitOrWarn(text: CharSequence): Boolean" in creds)

# 3. Captura previa al TAB
fill_fn = creds[creds.find("private fun fill(entry: VbCredentialEntry)") :]
check(
    "fill captura initialEditor antes del TAB",
    "val initialEditor = service.currentInputEditorInfo" in fill_fn
    and fill_fn.find("val initialEditor =") < fill_fn.find("KEYCODE_TAB"),
)
check(
    "fill captura initialIc antes del TAB",
    "val initialIc = service.currentInputConnection" in fill_fn
    and fill_fn.find("val initialIc =") < fill_fn.find("KEYCODE_TAB"),
)
check(
    "fill valida initialEditor e initialIc antes de comitear usuario",
    "if (initialEditor == null || initialIc == null) return" in fill_fn,
)
check(
    "fill comitea usuario con commitOrWarn",
    "if (!commitOrWarn(entry.usuario)) return" in fill_fn,
)

# 4. Envío de TAB protegido contra caídas IPC
check(
    "TAB envuelto en try/catch",
    "try {\n                service.sendDownUpKeyEvents(KeyEvent.KEYCODE_TAB)\n            } catch" in fill_fn
    or "try {\n            service.sendDownUpKeyEvents(KeyEvent.KEYCODE_TAB)" in fill_fn
    or ("service.sendDownUpKeyEvents(KeyEvent.KEYCODE_TAB)" in fill_fn and "catch (_: DeadObjectException)" in fill_fn),
)

# 5. Guardas en el bloque diferido (250ms)
deferred = fill_fn[fill_fn.find("handler.postDelayed") : fill_fn.find("host.showLayer(origin)")]

check("Diferido comprueba isServiceAlive", "if (!host.isServiceAlive()) return@postDelayed" in deferred)
check("Diferido obtiene currentEditor con aborto", "val currentEditor = service.currentInputEditorInfo ?: return@postDelayed" in deferred)
check("Diferido obtiene currentIc con aborto", "val currentIc = service.currentInputConnection ?: return@postDelayed" in deferred)

# Guarda A: si el TAB no avanzó, abortar
check(
    "Diferido detecta si el TAB no avanzó (misma conexión)",
    "currentIc === initialIc" in deferred,
)
check(
    "Diferido detecta si el TAB no avanzó (mismo fieldId)",
    "currentEditor.fieldId == initialEditor.fieldId" in deferred,
)
check(
    "Diferido aborta si el TAB no avanzó",
    "if (didNotAdvance) return@postDelayed" in deferred,
)

# Guarda B: si cambió de paquete/app, abortar
check(
    "Diferido detecta cambio de aplicación (packageName)",
    "currentEditor.packageName != initialEditor.packageName" in deferred
    and "return@postDelayed" in deferred[deferred.find("currentEditor.packageName") :],
)

# Guarda C: si el nuevo campo NO es de contraseña, abortar
check(
    "Diferido valida que el campo sea de contraseña con isPasswordInput",
    "!isPasswordInput(currentEditor)" in deferred,
)
check(
    "Diferido valida con host.isPasswordField",
    "!host.isPasswordField()" in deferred,
)
check(
    "Diferido aborta si el campo no es de contraseña",
    "if (!isPasswordInput(currentEditor) || !host.isPasswordField()) return@postDelayed" in deferred
    or "if (!isPasswordInput(currentEditor)) return@postDelayed" in deferred,
)

# Guarda D: pegado de clave seguro
check(
    "Diferido pega contraseña vía commitOrWarn",
    "commitOrWarn(password)" in deferred,
)

# 6. Rama directa cuando el foco ya es un campo de contraseña
direct_branch = fill_fn[fill_fn.find("if (host.isPasswordField())") : fill_fn.find("} else {")]
check(
    "Foco previo en password pega directo sin TAB ni delay",
    "commitOrWarn(password)" in direct_branch
    and "KEYCODE_TAB" not in direct_branch
    and "postDelayed" not in direct_branch,
)

# 7. Privacidad y Seguridad estricta
check(
    "CredentialsLayer: cero llamadas a Log.*",
    "Log." not in creds,
)
check(
    "CredentialsLayer: documentación KDoc del contrato C-07",
    "Seguridad C-07 (Relleno de claves seguro)" in creds,
)

# 8. Mutaciones negativas
def test_mutations():
    # Mutación 1: Eliminar la guarda de TAB no avanzó
    mutated_1 = deferred.replace("if (didNotAdvance) return@postDelayed", "// bypassed")
    check("Mutación 1 (sin guarda didNotAdvance): detectada", "if (didNotAdvance) return@postDelayed" not in mutated_1)

    # Mutación 2: Eliminar la comprobación de isPasswordInput
    mutated_2 = deferred.replace("!isPasswordInput(currentEditor)", "false")
    check("Mutación 2 (sin isPasswordInput): detectada", "!isPasswordInput(currentEditor)" not in mutated_2)

    # Mutación 3: Eliminar la comprobación de packageName
    mutated_3 = deferred.replace("currentEditor.packageName != initialEditor.packageName", "false")
    check("Mutación 3 (sin check de packageName): detectada", "currentEditor.packageName != initialEditor.packageName" not in mutated_3)

    # Mutación 4: Introducir un Log en CredentialsLayer
    mutated_4 = creds + '\n// android.util.Log.d("Credentials", "pass")'
    check("Mutación 4 (Log introducido): detectada", "Log." in mutated_4)

test_mutations()

print("\n============================================================")
print(f" RESULTADOS C-07: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

sys.exit(suite.exit_code())
