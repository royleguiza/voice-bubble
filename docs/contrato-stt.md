# Contrato STT K3/D7 — fuente única

> Este archivo es la **única fuente de verdad** del contrato de API key y
> config STT entre Flutter (app) y Kotlin (IME). El código solo enlaza aquí
> (3 líneas + link). Si este doc y un comentario difieren, vale este doc.

## Dónde vive cada dato

| Dato | Dónde | Clave | Quién escribe | Quién lee |
|---|---|---|---|---|
| API key Groq | Bóveda cifrada (ESP) | `groq_api_key` | Dart `saveSttMirror` / `clearSttMirror` | Dart secure_storage, Kotlin `SecureStore.read` |
| Presencia key | Prefs planas | `kb_stt_key_configured` (bool) | Dart `saveSttMirror`/`repairSttMirror` | Kotlin fail-fast "sin key" |
| Endpoint | Prefs planas | `kb_stt_url` | Dart | Kotlin `loadConfig` |
| Modelo | Prefs planas | `kb_stt_model` | Dart | Kotlin `loadConfig` |
| Idioma | Prefs planas | `kb_stt_language` | Dart | Kotlin `loadConfig` |
| Legado plano | Prefs planas | `kb_stt_api_key` | NADIE (prohibido escribir) | Migración única que lo traslada a bóveda y lo borra |

Dart y Kotlin usan la MISMA bóveda (flutter_secure_storage con ESP del
lado Dart, EncryptedSharedPreferences `SecureStore` del lado Kotlin: mismo
archivo, misma master key, APIs públicas de AndroidX; sin duplicar cripto).

## Reglas

1. Jamás se loguea la key (guard CI "Sin contenido en Logs").
2. Jamás va al repo ni al backup (`backup_rules.xml` + `data_extraction_rules.xml` excluyen prefs y bóveda).
3. Clave ausente o vacía = fail-fast en el llamador ("Falta la API key" hacia Ajustes), nunca un 401 por red.
4. `kb_stt_api_key` solo se LEE para migrar; el IME también lo migra por su cuenta. Prohibido escribirlo (guard `test_secrets_vault`).
5. La regresión bool-only (solo presencia, sin key real) dejaba "Falta la API key" permanente: NO reintroducir.

## Hilos del dictado (K3)

`start/stop/cancelRecording` bloquean (setup AudioRecord + join ≤2.5 s):
jamás desde el main (usar `BackgroundWork.execute`). `transcribe` no bloquea
(deriva a `BackgroundWork`, callbacks en fondo). Captura serializada con
`audioLock`; único hilo propio legítimo: `VbKeyboardRec` durante la grabación.

## Historia

- K3 nació con espejo plano en prefs para el IME sin keystore.
- SPK-02 (2026-09-07) lo movió a bóveda cifrada; el espejo quedó como legado solo-lectura.
- D7 es el mismo contrato visto desde Ajustes: la app escribe una vez, el IME reutiliza.
