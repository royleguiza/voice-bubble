# CHECKLIST-TESTING.md — Verificación en dispositivo (dueño)

> **APK a usar**: `voice-bubble-debug-apk-r57` · Run [`32634338510`](https://github.com/royleguiza/voice-bubble/actions/runs/32634338510) (CI verde, 368 tests)
> **Cómo descargarlo**: GitHub → repo → pestaña **Actions** → run r57 (o el más reciente verde) → sección **Artifacts** → descargar y descomprimir el ZIP.
> **Estado**: v1.0.0 tagged. Todo lo automatizable ya pasó CI; ESTA lista es lo que solo puede validar el dueño en el teléfono físico.
> **Resultado**: verificación completa del dueño el 2026-08-23 con APK r57 — todos los ítems OK, sin incidencias.
> **Regla**: marcar cada casilla al verificarla. Si algo falla, registrar en "Incidencias encontradas" al final (con app, paso y síntoma) para fix-wave.

---

## 1. Heredadas de K2/K3 (pendientes históricas)

- [x] Termux: `ls`+TAB autocompleta; Ctrl+C corta; Ctrl+L limpia; Ctrl+[ = ESC; flechas navegan historial bash.
- [x] Acode: llaves/corchetes correctos; par auto-cerrado con toque largo.
- [x] Teclas terminales no rompen apps normales (Chrome ignora ESC/CTRL sin error).
- [x] Dictado es/en en Chrome, WhatsApp y Acode deja el texto exacto en el cursor.
- [x] Burbuja grabando → teclado avisa ocupado (y viceversa).
- [x] Campo de contraseña → micrófono invisible.

## 2. Cierre K4 — Snippets

- [x] Seeds visibles en la primera apertura de la capa ☰ del teclado (los 5: Codex, Gemini, Git commit, Git push, Supabase push).
- [x] Crear snippet en la app → aparece en el teclado al reabrir la capa, sin reiniciar nada (≤ 2 s).
- [x] Editar/borrar en la app se refleja igual en el teclado.
- [x] Insertar un snippet multilínea en Acode y en Termux funciona íntegro.
- [x] Toque largo en chip: Insertar / Copiar al portapapeles / Abrir app para editar funcionan.
- [x] Búsqueda filtra por nombre en tiempo real (con las letras QWERTY de la capa).
- [x] Modo búsqueda: campo iluminado captura teclas; ↵ sale del modo; ⌫ borra el query sin tocar el documento.
- [x] Corromper el JSON manualmente (editor de archivos) → teclado vivo con lista vacía, sin crash.
- [x] En un campo de contraseña NO aparece la tecla ☰.

## 3. Cierre K5 — Pulido

- [x] Tema correcto en claro/oscuro y al cambiar el modo del sistema en caliente (todas las capas, popups y menús).
- [x] Filas QWERTY de la capa snippets: teclear filtra en vivo; backspace borra el query; nada escribe en el documento destino.
- [x] Altura baja/media/alta desde Ajustes se aplica al reabrir el teclado; la barra de gestos no solapa en ninguno de los 3 perfiles.
- [x] Switch Vibración OFF elimina el haptic feedback del teclado.
- [x] Con idioma EN: avisos de dictado (sin conexión, API key, permiso, ocupado) salen en inglés.
- [x] Rotación a mitad de dictado cancela limpio (sin grabación fantasma ni crash).
- [x] Cambiar de campo/app mientras graba cancela el dictado.
- [x] Llamada entrante durante dictado: la grabación se cancela al perder audio focus.
- [x] Uso mixto de 15 minutos (dictado + código + snippets + Termux) sin crash ni ANR.

## 4. Cierre Hito 5 — Robustez e instalación

- [x] Icono adaptive visible en launcher (claro/oscuro) y splash de marca al arrancar.
- [x] Burbuja funciona con Android 14/15 (servicio en primer plano tipado micrófono; notificación visible mientras graba).
- [x] POST_NOTIFICATIONS se solicita la primera vez que inicias la burbuja en Android 13+.
- [x] Con micrófono denegado permanentemente, activar la burbuja NO crashea la app.
- [x] Grabación larga (~10 min) estable desde la burbuja.
- [x] Reintento tras fallo de red usa el MISMO audio sin regrabar (desconectar wifi a mitad: transcribir → falla → Reintentar con red restablecida).
- [x] Historial mantiene exactamente 20 elementos (dictar 25 veces seguidas → quedan las últimas 20).
- [x] Sin conexión: mensaje claro, sin envíos parciales. API key inválida: aviso claro sin reintentos infinitos.

## 5. Instalación limpia (opcional pero recomendado)

- [x] Desinstalar la versión previa → instalar r57 desde cero siguiendo `INSTALL.md` → activación burbuja + teclado sin pasos faltantes.
- [x] La guía de batería del fabricante (INSTALL.md §5) corresponde con los menús reales de tu teléfono.

---

## 6. Lote pulido UI v1.1 (nuevo APK, checklist completa en `PLAN-PULIDO-TECLADO.md` §Verificación del dueño)

- [ ] ☰ entre punto y ↵; espacio más centrado; fila completa funcional; contraseña sin ☰.
- [ ] Snippets: contenedor más alto (escala con perfil), búsqueda compacta, chips densos, grid 3 columnas con última fila full width.
- [ ] Shift: tap = una mayúscula; doble tap rápido = mayúsculas persistentes (⇪); tap posterior apaga; glifo más grande.
- [ ] ↵ , . claramente más grandes sin desalinear.
- [ ] Toque largo en 🎤 muestra el historial real (incluye dictados del teclado); insertar no duplica; borrar en la app no resucita al dictar.
- [ ] ⌫: mantener borra continuo acelerado; deslizar izquierda borra palabra por palabra; tap corto = 1 carácter.

---

## Incidencias encontradas

| # | Fecha | Hito/sección | Síntoma | App/contexto |
|---|---|---|---|---|
| — | — | Verificación 2026-08-23 completa | Sin incidencias: los 5 bloques pasaron íntegros | APK r57 (run `32634338510`) |

---

*Referencias: `PLAN-EJECUCION-LOOP.md` §11 (origen), `INSTALL.md` (instalación/batería), `AGENTS.md` §Estado.*
