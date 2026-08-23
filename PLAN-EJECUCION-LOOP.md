# PLAN-EJECUCION-LOOP.md — Orquestación de Cierre VoiceBubble (K4 → v1.0.0)

> **Fecha**: 2026-08-23 · **Coordinador**: ox-alpha (opencode)
> **Directiva del dueño (2026-08-23)**:
> 1. Implementar TODO lo que resta (K4 → Hito 6) con **subagentes en paralelo** de contexto limpio.
> 2. Tras cada tanda, un **auditor ultracrítico** (contexto limpio) califica cada tarjeta de **0 a 10** en ESTE archivo.
> 3. Puntaje **< 8.5** → nueva tanda limpia que rehace esa tarjeta → nuevo auditor → repetir hasta aprobar.
> 4. Tests después de cada hito. **PROHIBIDO pushear** hasta terminar TODO el alcance.
> 5. Sin esperas de aprobación: el coordinador ejecuta el loop completo de forma autónoma.

---

## 1. Roles y responsabilidades

| Rol | Quién | Función |
|---|---|---|
| **Coordinador** | ox-alpha (sesión principal) | Descompone hitos en tarjetas, lanza tandas paralelas, integra resultados, resuelve conflictos, commitea localmente por hito aprobado, mantiene este registro |
| **Implementador** | Subagente `general` (contexto limpio) | Ejecuta UNA tarjeta: código + tests, reporta archivos tocados y decisiones |
| **Auditor ultracrítico** | Subagente `general` NUEVO (contexto limpio) | Audita tarjetas implementadas contra su spec y las reglas del repo; devuelve veredicto estructurado con puntaje 0–10 |

**Regla de contexto limpio**: ningún subagente recibe historial conversacional. Cada lanzamiento incluye SOLO: brief de la tarjeta, contrato técnico aplicable, reglas del repo (extracto AGENTS.md §5/§8/§9), punteros a archivos a leer.

## 2. Línea base verificada (partida)

- Hitos 0–3 ✅ · T0 ✅ · K1 ✅ · K2/K2.1/K3 implementados, CI verde r55 (`32619043596`, 304 tests).
- Lote pulido visual r54 ✅ verificado por el dueño.
- Lote historial + audios largos r55: fix de historial **verificado por el dueño hoy (2026-08-23)** — marcado en `AGENTS.md` §Estado y `teclado-voice.md` §K3.
- Hito 4 (Accessibility): CONGELADO — fuera de alcance de este plan.
- Deuda menor registrada: mocks muertos `plugin.speech_to_text.*` en `home_screen_test.dart` (se limpia en K5-T7).

## 3. Alcance total restante (inventario)

| Bloque | Contenido | Estado origen |
|---|---|---|
| **K4** – Snippets y comandos | Modelo+persistencia+seeds, SnippetStore.kt tolerante, capa snippets en teclado, CRUD en Settings, tests puente | `teclado-voice.md` §K4 |
| **K5** – Pulido y entrega beta | Tema nativo completo, altura configurable, vibración on/off, i18n es/en teclado, escenarios hostiles, auditoría privacidad, regresión completa, docs, tag `v0.9.0-keyboard-beta` | `teclado-voice.md` §K5 |
| **Hito 5 re-definido** | Robustez Android 14/15, guía batería fabricantes, icono/splash, INSTALL.md, matriz de tests exhaustiva, preparación release firmado (docs) | `plan.md` §Hito 5 adaptado a decisión "solo Cloud" (tareas 1–3 de modelos locales = N/A) |
| **Hito 6** – Entrega | Coherencia docs cruzada, README final, checklist dispositivo del dueño, push único + CI ritual + tags `v0.9.0-keyboard-beta` y `v1.0.0` | `plan.md` §Hito 6 |

Fuera de alcance: Hito 4 (congelado), D9 opcional (skip registrado, requiere decisión del dueño), cualquier feature no listada arriba (anti-patrón §8).

## 4. Restricciones duras de todo el loop

1. **Zonas de edición por lane**: Lane A = `app_source/**`. Lane B = `voice_bubble_stt/android/**`. Prohibido cruzar lanes dentro de la misma tanda (evita conflictos). El contrato compartido Dart↔Kotlin está fijado AQUÍ y va embebido en cada brief.
2. **Sin push**: commits locales permitidos solo al cierre de un hito 100% APROBADO por auditoría (mensaje español imperativo). Un único push final al terminar todo (§9).
3. **Tests**: cada tarjeta que toque código exige tests Dart actualizados/creados. No hay runner Flutter local: la validación en esta fase es ESTÁTICA (relectura de diff + auditor); la ejecución real ocurre en el push final (CI). Los auditores deben tratar el análisis estático como si fuera el CI (checklist lecciones §9.1).
4. **Un hito a la vez**, tarjetas de un hito agrupadas en oleadas paralelizables.
5. Anti-patrones §8 y reglas §9.2 de AGENTS.md aplican a TODAS las tandas.

---

## 5. El LOOP (protocolo operativo)

```
┌─────────────────────────────────────────────────────────────────┐
│ Para cada hito (K4 → K5 → H5 → H6):                             │
│                                                                  │
│  1. COORDINADOR lanza OLEADA = N subagentes paralelos limpios    │
│     (uno por tarjeta; solo lanes/archivos disjuntos).            │
│  2. IMPLEMENTADORES entregan diff + reporte.                     │
│  3. COORDINADOR integra: relee TODO el diff (§9.2-7), valida     │
│     contrato compartido, detecta conflictos entre lanes.         │
│  4. COORDINADOR lanza AUDITOR ultracrítico limpio con:           │
│     tarjetas + specs + diff resumido + rúbrica §6.               │
│  5. AUDITOR califica cada tarjeta 0–10 → se registra en §10.     │
│  6. ¿Todas ≥ 8.5?                                                │
│     SÍ  → tarjetas APROBADAS. Si el hito quedó completo:         │
│           commit local + actualizar checkboxes de docs fuente.   │
│     NO  → REPROCESO: nueva tanda limpia SOLO con las tarjetas    │
│           reprobadas + lista de defectos del auditor (§7)        │
│           → volver al paso 4 con ronda+1.                        │
│  7. Siguiente hito.                                              │
│                                                                  │
│ Al agotar los 4 hitos: PUSH ÚNICO + ritual CI §9 (+ fix-waves    │
│ si el run falla, hasta verde) + tags + informe final.            │
└─────────────────────────────────────────────────────────────────┘
```

### Estados de tarjeta

`PENDIENTE → EN CURSO → IMPLEMENTADA → AUDITADA(ronda N, puntaje) → APROBADA | REPROCESO(n)`

### Contrato compartido Snippets (FUENTE ÚNICA — va embebido en briefs K4)

- Clave de preferencia: `flutter.voice_snippets_v1` (archivo `FlutterSharedPreferences`; shared_preferences antepon `flutter.` desde Dart).
- Valor: STRING JSON — array de objetos:
  `[{"id":"<str-único>","nombre":"<str>","contenido":"<str>","orden":<int>}]`
- Límites: máx **50** snippets · contenido máx **2000** caracteres · nombre requerido no vacío.
- Flag de seeds: `flutter.kb_snippets_seeded` (bool). Quien llegue primero siembra.
- Seeds exactos (decisión dueño 2026-08-22, editables/borrables):

| orden | nombre | contenido |
|---|---|---|
| 0 | Codex | `codex "` |
| 1 | Gemini | `gemini -p "` |
| 2 | Git commit | `git add . && git commit -m "` |
| 3 | Git push | `git push origin main` |
| 4 | Supabase push | `supabase db push` |

- Parseo tolerante en AMBOS lados: JSON roto/tipo incorrecto → lista vacía, jamás crash ni throw.

---

## 6. Rúbrica del auditor (0–10 por tarjeta)

| Dimensión | Peso | Qué evalúa |
|---|---|---|
| A. Funcionalidad vs spec | 30% | Cumple TODOS los criterios de la tarjeta y el contrato compartido |
| B. Riesgo-CI estático | 25% | Imports completos/rutas exactas, símbolos existentes, APIs reales del SDK/package, YAML/recursos válidos (hex ≤8 dígitos), lecciones §9.1 como checklist |
| C. Tests | 20% | Cobren los criterios automatizables; sin mocks inventados; superficie de test suficiente (lección 17/21); fakeAsync→sync IO (lección 10) |
| D. Seguridad/privacidad/anti-patrones | 15% | §8 + §5 seguridad AGENTS.md; cero logging de contenido de usuario; sin secrets |
| E. Convenciones y estilo | 10% | design.md tokens, consistencia con código existente, comentarios justificados |

`PUNTAJE = Σ(dimensión×peso)` redondeado a 1 decimal. **Aprobado: ≥ 8.5.**
El auditor es ULTRACRÍTICO: ante duda, puntúa abajo. Un solo defecto bloqueante (compilaría mal, violaría privacidad, rompería contrato) ⇒ tope 8.0.

### Formato de veredicto (por tarjeta)

```
### Auditoría · <ID-tarjeta> · ronda <N>
- A Funcionalidad: X.X/10 — <justificación breve>
- B Riesgo-CI: X.X/10 — <hallazgos>
- C Tests: X.X/10 — <hallazgos>
- D Seguridad: X.X/10 — <hallazgos>
- E Estilo: X.X/10 — <hallazgos>
PUNTAJE FINAL: X.X / 10
VEREDICTO: APROBADA | REPROCESO
Defectos bloqueantes: <lista o "ninguno">
Defectos menores: <lista o "ninguno">
```

## 7. Protocolo de REPROCESO (< 8.5)

1. Nueva tanda limpia por tarjeta reprobada. El brief incluye: tarjeta original + veredicto completo del auditor + regla "se reevalúa la tarjeta completa, no solo el parche".
2. Nuevo auditor limpio (ronda N+1) recalifica desde cero contra la MISMA rúbrica.
3. Repetir hasta ≥ 8.5. Cada ronda queda registrada en §10.2 (columna rondas).

---

## 8. Tarjetas de trabajo

> Formato: lane · archivos · criterios. Lo verificable en dispositivo pasa al checklist del dueño (§11).

### HITO K4 — Snippets y comandos

**OLEADA 1** (paralela):
- **K4-T1** [Lane A] Modelo + persistencia Dart.
  - Nuevo `app_source/lib/models/snippet.dart` (estilo del modelo existente; toJson/fromJson con claves exactas del contrato §4).
  - `app_source/lib/services/storage_service.dart`: CRUD snippets (list/add/update/delete/reorder), límites 50/2000, parseo tolerante, `ensureSeeds()` idempotente vía flag, constantes de claves canónicas.
  - Tests nuevos: CRUD · límites rechazados · JSON corrupto → vacío · seeds idempotentes · orden.
- **K4-T2** [Lane B] `SnippetStore.kt` nuevo (solo el store, sin wiring UI).
  - Data class + lectura tolerante de la clave del contrato, cache + `reload()`, `seedIfFirstOpen()` con los 5 seeds exactos, orden por campo `orden`.
  - Import org.json PRIMERO (lección §9.1-22). Cero logs de contenido.

**OLEADA 2** (paralela, tras integrar O1):
- **K4-T3** [Lane B] Capa snippets en el teclado.
  - Acceso a capa chips: grid scrollable; búsqueda arriba filtra por nombre en tiempo real; toque = insertar contenido completo en cursor (`commitText`); toque largo = menú insertar/copiar/abrir app para editar.
  - Recarga desde SnippetStore en cada apertura de capa ⇒ cambios de la app visibles ≤2 s sin reiniciar nada.
  - Seeds se siembran en la primera apertura de la capa. Estética tokens nativos r54; Reduced Motion respetado.
- **K4-T4** [Lane A] CRUD UI en SettingsScreen (sección Teclado existente).
  - Crear/editar/borrar/reordenar; preview multilínea; validación de límites con feedback claro; Liquid Glass estricto según design.md; textos es/en.
  - Widget tests: render · crear/editar/borrar · límite 50 · persistencia.

**Cierre K4 (K4-T5, coordinador)**: verificación cruzada del contrato entre lanes, regresión historial/micrófono intacta, checkboxes automatizables de K4 marcados en `teclado-voice.md`, commit local `Hito K4: snippets y comandos`.

### HITO K5 — Pulido, robustez y entrega beta

**OLEADA 3** (paralela):
- **K5-T1** [B] Tema/tokens completos en todas las capas del teclado (claro+oscuro siguiendo el sistema; pressed/haptic consistentes; contraste r54 como base).
- **K5-T2+T3** [A+B, UN solo agente para ambas zonas] Altura del teclado configurable baja/media/alta (`flutter.kb_height_profile` → Kotlin aplica factor respetando insets, lección §9.1-20) + vibración on/off (`flutter.kb_haptics_enabled`, default ON) + sin sonido de tecla.

**OLEADA 4** (paralela):
- **K5-T4** [B] i18n es/en de etiquetas internas del teclado (avisos inline, menús, búsqueda) con el patrón de idiomas ya existente.
- **K5-T5** [B] Escenarios hostiles: rotación a mitad de dictado · cambio rápido de campo/app grabando · llamada entrante (pérdida audio focus) → cancelaciones limpias, estados consistentes, exclusión mutua intacta.
- **K5-T6** [auditoría técnica estática] grep `Log.` en TODO Kotlin del teclado → solo diagnóstico sin contenido; confirmar cero persistencia de texto tecleado; informe en registro.
- **K5-T7** [A] Regresión completa de tests + limpieza deuda mocks muertos `home_screen_test.dart`.
- **K5-T8** [docs] README sección teclado/snippets + preparación tag `v0.9.0-keyboard-beta`.

Cierre K5: auditoría oleadas 3–4 → commit local + checklist dueño actualizada.

### HITO 5 re-definido (solo Cloud)

> Tareas originales 1–3 (modelos locales) N/A: modo Local removido por decisión del dueño (2026-08-22). Release firmado: solo se DOCUMENTA el proceso (keystore NUNCA al repo); la firma real queda para el dueño.

**OLEADA 5** (paralela):
- **H5-T1** [B] Robustez Android 14/15: `foregroundServiceType` micrófono correcto, POST_NOTIFICATIONS runtime en flujo burbuja, revisión restricted settings; parches menores solo si falta algo.
- **H5-T2** [docs] Guía de optimización de batería (Xiaomi/Huawei/Oppo/Samsung) en INSTALL.md.
- **H5-T3** [B] Icono adaptive profesional (vector XML foreground/background, sin binarios pesados) + splash simple coherente con design.md.
- **H5-T4** [docs] INSTALL.md completo: instalación APK, permisos justificados, activación teclado/burbuja, batería, troubleshooting.
- **H5-T5** [A] Matriz de tests exhaustiva: grabación larga simulada · reintento sin regrabar · modos Toque/Mantener persisten · FIFO-20 exacto · errores red/API reintentable vs no-reintentable.

### HITO 6 — Entrega final

**OLEADA 6**:
- **H6-T1** [coordinador] Coherencia cruzada README↔AGENTS↔plan↔teclado-voice↔design↔INSTALL + suite completa lista para CI.
- **H6-T2** [docs] README final pulido (alcance dual, privacidad del teclado, permisos).

---

## 9. Entrega final (protocolo de cierre)

1. Verificación previa del coordinador: diff global releído; YAML validado con python3-yaml si se tocó; colores hex ≤8 dígitos; imports Kotlin/Dart revisados contra lecciones §9.1.
2. **PUSH ÚNICO a `main`** con los commits locales acumulados (uno por hito aprobado).
3. Ritual obligatorio AGENTS.md §9.4: monitorear el run hasta `completed` con el token de `/root/.local/share/gh-actions/token` (NUNCA exponer/imprimir/commitear su valor).
   - `failure` → fix-wave inmediata (tanda limpia con logs del job/step fallido) → nuevo push → repetir hasta verde.
   - `success` → reportar Run ID, link de Actions, artefacto `voice-bubble-debug-apk-r<N>` y total de tests.
4. Tags en orden: `v0.9.0-keyboard-beta` (cierre K5) y `v1.0.0` (entrega final).
5. Actualizar §Estado de AGENTS.md y checkboxes de plan.md / teclado-voice.md con los resultados CI reales.
6. Informe final al dueño + checklist §11 completa para verificación en dispositivo.

## 10. Registro vivo

### 10.1 Log de oleadas

| # | Oleada | Tarjetas | Inicio | Fin | Resultado |
|---|---|---|---|---|---|
| 1 | K4-O1 | K4-T1 ∥ K4-T2 | 2026-08-23 | 2026-08-23 | APROBADA (T1 9.6 · T2 8.9, ronda 1) |
| 2 | K4-O2 | K4-T3 ∥ K4-T4 | 2026-08-23 | 2026-08-23 | APROBADA ronda 2 (T3 8.9 · T4 9.5) |

### 10.2 Estado de tarjetas

| ID | Título | Lane | Estado | Ronda | Puntaje |
|---|---|---|---|---|---|
| K4-T1 | Modelo+persistencia snippets Dart | A | APROBADA | 1 | 9.6 |
| K4-T2 | SnippetStore.kt tolerante | B | APROBADA | 1 | 8.9 |
| K4-T3 | Capa snippets en teclado | B | APROBADA | 2 | 8.9 |
| K4-T4 | CRUD UI Settings | A | APROBADA | 2 | 9.5 |
| K4-T5 | Integración+cierre K4 | Coord. | APROBADA | — | — |
| K5-T1..T8 | ver §8 | mixto | PENDIENTE | — | — |
| H5-T1..T5 | ver §8 | mixto | PENDIENTE | — | — |
| H6-T1..T2 | ver §8 | mixto | PENDIENTE | — | — |

### 10.3 Decisiones del coordinador

| Fecha | Decisión | Motivo |
|---|---|---|
| 2026-08-23 | D9 (snippets multi-app) fuera de alcance v1 | Opcional según teclado-voice.md §3/D9; requiere decisión del dueño para activarla |
| 2026-08-23 | Tests se ejecutan recién en el push final | No existe runner Flutter local (Termux); validación intermedia = análisis estático + auditoría |
| 2026-08-23 | Commits locales por hito aprobado, push único al final | Directiva del dueño: nada se pushea hasta completar TODO el alcance |
| 2026-08-23 | Ids de seeds alineados entre lanes (`seed-codex`…`seed-supabase-push` en ambos lados) | Integración O1 detectó divergencia `seed-N` vs `seed-*`; el contrato exige ids estables compartidos |
| 2026-08-23 | "Abrir app para editar" del menú contextual = lanzar MainActivity propia | No es D9 (apps de terceros); patrón ya usado por avisos inline de K3 ("abrir Ajustes") |
| 2026-08-23 | Fix de 1 línea K4-T4 aplicado por el coordinador (parche mínimo del auditor, verbatim) | El lanzamiento del subagente falló por error de formato; parche trivial con instrucción exacta del auditor |
| 2026-08-23 | Fila(s) alfabéticas dentro de la capa snippets (búsqueda tecleada completa) se agrega como alcance de K5-T1 | Defecto menor aprobado por auditor r2; no bloquea el criterio "filtra en tiempo real" (dictado/historial/puntuación ya pueblan) |
| 2026-08-23 | Criterios de aceptación K4 que requieren dispositivo NO se marcan aún | Se acumulan en la checklist del dueño §11 y se cierran con el APK del push final |

### 10.4 Incidencias

(ninguna aún)

### 10.5 Veredictos de auditoría

> El auditor devuelve los veredictos en el formato §6; el coordinador los vuelca aquí, uno por tarjeta y ronda.

### Auditoría · K4-T1 · ronda 1
- A Funcionalidad: 9.5/10 — CRUD completo, límites exactos (50/2000/nombre), seeds byte a byte contra contrato, idempotencia correcta. Menor: saveSnippets público no aplica límites.
- B Riesgo-CI: 9.5/10 — analyze estricto simulado limpio; records válidos en SDK ≥3.5; APIs reales de shared_preferences.
- C Tests: 9.5/10 — cubren todos los criterios automatizables con mock oficial; sin canales inventados.
- D Seguridad: 10.0/10 — sin secrets ni logging activo.
- E Estilo: 9.5/10 — consistente con el resto del archivo.
PUNTAJE FINAL: 9.6 / 10
VEREDICTO: APROBADA
Defectos bloqueantes: ninguno
Defectos menores: saveSnippets público sin límites; reload() por lectura; read-modify-write no atómico (irrelevante en UI secuencial).

### Auditoría · K4-T2 · ronda 1
- A Funcionalidad: 9.5/10 — lectura tolerante, cache+reload, seeds exactos alineados, orden estable, flag siempre marcado.
- B Riesgo-CI: 9.5/10 — imports org.json primero (lección 22); APIs org.json/SharedPreferences verificadas contra la realidad.
- C Tests: 6.5/10 — spec no exigía tests y no hay infra Kotlin de tests; parseo/seeds automatizables quedarían para Robolectric.
- D Seguridad: 9.5/10 — logs solo numéricos; catch silencioso en seedIfFirstOpen (seguro pero sin diagnóstico).
- E Estilo: 9.5/10 — patrón idéntico a SpeechToTextClient.kt.
PUNTAJE FINAL: 8.9 / 10
VEREDICTO: APROBADA
Defectos bloqueantes: ninguno
Defectos menores: sin tests unitarios Kotlin; default de `orden` ausente difiere Dart(0) vs Kotlin(índice); catch sin log; cache obsoleto posible entre procesos (mismo patrón validado K3).

### Auditoría · K4-T3 · ronda 1
- A Funcionalidad: 6.5/10 — capa completa salvo DEFECTO CRÍTICO: la búsqueda es inoperable (ninguna ruta de teclas escribe en el EditText interno; todas van a currentInputConnection de la app destino).
- B Riesgo-CI: 9.0/10 — kotlinc/AAPT2 simulados limpios; imports y recursos verificados. Menor runtime: menú puede recortarse arriba para chips de primera fila.
- C Tests: 7.0/10 — sin infra Kotlin de tests (correcto en este repo); la feature rota solo sería visible en dispositivo.
- D Seguridad: 9.5/10 — cero Log de contenido; solo lectura del store; oculto en contraseñas; clipboard iniciado por usuario.
- E Estilo: 9.0/10 — integración quirúrgica reutilizando helpers existentes.
PUNTAJE FINAL: 7.9 / 10
VEREDICTO: REPROCESO
Defectos bloqueantes: búsqueda no escribible desde el propio teclado — requiere enrutamiento estilo Gboard (capturar commit cuando la búsqueda está enfocada y redirigirlo al campo) o fila de letras dedicada dentro de la capa.
Defectos menores: menú recortable en borde superior primera fila; grid 112dp corto para listas grandes; contentDescription "snippets" sin variante EN.

### Auditoría · K4-T4 · ronda 1
- A Funcionalidad: 9.5/10 — CRUD+reorden+validaciones+seeds completos con tokens verificados contra fuente real.
- B Riesgo-CI: 9.5/10 — analyze estricto simulado limpio; APIs reales; mounted guards OK.
- C Tests: 5.5/10 — cobertura amplia con persistencia desde instancia fresca; DEFECTO BLOQUEANTE: 'límite 50' aserte `find.text('Extra'), findsNothing` pero el sheet queda ABIERTO tras el rechazo y su TextField matchea → suite roja.
- D Seguridad: 9.0/10 — doble validación UI+StorageService; confirmación de borrado; sin logs ni secrets.
- E Estilo: 9.0/10 — convenciones respetadas; keys ValueKey consistentes usadas por tests.
PUNTAJE FINAL: 8.0 / 10 (topado por bloqueante)
VEREDICTO: REPROCESO
Defectos bloqueantes: settings_snippets_test.dart ~línea 234 — fix mínimo: asertar contra storage, o verificar ausencia del tile por key, o acotar el finder al ListView (el sheet NO es descendiente del ListView).
Defectos menores: reorder sin aserción de UI post-movimiento; tiles con Card/theme en vez de GlassContainer directo (aceptable).

### Auditoría · K4-T3 · ronda 2
- A Funcionalidad: 8.7/10 — routing estilo Gboard verificado en los 3 puntos + backspace/enter/visuales/resets; resto de la spec intacto y sin regresiones.
- B Riesgo-CI: 9.5/10 — kotlinc/AAPT2 simulados limpios; refs R existentes (incluye kb_label_on_accent/kb_key_stroke ya en repo); cero Log.
- C Tests: 8.0/10 — sin cobertura Kotlin automatizada (convención del repo); routing descansa en análisis estático + verificación del dueño.
- D Seguridad: 9.5/10 — query solo en memoria, limpiado al salir; contraseñas sin ☰ ni 🎤; clipboard por acción explícita.
- E Estilo: 9.5/10 — KDoc español, helpers factorizados, sin hardcodeos.
PUNTAJE FINAL: 8.9 / 10
VEREDICTO: APROBADA
Defectos bloqueantes: ninguno
Defectos menores: capa SNIPPETS sin filas alfabéticas (búsqueda manual limitada a dictado/historial/puntuación → sugerido para K5); CTRL/ALT sticky sobreviven al modo búsqueda (visibles, se consumen después); ES/EN intra-capa apaga modo conservando query; dictado durante búsqueda va al query; doble refresh por pulsación; tope 50 chars sin feedback.

### Auditoría · K4-T4 · ronda 2
- A Funcionalidad: 9.5/10 — fix mantiene significado exacto (sheet fuera del ListView); los otros 7 tests re-verificados contra la implementación real.
- B Riesgo-CI: 9.5/10 — analyze estricto simulado limpio; mounted guards completos.
- C Tests: 9.5/10 — 8 pruebas CRUD+reorden+límites+validación+seeds; fix más preciso que el original.
- D Seguridad: 10.0/10 — API key obscureText; sin secretos en tests.
- E Estilo: 9.5/10 — tokens Liquid Glass correctos; comentario del fix explica el porqué.
PUNTAJE FINAL: 9.5 / 10
VEREDICTO: APROBADA
Defectos bloqueantes: ninguno
Defectos menores: finder byType(ListView) sin scoping al Scaffold (hoy imposible de colisionar); duplicación documentada de consts 50/2000 UI↔StorageService.

---

## 11. Checklist acumulada de verificación en dispositivo (para el dueño)

> Se completa durante el loop con todo lo no automatizable. Se entrega al final junto al APK.

**Pendientes heredadas (K2/K3):**
- [ ] Termux: `ls`+TAB autocompleta; Ctrl+C corta; Ctrl+L limpia; Ctrl+[ = ESC; flechas navegan historial bash.
- [ ] Acode: llaves/corchetes correctos; par auto-cerrado con toque largo.
- [ ] Teclas terminales no rompen apps normales (Chrome ignora ESC/CTRL sin error).
- [ ] Dictado es/en en Chrome, WhatsApp y Acode deja el texto exacto en el cursor.
- [ ] Burbuja grabando → teclado avisa ocupado (y viceversa).
- [ ] Campo de contraseña → micrófono invisible.

**Se agregan al cerrar cada hito:**

*Cierre K4 (verificar con APK del push final):*
- [ ] Seeds visibles en la primera apertura de la capa ☰ del teclado.
- [ ] Crear snippet en la app → aparece en el teclado al reabrir la capa, sin reiniciar nada (≤ 2 s).
- [ ] Editar/borrar en la app se refleja igual en el teclado.
- [ ] Insertar un snippet multilínea en Acode y en Termux funciona íntegro.
- [ ] Toque largo en chip: Insertar / Copiar al portapapeles / Abrir app para editar funcionan.
- [ ] Búsqueda filtra por nombre en tiempo real (probar con dictado 🎤 y espacio/coma; las letras tecleadas llegan con K5-T1).
- [ ] Modo búsqueda: campo iluminado captura teclas; ↵ sale del modo; ⌫ borra el query sin tocar el documento.
- [ ] Corromper el JSON manualmente → teclado vivo con lista vacía, sin crash.
- [ ] En un campo de contraseña NO aparece la tecla ☰.

---

## 12. Resumen del flujo para cualquier agente que lea este archivo

1. Este archivo es la fuente de verdad del ESTADO del loop; `plan.md`/`teclado-voice.md` siguen siendo la fuente del QUÉ.
2. Los subagentes NUNCA editan este archivo salvo el auditor vía el coordinador (los veredictos los vuelca el coordinador en §10.5).
3. Toda desviación de spec se registra en §10.3 antes de ejecutarse.
4. El loop termina únicamente cuando: todas las tarjetas APROBADAS ≥8.5 + push final verde + tags creados + informe entregado.
