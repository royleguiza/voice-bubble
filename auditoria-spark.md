# AUDITORIA-SPARK — Auditoría total de voice-bubble — 2026-09-07

> **Método:** auditoría manual, sin subagentes. Lectura directa de `app_source/lib` (6.122 líneas Dart), `voice_bubble_stt/android` (10.015 líneas Kotlin), 10 suites `test_*.py` (1.768 líneas), `.github/workflows/android.yml`, `design.md`, `design_tokens.dart`, `colors.xml`/`dimens.xml`, `AndroidManifest.xml`, `build.gradle.kts`, más `grep` sistemático de TODO/hardcodes/canales/prefs. Nada del código se tomó por verdadero: cada afirmación lleva evidencia `archivo:línea`.
> **Filosofía:** minimalismo. Lo simple y borrable es mejor que lo inteligente y enredado. Todo lo que sigue se juzga con esa vara.
> **Guía impeccable:** se audita contra `audit.native.md` + `android.md` + `typeset.md` (5 dimensiones 0–4).

## Audit Health Score (impeccable native)

| # | Dimensión | Score | Hallazgo clave |
|---|---|---|---|
| 1 | Accessibility (TalkBack) | 2 | Labels existen, Reduced Motion se honra en botón/popup/tabs, pero chips 32dp y pill historial ~32dp violan 48dp; tertiary `.3` sin contraste |
| 2 | Performance | 2 | `BackgroundWork` bien, pero `BackdropFilter σ24` en cada glass + sheet completo; I/O sync residual en UI; 3 god-objects |
| 3 | Appearance & Theming | 2 | Sistema de tokens existe y se usa a medias; `Colors.green` ×5, `TextStyle(12,w400)` fuera de tokens, sin Dynamic Color |
| 4 | Platform Conformance | 1 | Glass iOS enrollado a mano en vez de M3; bottom bar custom de 6 destinos (M3: 3–5); iconos rounded/outlined/plain mezclados |
| 5 | Adaptivity | 2 | Insets gestos bien resueltos, pero 6 tabs apretados en compact, sin rail/drawer en expanded, landscape/multi-window sin probar |
| **Total** | | **9/20** | **Poor (major overhaul en conformancia + simplificación)** |

### Veredicto Platform Conformance: FAIL
No lee como app Android nativa. Lee como app iOS (Liquid Glass, HIG type scale, capsule tab bar) con skin Android. Un usuario fluido de Android tropieza en: navegación custom de 6 tabs en vez de NavigationBar, ausencia de M3 color roles/type scale, materiales hand-rolled en vez de tonal elevation, touch targets de 32dp. Ver SPK-20–SPK-24.

### Resumen ejecutivo
- **28 hallazgos:** 8 críticos (P0), 10 altos (P1), 7 medios (P2), 3 pulido (P3).
- **Top 3:** (1) secretos en historial git + passwords/API key en prefs planas con backup a Drive; (2) release con fallback a debug.keystore; (3) 3 god-objects (VKS 4.167 líneas, Settings 2.136, Storage 1.063) que hacen imposible mantener sin romper.
- **Deuda de enredo:** doble escritura de historial con curita de dedup 30s, 32 claves prefs con ~60 getters/setters a mano, BubbleHistoryController 1.305 líneas de UI programática, laboratorio duplicado, 194 líneas de Accessibility dormida con `dispatchGesture` real.
- **Siguiente paso:** revocar PAT + reescribir historial, sacar passwords/key del backup, matar fallback release, agregar Python al CI + analyze fatal, y empezar a partir god-objects. Detalle abajo.

---

## P0 CRÍTICOS — bloquean o exponen (fix inmediato)

### SPK-01 — PAT viejo vive en historial git + secretos en disco
- **DÓNDE:** `git log --all -- wait_action.sh` → `491f528,3e3dbce,db99e30,0b8ea45`; disco: `.github_token`, `.agents/secrets.env` (600, ignorados, pero existen).
- **QUÉ:** el `wait_action.sh` actual ya está limpio (`: "${GITHUB_TOKEN:?…}"`), pero los 4 commits viejos siguen en `git log --all` con el token. `.gitignore` ignora ambos archivos hoy, pero el clon trae la historia.
- **POR QUÉ:** se commiteó el secreto antes de ignorarlo; nunca se reescribió la historia.
- **OCASIONA:** cualquiera con clone/fork lee un PAT con scope `repo`: push malicioso, exfiltración, gasto CI.
- **IDEA FIX:** revocar el PAT en GitHub ya; reescribir con `git filter-repo --path wait_action.sh --invert-path` o BFG + `git push --force`; rotar todo lo que ese PAT tocaba; añadir guard CI `git log --all -p | grep github_pat` que falle si reaparece.

### SPK-02 — Passwords y API key en SharedPreferences planas + backup a Drive
- **DÓNDE:** `app_source/lib/services/storage_service.dart:495` (`prefs.setString(sttApiKeyMirrorKey, trimmed)`), `:1001-1002` (`passes[id]=password` → `credPassKey`), `CredentialStore.kt:parsePasses` lo lee; `AndroidManifest.xml:allowBackup=true, hasFragileUserData=true`; `backup_rules.xml` + `data_extraction_rules.xml` excluyen `transcription_history.json` y `clipboard_*` pero NO `FlutterSharedPreferences.xml`.
- **QUÉ:** la key de Groq y TODAS las passwords de Claves viven en claro en prefs. El backup las sube a Drive y sobreviven desinstalación.
- **POR QUÉ:** el espejo K3 nació para el IME sin keystore, y Claves copió el mismo patrón ("el espejo plano es el mismo patrón aceptado", `storage_service.dart:911-912`). El comentario lo admite.
- **OCASIONA:** robo de cuota Groq; passwords de otros servicios en claro, con retención sin consentimiento visible (riesgo Data Safety / Play review).
- **IDEA FIX:** passwords SOLO en `flutter_secure_storage` (o EncryptedSharedPreferences en Kotlin, el IME sí puede usarlo); key: que el IME lea el keystore o pida reingreso una vez en vez de espejo perpetuo; añadir `<exclude domain="sharedpref" path="FlutterSharedPreferences.xml"/>` o `allowBackup=false` si nada debe sobrevivir; `clearSttMirror` ya borra, falta borrar también al logout/desinstalar.

### SPK-03 — Release firmada con debug si falta env
- **DÓNDE:** `voice_bubble_stt/android/app/build.gradle.kts:create("release")` → fallback a `debug.keystore` (`storePassword="android"` pública).
- **QUÉ:** sin `KEYSTORE_FILE` el `--release` firma igual, con la debug versionada.
- **POR QUÉ:** "fallback SOLO para builds locales" que el CI jamás debería tocar, pero nada lo impide.
- **OCASIONA:** APK "release" indistinguible de debug, Play lo rechaza, cualquiera con el repo firma como vos.
- **IDEA FIX:** borrar el fallback; `error("KEYSTORE_FILE ausente: release sin firma real prohibido")`. Dejar debug solo en `getByName("debug")`.

### SPK-04 — Doble escritura de historial con curita de 30s
- **DÓNDE:** escritura 1: `transcription_service.dart:92` (`storageService.add`); escritura 2: `home_screen.dart:317` (`pushHistoryEntry`) → `MainActivity.kt:102` (`TranscriptionHistoryRepository.addTranscription`); curita: `TranscriptionHistoryRepository.kt:DEDUP_TEXT_WINDOW_MS=30_000` + `isEcho`.
- **QUÉ:** cada dictado se escribe 2 veces con distinto timestamp; el dedup por texto+ventana esconde el duplicado.
- **POR QUÉ:** dos fuentes de verdad (Dart prefs+file y Kotlin file) en vez de una.
- **OCASIONA:** duplicados si el segundo write cae fuera de 30s (jank/backup); dictados idénticos legítimos <30s se TRAGAN (pérdida silenciosa); orden por timestamp falso.
- **IDEA FIX:** un solo escritor (el repo nativo atómico). Dart deja de persistir y solo lee; o al revés. Borrar `pushHistoryEntry` o `StorageService.add`, no ambos. Eliminar `DEDUP_TEXT_WINDOW_MS`.

### SPK-05 — `VoiceKeyboardService.kt` 4.167 líneas / 160 funciones: god-object
- **DÓNDE:** `wc -l VoiceKeyboardService.kt` → 4.167; `grep -c "fun "` → 160. Capas, dictado, snippets, credenciales, clipboard, trackpad, prefs, popups, haptics, todo adentro.
- **QUÉ:** el teclado ES la app. Cambiar un padding de snippet recompila dictado+clipboard+creds.
- **POR QUÉ:** crecimiento por hitos (K1→K5 + creds + trackpad + clipboard) sin partir.
- **OCASIONA:** cada fix rompe otra capa; imposible testear aislado; ANR трудно de localizar; onboarding de un mantenedor = semanas.
- **IDEA FIX:** partir por archivos sin cambiar conducta: `KeyboardPrefs.kt` (todo `flutter.*`), `DictationController.kt` (start/stop/transcribe), `SnippetsLayer.kt`, `CredentialsLayer.kt`, `ClipboardLayer.kt`, `TrackpadBridge.kt`. VKS queda como shell <500 líneas. Hacerlo en serie, un archivo por commit.

### SPK-06 — `settings_screen.dart` 2.136 líneas / 44 setState: god-screen
- **DÓNDE:** `wc -l` 2.136; `grep -c setState` → 44. Seis tabs (`_buildInicioTab`, `_buildBurbujaTab`, `_buildKeyboardTab`, `_buildTrackpadTab`, `_buildSnippetsTab`, `CredentialsScreen`) + 12 toggles trackpad + snippets CRUD + api key + burbuja, todo en un State.
- **QUÉ:** Ajustes es un monolito. El lazy `_builtTabs` evita montar todo de golpe (bien), pero lo visitado nunca se desmonta y cada slider/toggle hace setState del padre.
- **OCASIONA:** rebuilds gigantes al arrastrar sensibilidad; un bug en Claves tumba Teclado; imposible reutilizar una sección.
- **IDEA FIX:** un widget por tab (`settings/inicio_tab.dart`, `…/teclado_tab.dart`, etc.) con su propio State; `SettingsScreen` solo `IndexedStack` + `SettingsTabBar`. Mover cada `_save*` a su tab.

### SPK-07 — `StorageService` 1.063 líneas / 32 claves: dios de prefs
- **DÓNDE:** `storage_service.dart` 1.063 líneas; `docs/contract-keys.txt` 32 claves; ~30 pares get/set + snippets + creds + historial + espejo STT.
- **QUÉ:** todo KV pasa por una clase: trackpad (12 claves), teclado, burbuja, snippets, creds, historial file+prefs.
- **POR QUÉ:** sin codegen ni wrapper tipado; cada pref nueva = 2 métodos copiados a mano + espejo Kotlin a mano.
- **OCASIONA:** ya divergió una vez (haptic String-vs-Bool, hoy parchado con comentario en `FloatingTrackpadService.kt:478-482`); la próxima divergencia es crash `ClassCastException`.
- **IDEA FIX:** un `PrefsBridge` con 4 primitivas tipadas (`boolPref/stringPref/intPref/doublePref`) + tabla declarativa de claves/defaults; generar `contract-keys.txt` desde esa tabla en vez de `grep`. Borrar los 2 métodos dormidos `clearPreviousHistoryOnStartup/purgePreviousSessionHistory` (`:751-772`).

### SPK-08 — CI verde falso: Python jamás corre + analyze no fatal
- **DÓNDE:** `.github/workflows/android.yml:82-88` → `flutter analyze` pelado + `flutter test`, cero `python`. `analysis_options.yaml` endurece `strict-casts/strict-raw-types` pero sin `--fatal-infos --fatal-warnings`.
- **QUÉ:** las 8 suites Python (únicas que verifican Kotlin, prefs, manifest, sensibilidad, FIFO) solo corren en local a mano. Infos/warnings entran al APK en verde.
- **POR QUÉ:** miedo a romper CI en máquina chica; el master delega por subprocess pero nadie lo invoca en Actions.
- **OCASIONA:** "master 10/10 + CI verde" certifican cosas distintas; una regresión Kotlin llega al APK.
- **IDEA FIX:** job `python-suites` (`python3 test_master_suite.py`) antes del build; `flutter analyze --fatal-infos --fatal-warnings`. Si el runner sufre, al menos `test_master_suite.py` como gate.

---

## P1 ALTOS — mantener así sale caro (antes del próximo feature)

### SPK-09 — La app ya no hace UNA cosa (scope creep anti-minimalista)
- **DÓNDE:** `README.md` ("extremadamente simple, solo transcripción") vs realidad: teclado 3 capas + dictado 5min + snippets + credenciales/password-manager + clipboard multimodal FIFO-25 con imágenes + trackpad mouse virtual + burbuja modal con historial+snippets + 6 tabs.
- **POR QUÉ:** cada hito sumó sin quitar.
- **OCASIONA:** superficie de bugs ×6, RAM/disco en máquina de 3.8GB al límite, usuario nuevo no entiende en 10s (viola `design.md §1`).
- **IDEA FIX:** congelar features; declarar Claves y Clipboard-imágenes como experimentales con flag OFF por defecto; próxima tarjeta solo puede entrar si otra sale o se parte un god-object.

### SPK-10 — Clipboard con imágenes/LRU/executor: mini file-manager en el teclado
- **DÓNDE:** `ClipboardStore.kt` 446 líneas: `LruCache 4MB`, `Executors.newSingleThreadExecutor()`, `clipboard_media/`, `FileProvider` en manifest, `ClipboardFilmstripLayout.kt` 244 líneas.
- **OCASIONA:** OOM en gama baja, huérfanos en disco, backup ya parcheado pero frágil.
- **IDEA FIX:** modo texto primero (ya cubre 95% del uso Termux); imágenes detrás de flag; o mover a proceso aparte. Si se queda, `MAX_UNPINNED_ITEMS=25` + purga de huérfanos con test que lo pruebe.

### SPK-11 — `BubbleHistoryController.kt` 1.305 líneas de UI a mano
- **DÓNDE:** 1.305 líneas, ~25 `fun build*/populate*/render*`, `GradientDrawable` por código, `attachCardGestures`, `copySelected`, `refreshCopyAll`.
- **OCASIONA:** theming imposible (colores fuera de `colors.xml`), cada cambio visual exige leer 1.300 líneas.
- **IDEA FIX:** layout XML + ViewHolder/Adapter; o Compose si el teclado migra. Al menos extraer `HistoryCardView.kt` + `SnippetsCardView.kt`.

### SPK-12 — Laboratorio duplicado y trackeado
- **DÓNDE:** `laboratorio_ui/` + `laboratorio-ui/` ambos en `git ls-files`; png `55ca4ee….png`, `serve.js`, `analyze_html.js`, `designs/mej*.py` (14 scripts).
- **OCASIONA:** confusión (¿cuál es el bueno?), peso del repo, `node_modules` local gigante al lado.
- **IDEA FIX:** quedarse con uno, borrar el otro + png; mover lab fuera del APK repo o a `experiments/` con su propio `.gitignore`.

### SPK-13 — Colores fuera de tokens (`Colors.green` ×5 + black/white crudos)
- **DÓNDE:** `settings_screen.dart:1055,1066,1099,1128,1547` (`Colors.green` éxito); `record_button.dart:103-105`, `glass_container.dart:49-50` (`Colors.black/white`).
- **POR QUÉ:** no existe token `success`; glass usa black/white directo en vez de `kBg*`.
- **OCASIONA:** éxito verde fijo en dark (contraste pobre), glass no sigue `surfaceContainer`.
- **IDEA FIX:** añadir `kSuccessLight/Dark` a `design_tokens.dart`; reemplazar los 5; glass → `kBgElevated*` con opacidad.

### SPK-14 — Tipografía sin escala única (pesos y tamaños a mano)
- **DÓNDE:** tokens definen `Title 22 bold` + resto `normal` (`design_tokens.dart:125-159`); fuera: `settings_screen.dart:1028` (`TextStyle(12,w400)`), `:1273` (`bold/normal`), `:1739` (`bold`); `settings_tab_bar.dart:131,144` (`w600/w500`, `11sp`, `letterSpacing -0.1`).
- **QUÉ:** 4 pesos para "énfasis" (bold, w600, w500, normal) y 11sp fuera de la escala (mínimo 12). `w400` == `normal` pero escrito distinto.
- **OCASIONA:** jerarquía borrosa (¿selected es bold o w600?), drift futuro.
- **IDEA FIX:** 3 roles con nombre (`kTextSelected/kTextUnselected/kTextMeta`) y prohibir `TextStyle(` fuera de tokens (lint custom o grep-guard en CI como el de colores).

### SPK-15 — Iconos de 3 familias y 5 tamaños sin escala
- **DÓNDE:** Flutter: `Icons.settings/mic/history/cloud/copy/chat/keyboard/touch/segment/vpn_key/home` mezclando rounded/outlined/plain, tamaños 16/18/20/22/42; nativo: 20+ `ic_*.xml` custom.
- **OCASIONA:** app con 2 lenguajes de icono; glifos `,` `.` a 19sp (`dimens.xml:kb_key_glyph_punct`) vs shift/enter 16sp: compensación ad-hoc en vez de sistema.
- **IDEA FIX:** una tabla (Material Symbols, un peso, 3 tamaños: 18/22/28) y mapear cada `ic_*` a un símbolo; borrar el resto.

### SPK-16 — Touch targets <48dp (Android) / <44dp (diseño §9)
- **DÓNDE:** `dimens.xml:kb_snippet_chip_height=32dp` (comenta "mínima 32dp"), `kb_snippet_search_height=36dp`; pill Historial (`home_screen.dart:741-742`, padding v8 + footnote) ≈32dp; tab bar 6×~54dp con ellipsis.
- **NORMA:** `android.md` exige 48×48dp + 8dp separación; `design.md §9` 44×44.
- **OCASIONA:** fallos de toque en moto G / dedos grandes; TalkBack recorre 6 tabs apretados.
- **IDEA FIX:** chips/search a 48dp (o 44dp con justificación medible); pill a 48dp; si 6 tabs no entran a 48dp, bajar a 5 (fusionar Snippets+Claves en "Insertar").

### SPK-17 — I/O residual en main + lock gordo
- **DÓNDE:** `home_screen.dart:291-306` (`existsSync/lengthSync` en `_hasUsableAudio/_audioFileExists`, corre en UI); `TranscriptionHistoryRepository.kt:loadHistory` (`file.readText` dentro de `synchronized(lock)`); `ClipboardStore.kt:readFromDisk` ya salió del lock (bien, copiar el patrón).
- **OCASIONA:** jank en cada stop/retry; ANR en eMMC lenta con archivo crecido.
- **IDEA FIX:** `BackgroundWork.executeWithResult` para `hasUsableAudio`; en repo: leer fuera del lock como hace ClipboardStore, lock solo para swap de caché.

### SPK-18 — `Transcription.fromJson` miente con `now()` en silencio
- **DÓNDE:** `transcription.dart:35-53` (null/ilegible → `DateTime.now()`); `storage_service.dart:794,820` omite timestamps ilegibles solo en file/prefs, pero el modelo sigue mintiendo para otros llamadores.
- **OCASIONA:** entrada corrupta se reordena como "la más reciente"; historial FIFO-20 expulsa la buena.
- **IDEA FIX:** `fromJson` nullable o `tryParse` que devuelva null y el llamador descarte; jamás inventar tiempo.

---

## P2 MEDIOS — enredo que frena (siguiente pasada)

### SPK-19 — `Snippet.toString` expone contenido; `Credential` bien
- **DÓNDE:** `snippet.dart:toString` incluye `contenido` (puede llevar comandos con paths/tokens); `credential.dart:toString` solo `id+nombre` (bien).
- **IDEA FIX:** `Snippet.toString` → solo `id+nombre+orden`, como creds.

### SPK-20 — `ChannelGuard` traga errores en release
- **DÓNDE:** `channel_guard.dart:29-42` (`debugPrint` + `return false` siempre).
- **OCASIONA:** en release `debugPrint` no sale: permiso denegado vs binder roto indistinguibles.
- **IDEA FIX:** devolver `ChannelResult(ok, reason)` o al menos `assert` en debug + contador en release (sin contenido).

### SPK-21 — Contratos K3/D7 copiados en 4 archivos
- **DÓNDE:** mismo contrato espejo explicado en `storage_service.dart:399-420`, `SpeechToTextClient.kt:42-62`, `build.gradle` no, `INSTALL.md §3`.
- **OCASIONA:** cambias uno y los otros mienten (ya pasó con bool-only).
- **IDEA FIX:** un `docs/contrato-stt.md` único; en código solo link + 3 líneas.

### SPK-22 — Purgas dormidas pero vivas
- **DÓNDE:** Dart `clearPreviousHistoryOnStartup/purgePreviousSessionHistory` `@Deprecated` (`storage_service.dart:750-772`); Kotlin `purgePreviousSessionHistory/clearPreviousHistoryOnStartup` activos (`TranscriptionHistoryRepository.kt`).
- **OCASIONA:** alguien la llama "para limpiar" y borra 20 dictados + prefs.
- **IDEA FIX:** borrar las 4; si retención importa, test que afirme `load` no purga.

### SPK-23 — Accessibility dormida con `dispatchGesture` real
- **DÓNDE:** `VoiceBubbleAccessibilityService.kt` 194 líneas, `isConnected()=false` sin manifest (bien), pero `dispatchTap/LongPress/Scroll` con `dispatchGesture` real; 6 llamadores en VKS + 3 en trackpad que hoy son no-ops.
- **OCASIONA:** código muerto con pinta de vivo; si se declara por error, toma la pantalla; el trackpad promete "clics" que no existen.
- **IDEA FIX:** o se borra el dispatch y el trackpad se vende como "puntero local", o se documenta en UI "no hace clic fuera (sin accesibilidad)". No dejar promesa rota.

### SPK-24 — Motion inconsistente (overshoot prohibido y usado)
- **DÓNDE:** `record_button.dart:149-152` prohíbe `easeOutBack` (extrapola colores) y usa `easeOut`; `transcription_popup.dart:scale` usa `easeOutBack` para scale 0.85→1.
- **OCASIONA:** dos físicas distintas para el mismo lenguaje.
- **IDEA FIX:** una curva por trabajo (enter: `easeOutBack` solo scale, nunca decoración; exit: instantáneo como el botón). Definir `kCurveEnter/kCurveExit` en tokens.

### SPK-25 — `Debouncer.run` traga todo
- **DÓNDE:** `debouncer.dart:run` (`catch (_) {}`).
- **OCASIONA:** persist que falla (disco lleno) parece éxito.
- **IDEA FIX:** `onError` opcional + contador; UI ya es optimista, al menos loguear en debug.

---

## P3 PULIDO — ruido (si hay tiempo)

### SPK-26 — Nombres de claves sin convención (es/en, kb_/vb_/flutter.)
- `bubble_history_enabled` vs `kb_terminal_row_visible` vs `transcriptions` vs `vb_credentials_v1`. Prefijos `flutter.` solo del lado Kotlin. Renombrar rompe contrato, así que congelar y documentar la tabla (ya existe) en vez de renombrar.

### SPK-27 — Comentarios-novela vs código
- KDoc de 30 líneas por método (hilos, K3, D7) triplicado. Mover a docs, dejar 3 líneas + link. Menos es más también en comentarios.

### SPK-28 — `version 1.0.0+87` sin bump automático
- Ambos pubspec consistentes (master lo exige, bien), pero `+87` manual vs artefacto `rN` de Actions confunde (¿r111 es +87?). Adoptar `version: 1.0.0+$GITHUB_RUN_NUMBER` en CI o eliminar `+87` del repo.

---

## Patrones sistémicos (la raíz del enredo)

1. **Un dios por capa:** VKS / Settings / Storage crecen porque "es más rápido añadir ahí". Regla: archivo >500 líneas o >10 `fun` nuevos exige partir antes del siguiente feature.
2. **Dos fuentes de verdad:** historial (Dart+Kotlin), prefs (Dart+Kotlin con grep-paridad), colores (Dart tokens + XML). Cada duplicación ya dio un bug. Regla: una fuente, la otra lee.
3. **Curitas temporales:** dedup 30s, `getString` con comentario "no usar getBoolean", `_builtTabs` para no montar todo. Cada curita esconde arquitectura rota. Regla: curita con TODO + issue, o fix real.
4. **iOS en Android:** Glass enrollado, HIG types, 6-tab bar. Regla: M3 primero (NavigationBar, type scale, tonal elevation), marca después vía color/forma.
5. **Tests que no bloquean:** Python verifica lo que CI no mira. Regla: si no corre en Actions, no existe.

## Positivo (mantener y replicar)

- `BackgroundWork` pool único + `postMain` con revalidación: el patrón correcto, ya usado en `pushHistoryEntry`, SpeechToText, Clipboard. Extender al resto en vez de threads sueltos.
- `commitFromExternal` con `DeadObject/Remote/IllegalState` clasificado: binder jamás tumba el IME. Modelo a seguir para todo `currentInputConnection`.
- `CredentialStore` solo-lectura + `toString` sin secretos + `obscureText` sin ojo: privacidad bien pensada. Llevar el mismo rigor a STT espejo y snippets.
- `GlassContainer` con blur compartido + `ChannelGuard` único + `transcription_feedback.dart` como fuente de textos/fechas: centralizar en vez de copiar. Hacer lo mismo con prefs y curvas.
- `contract-keys.txt` + guards CI (hex, logs, manifest): paridad verificable. Solo falta invocarlo en cada push (SPK-08).
- Reduced Motion honrado en botón/popup/tabs + `Insets navigationBars+cutout` en teclado: accesibilidad real, no checklist.

## Acciones recomendadas (orden P0→P3)

1. **[P0]** Revocar PAT + `filter-repo` historia + guard `github_pat` en CI.
2. **[P0]** Sacar passwords/key de prefs planas y de backup; passwords a secure storage.
3. **[P0]** Matar fallback release→debug en `build.gradle.kts`.
4. **[P0]** Un solo escritor de historial; borrar `DEDUP_TEXT_WINDOW_MS`.
5. **[P0]** Partir VKS / Settings / Storage (un archivo por commit, serie).
6. **[P0]** `python test_master_suite.py` en Actions + `analyze --fatal-infos --fatal-warnings`.
7. **[P1]** Congelar features; Claves-imágenes detrás de flag; fusionar tabs a ≤5.
8. **[P1]** Tokens `success`, escala icono/touch 48dp, matar `Colors.green` y `TextStyle(` sueltos (grep-guard).
9. **[P2]** Borrar purgas dormidas, `Snippet.toString` sin contenido, `ChannelResult` con razón.
10. Final: re-correr esta auditoría y exigir ≥14/20 antes del próximo feature.

> Podés pedirme estos uno por uno, todos juntos o en el orden que prefieras. Re-correr la auditoría tras los fixes para ver el score subir.

---

## Cierre 2026-09-09 — pendientes SPK-09/10/11/15/17/21/23/26/27/28 (local, sin push)

Master local **12/12 verde** (`test_master_suite.py`; clipboard 30/30, burbuja-historial 83/83 tras actualizar anclas SPK-11). Flutter analyze/test NO corren en esta máquina (sin SDK ARM64): el CI debe verificar compilación antes de cualquier push.

| SPK | Fix | Evidencia |
|---|---|---|
| 09 | Congelamiento + experimental | `docs/congelamiento-features.md`; flag imágenes OFF en Ajustes→Teclado; banner "Experimental" en `credentials_screen.dart`; 6 tabs se mantienen con justificación medible (~50dp ≥ 48dp) |
| 10 | Texto primero + purga | `ClipboardStore.imagesEnabled()` gate en `addImageClip` + `purgeOrphanMedia()` en primera carga; `kb_clipboard_images_enabled` en triángulo Kotlin==contrato==Dart; toggle en `teclado_tab.dart`; TEST 10 en `test_clipboard_suite.py` |
| 11 | Partición | `HistoryCardView.kt` (153) + `SnippetsCardView.kt` (188) nuevos; `BubbleHistoryController.kt` 1292→1027 (delegados `buildCard`/`buildSnippetCard`/fondos/vacíos); anclas actualizadas en `test_bubble_history_suite.py` |
| 15 | Tabla iconos | `app_icons.dart` (18/22/28) + `docs/contrato-iconos.md`; `size: 16/20` → tabla; guard de tamaños en `android.yml` (job Tokens UI) |
| 17 | I/O fuera de main | `home_screen.dart`: `_hasUsableAudio`/`_audioFileExists` async + 4 call sites con await; `TranscriptionHistoryRepository`: `loadHistory` sin lock (archivo atómico), lock solo en write de `addTranscription` |
| 21 | Contrato único | `docs/contrato-stt.md` (fuente única K3/D7 + hilos); KDocs de `storage_service.dart` y `SpeechToTextClient.kt` a 3 líneas + link |
| 23 | Dormida explícita | Guards `isConnected()` en `FloatingTrackpadService` (3 dispatch); KDoc dormido; `docs/contrato-trackpad.md`; aviso "Puntero local" en `trackpad_tab.dart` |
| 26 | Claves congeladas | `docs/contrato-claves.md` (convención congelada + regla de entrada triple) |
| 27 | Podar novelas | KDocs >10 líneas → ≤3 + link en `SpeechToTextClient`, `BubbleHistoryController`, `ClipboardStore`, `TranscriptionHistoryRepository`, `FloatingTrackpadService`, `VoiceBubbleAccessibilityService`, `storage_service.dart` |
| 28 | Versión | `version: 1.0.0` (sin `+87`) en ambos pubspec; artefacto `rN` única fuente de build; About + 3 asserts actualizados |

### Score estimado tras cierre (a confirmar con re-auditoría + CI verde)

| # | Dimensión | Antes | Ahora | Por qué |
|---|---|---|---|---|
| 1 | Accessibility | 2 | 3 | 48dp + aviso trackpad; quedan 6 tabs densos |
| 2 | Performance | 2 | 3 | I/O fuera de main/lock; VKS 570, Settings 870, Bubble 1027+vistas |
| 3 | Appearance | 2 | 3 | success/text/iconos con guards; sin Dynamic Color |
| 4 | Conformance | 1 | 2 | Glass + tab-bar custom siguen; targets y tokens ya M3 |
| 5 | Adaptivity | 2 | 2 | Sin cambios (landscape/multi-window sin probar) |
| **Total** | | **9/20** | **~13/20** | Falta ≥14: Dynamic Color, rail/drawer en expanded, probar landscape |

Resto para ≥14 (no entraron, requieren decisión): Dynamic Color, NavigationBar/rail según ventana, `monochrome`, contador de generación tras rotación, PNGs huérfanos.
