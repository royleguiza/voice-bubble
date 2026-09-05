# PLAN-PULIDO-TECLADO.md — Loop de pulido UI v1.1 (post v1.0.0)

> **Origen**: decisión del dueño 2026-08-23 tras verificación completa de CHECKLIST-TESTING.md sin incidencias.
> **Alcance**: 6 tarjetas (P1–P6), una por tecla/área del teclado nativo Kotlin. Nada fuera de esta lista.
> **Fuente de edición principal**: voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/VoiceKeyboardService.kt (+ res/values/dimens.xml si hace falta). El código Dart NO se modifica salvo que una tarjeta lo exija explícitamente.
> **Proceso**: subagentes SECUENCIALES (archivo compartido = cero ediciones paralelas) → auditor ultracrítico → aprobación solo con calificación > 9.0/10 por tarjeta → batería de verificación → push único a main → monitoreo CI obligatorio → APK nuevo al dueño.
> **Baseline verde**: run 32634338510 (r57, 368 tests), tag v1.0.0, commit c146c09.

---

## Reglas transversales (obligatorias para todos los subagentes)

1. Editar SOLO lo que su tarjeta indica. Cada subagente parte del estado actual del repo y NO toca regiones de otras tarjetas.
2. Diseño: colores SIEMPRE vía recursos existentes (R.color.*, R.drawable.kb_*). Prohibido hardcodear hex en Kotlin. Métricas nuevas como dimen en dimens.xml (nombres kb_*), nunca px mágicos.
3. i18n es/en: todo texto visible nuevo u oculto condicionado a spanishMode.
4. Privacidad: prohibido loguear contenido (texto tecleado, transcripciones). Solo diagnósticos numéricos (conteos) si son imprescindibles, precedente auditoría K5-T6.
5. Campos de contraseña: ninguna tecla nueva funcional allí (☰ y 🎤 ya se ocultan; mantener).
6. Reduced Motion: nada de animaciones nuevas; haptics según patrón existente (haptic()).
7. Sin comentarios innecesarios; estilo Kotlin del archivo actual. Ante errores en cascada de Kotlin, revisar PRIMERO imports.
8. Verificación local disponible (sin Flutter/Gradle): releer el diff completo buscando símbolos inexistentes e imports faltantes.
9. Al terminar, el subagente devuelve: lista de cambios con líneas, decisiones tomadas, riesgos y checklist de criterios marcados.

---

## P1 — Fila inferior: ☰ entre punto y ↵; espacio más centrado

**Estado actual** (buildBottomBar, ~L346): orden = ?123(w1.5) · </>(w1 opcional) · ☰(w1) · ES/EN(w1 opcional) · 🎤(w1) · ,(w1) · espacio(w2.6) · .(w1) · ↵(w1.8).

**Cambios**:
- Mover ☰ al extremo derecho: entre . y ↵. Orden objetivo: ?123 · </> · ES/EN · 🎤 · , · espacio · . · ☰ · ↵.
- Ajustar pesos para equilibrio visual (espacio puede subir levemente, p. ej. w2.6→3.0); documentar los pesos elegidos.
- Mantener ocultación de ☰ en campos de contraseña sin dejar huecos.

**Criterios de aceptación (dispositivo)**:
- [x] ☰ queda entre . y ↵ en capas LETTERS/SYMBOLS/CODE.
- [x] Espacio visualmente más centrado que hoy.
- [x] Todas las funciones previas de la fila operan (?123, </>, ES/EN, 🎤, coma, punto, enter).
- [x] En campo de contraseña ☰ invisible y fila equilibrada.

## P2 — Panel de snippets: contenedor +20%, búsqueda compacta, chips densos, grid 3 columnas responsivo

**Estado actual**: kb_snippets_grid_height = 80dp fijo (no escala con perfil de altura); chips en filas fijas de 2 (refreshSnippetGrid); input de búsqueda grande; scroll difícil.

**Cambios**:
- Altura del contenedor: mínimo +20% respecto al valor efectivo actual, escalando con heightFactor vía scaleV() (corrige deuda de auditoría K5-T2/T3). Puede proponerse hasta +30% si el llenado útil lo justifica; documentarlo.
- Input de búsqueda: reducir altura y texto (nuevo dimen kb_snippet_search_height; reuso de tamaños existentes para fuente), padding menor. Query y cursor deben seguir visibles.
- Chips: más compactos (nuevo dimen kb_snippet_chip_height, p. ej. 28dp; fuente igual o un punto menor que la actual small; menos padding). Área táctil efectiva >= 32dp.
- Grid: 3 columnas. Responsivo obligatorio: si los chips filtrados no completan una fila de 3, los últimos reparten la fila completa equitativamente (1 solo = peso 3f; 2 = 1.5f c/u).
- Evaluar 2 vs 3 columnas con criterio medible (densidad visible vs legibilidad con nombres ellipsized) y dejar la conclusión en el resumen; implementar 3 salvo evidencia contraria fuerte.
- Verificar que con la nueva altura se ven ~4–6 chips sin scrollear en pantalla típica.

**Criterios de aceptación (dispositivo)**:
- [x] Contenedor claramente más alto (+20% mínimo) y escala con perfil baja/media/alta.
- [x] Búsqueda más chica pero usable.
- [x] Chips compactos; los 5 seeds casi sin scroll.
- [x] Con 5 seeds: filas de 3+2 full width; con 7: 3+3+1 full width.
- [x] Filtro en vivo OK; backspace borra query; nada escribe en el documento.

## P3 — Shift: doble pulsación = CAPS LOCK persistente + glifo más grande

**Estado actual**: toggleShift alterna bool shiftActive; tras cada letra se apaga solo (commitLetter ~L579-591); visual = fondo accent.

**Cambios**:
- Máquina de estados off → on(momentáneo) → capsLock. Doble pulsación rápida (umbral <=300ms entre taps) activa CAPS LOCK persistente: todo en mayúscula hasta pulsación simple posterior, que apaga directo a off.
- En capsLock las letras NO se auto-apagan tras commit (ajustar commitLetter/displayFor).
- Visual diferenciado: shift momentáneo = fondo accent actual; capsLock = fondo accent + glifo distinto (p. ej. ⇪) u otro recurso existente sobrio. Documentar elección.
- Estado respetado al cambiar de capa y en onStartInputView según comportamiento actual (reset coherente).
- Glifo ⇧ +10–15% de tamaño interno (nuevo dimen tipo kb_key_glyph_shift; contenedor intacto).

**Criterios de aceptación (dispositivo)**:
- [x] Tap simple: una mayúscula y vuelve (comportamiento actual intacto).
- [x] Doble tap rápido: mayúsculas persistentes; escribir MY_FUNC completo; tap posterior restaura.
- [x] Shift momentáneo y capsLock distinguibles a simple vista.
- [x] ⇧ claramente más grande/pesada sin romper la fila.

## P4 — Glifos internos: ↵ , . +10–15%

**Estado actual**: ↵ hereda textSize de makeSpecialKey; coma y punto usan texto estándar de makeSymbolKey.

**Cambios**:
- Subir tamaño interno del glifo ↵ y de , y . (+10–15%) vía nuevos dimens (p. ej. kb_key_glyph_enter, kb_key_glyph_punct). Contenedores intactos.
- Centrado óptico verificado; ajustar padding solo si hace falta.

**Criterios de aceptación (dispositivo)**:
- [x] ↵ , . claramente más grandes, sin tocar teclas vecinas ni desalinear filas.

## P5 — Historial del micrófono: fix del modal vacío

**Síntoma**: toque largo en 🎤 muestra "Sin transcripciones todavía" pese a haber dictados guardados (visibles en la app).

**Investigación obligatoria** (descartar una por una, con evidencia en el resumen):
1. Instancia cacheada desactualizada: probar prefs.reload() antes de leer en sharedHistoryEntries().
2. Entradas cuyo JSON no parsea se descartan en silencio: contar descartes (diagnóstico numérico permitido).
3. Clave/formato real de Dart (storage_service.dart L8 _key='transcriptions' → Android flutter.transcriptions; setStringList = StringSet): confirmar contra código, no asumir.
4. Ruta del popup en makeMicKey (~L742): estados y anchor correctos.
5. Mutación accidental del Set devuelto por getStringSet (corrompe caché interna): copiar a HashSet propio antes de usar.

**Fix**: el que la evidencia respalde; mínimo esperado: lectura fresca garantizada + tolerancia de formato si aplica + conteo de descartes. Ventana con hasta 20 entradas por timestamp desc; tap inserta en cursor sin duplicar.

**Criterios de aceptación (dispositivo)**:
- [x] Con historial existente (teclado y/o burbuja) la ventana muestra las entradas reales.
- [x] Insertar deposita el texto en el cursor y no duplica en historial.
- [x] Con historial genuinamente vacío dice "Sin transcripciones todavía".
- [x] Cero contenido en logs.

## P6 — ⌫: autorrepetición por pulsación larga + gesto deslizante para borrar palabra

**Estado actual**: cada tap borra 1 carácter (handleBackspace); attachLongPress dispara una sola acción a los 350ms y no repite.

**Cambios**:
1. Autorrepetición (prioridad 1, obligatoria): pulsación larga inicia borrado continuo — primer borrado ~350ms, repeticiones desde ~250ms acelerando hasta ~50ms (constantes nombradas). Cancelación limpia en ACTION_UP/ACTION_CANCEL/salida de la tecla. Funciona en documento y en query de snippets (reusar handleBackspace). Haptic solo al inicio.
   - Extender attachLongPress con modo repetición (callback onRepeat opcional) SIN romper usuarios actuales (acentos, pares, mic, chips).
2. Gesto deslizante (prioridad 2, implementar): durante la pulsación larga sobre ⌫, arrastre horizontal hacia la izquierda borra PALABRA completa por cada umbral de distancia (~48dp, constante nombrada), usando deleteSurroundingText por límites de palabra. Factibilidad confirmada: el touch listener ya recibe ACTION_MOVE; es viable sin librerías nuevas. Documentar límites (no oraciones completas en v1.1).
3. El gesto NO debe activarse en toques cortos ni interferir con el tap simple de borrar 1 carácter.
4. i18n de contentDescription si cambia.

**Criterios de aceptación (dispositivo)**:
- [x] Mantener presionado ⌫ borra continuo acelerado; soltar detiene al instante.
- [x] Deslizar a la izquierda durante la pulsación borra palabra por palabra según distancia.
- [x] Tap corto sigue borrando exactamente 1 carácter.
- [x] En búsqueda de snippets ambas modalidades operan sobre el query.

---

## Proceso de ejecución (coordinador)

1. Subagentes ESCRITORES secuenciales P1→P6 (archivo compartido). Cada uno implementa su tarjeta completa y devuelve resumen.
2. Auditor ultracrítico único: califica cada tarjeta 0–10 verificando contra el código real. Aprobación exige > 9.0. Tarjetas < umbral vuelven a su escritor para fix y re-auditoría (máx 2 rondas).
3. Batería antes del push: diff completo re-leído por el coordinador + guardas grep (sin hex hardcodeado en Kotlin nuevo, sin Log de contenido, dimens nuevos presentes en ambos valores/night si aplicara) + validación YAML del workflow si se tocó + baseline CI verde previa.
4. Push único a main → monitoreo CI obligatorio (token /root/.local/share/gh-actions/token, jamás imprimirlo). Si falla: corrección inmediata antes de cualquier otra tarea.
5. Éxito: informar run ID, artefacto voice-bubble-debug-apk-r<N> y checklist de verificación en dispositivo para el dueño (sección nueva al final de este archivo).

## Estado del loop

- [x] P1 — Fila inferior ☰/espacio (auditoría 9.7)
- [x] P2 — Panel snippets (auditoría 9.6; grid 3 col elegido con análisis medible: seeds ≤13 chars ≈ ≤95dp a 117dp/columna, cero ellipsize, densidad 6 chips visibles)
- [x] P3 — Shift capsLock (auditoría 9.7)
- [x] P4 — Glifos ↵ , . (auditoría 9.8)
- [x] P5 — Historial mic (auditoría 8.8 → fixes obligatorios aplicados → re-auditoría 9.1)
- [x] P6 — ⌫ repetición + gesto (auditoría 9.4)
- [x] Auditoría >9.0 en las 6 tarjetas (auditor ultracrítico, diff leído línea a línea)
- [x] Batería pre-push (guardas grep sin hex/Log, XML válido, constantes def=uso, balance llaves/paréntesis 0, sin restos shiftActive, baseline r57 verde)
- [x] Push + CI verde (run [`32655570378`](https://github.com/royleguiza/voice-bubble/actions/runs/32655570378) success al primer intento · artefacto `voice-bubble-debug-apk-r58`)
- [x] APK entregado al dueño (r58)

Condiciones de vigilancia registradas por el auditor (no bloqueantes):
- Si se expone borrado individual/clear() de transcripciones en la app, el overlay anti-resurrección de P5 exigirá límite por sesión antes de mergear.
- `lastHistoryDiscarded` es un gancho de diagnóstico pasivo sin consumidor aún.
- Palabras >64 chars se recortan parciales en el gesto ⌫ (documentado v1.1).

## Verificación del dueño (declarada completa por el dueño el 2026-08-23; validación física pendiente de su descarga del APK)

**P1:** ☰ entre `.` y `↵` en LETTERS/SYMBOLS/CODE · espacio más centrado · toda la fila funciona · contraseña sin ☰ ni huecos.
**P2:** contenedor claramente más alto y escala con perfil baja/media/alta · búsqueda compacta usable · chips compactos, 5 seeds casi sin scroll · 5 seeds = filas 3+2 full width; crear 7 = 3+3+1 · filtro vivo/backspace/nada al documento.
**P3:** tap simple = una mayúscula y vuelve · doble tap rápido = mayúsculas persistentes (escribe MY_FUNC completo) · tap posterior apaga todo · ⇧ vs ⇪ distinguibles · glifo más grande sin romper la fila.
**P4:** ↵ , y . claramente más grandes, sin desalinear filas.
**P5:** toque largo 🎤 muestra las entradas reales (dictados de burbuja/app Y de teclado) · lo más nuevo arriba · tocar inserta en cursor sin duplicar · borrar una entrada en la app → dictar desde teclado → NO reaparece · primera instalación sin datos sí dice "Sin transcripciones todavía".
**P6:** mantener ⌫ borra continuo acelerado y soltar detiene al instante · deslizar a la izquierda borra palabra por palabra según distancia · flick corto (<350ms) borra una palabra · tap corto = exactamente 1 carácter · ambas modalidades operan sobre el query de snippets · acentos/pares/mic/chips intactos.
**Global:** tema claro/oscuro correcto en todo lo nuevo · 15 min de uso mixto sin crash ni ANR.

| # | Fecha | Tarjeta | Síntoma | App/contexto |
|---|---|---|---|---|
| — | 2026-08-23 | P1–P6 + auditoría total v1 (F1–F11) | Sin incidencias reportadas; dueño declaró todo completo antes de descargar r62 | APK r58/r62, CI verde runs `32655570378` y `32666610965` |
