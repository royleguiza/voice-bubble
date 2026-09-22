# Congelamiento de features (SPK-09) — fuente única

> La app ya no hace UNA cosa (README dice "solo transcripción"; realidad:
> teclado 3 capas + dictado 5 min + snippets + credenciales + clipboard
> multimodal + trackpad + burbuja modal + 6 tabs). Cada hito sumó sin quitar.
> Desde 2026-09-09 rige: **cero features nuevos** hasta re-auditoría ≥14/20.

## Regla de entrada/salida

Una tarjeta nueva solo entra si otra sale o si parte un god-object.
Archivo >500 líneas o >10 `fun` nuevos exige partir antes del próximo feature.

## Experimentales (flag OFF por defecto)

| Feature | Flag | Default | Dónde |
|---|---|---|---|
| Imágenes del portapapeles | `kb_clipboard_images_enabled` | OFF (texto primero) | Ajustes → Teclado → "Imágenes en portapapeles"; IME lo lee en `KeyboardPrefs` + gate en `ClipboardStore.addImageClip` |
| Cola diferida cloud Notas | `notes_deferred_queue_enabled` | OFF | Ajustes → General → "Guardar audio sin conexión"; `PendingNoteQueue` + hook en `NotesScreen`; plan `plan-notas-cola-nube.md` (tarjeta C1–C7 admitida por el dueño 2026-09-22) |
| Claves (password-manager) | — (sin flag: visible pero congelada) | Congelada, banner "Experimental" en UI | `CredentialsScreen` + `CredentialsLayer`; cero cambios fuera de fixes |

Claves no lleva flag de apagado porque su suite (`test_credentials_suite.py`)
exige sección visible; el congelamiento se expresa con banner + esta regla.
Si se le pone flag, la suite se actualiza el mismo día.

## Tabs: 6, con justificación medible (SPK-16)

Se mantienen Inicio / Burbuja / Teclado / Trackpad / Snippets / Claves porque
cada item mide ~50dp de alto (icono 22 + label + padding v6×2 ≥ 48dp) y entra
en 360dp (~56dp por tab con ellipsis). Fusionar Snippets+Claves en "Insertar"
queda como plan B si un dispositivo no llega a 48dp.

## Lo que sigue congelado

Autocorrector predictivo, temas, emojis, glide typing, portapapeles
multinivel, segundo motor Flutter en el teclado, dictado/snippets en
contraseñas, inyección con tercer teclado (bloqueada anti-Play-Protect).
Ver `AGENTS.md` §8.
