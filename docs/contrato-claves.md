# Contrato de claves puente (SPK-26) — convención congelada

> Las claves NO siguen una convención (`bubble_history_enabled` vs
> `kb_terminal_row_visible` vs `transcriptions` vs `vb_credentials_v1`;
> prefijo `flutter.` solo del lado Kotlin). **Renombrar rompe contrato**
> (prefs persistidas + guards CI), así que se congelan y se documentan.

- Fuente de verdad: `docs/contract-keys.txt` (una clave por línea, ordenada).
- Triángulo verificado en cada push: Kotlin (`flutter.*` en `voice_bubble_stt/android/...`)
  == `contract-keys.txt` == Dart (`StorageService.bridgeKeys`).
  Guards: `test_master_suite.py::test_contract_keys` + job "Contrato de claves del puente" en CI.
- Clave nueva = entrar en los 3 lados el mismo día (Kotlin + contrato + `bridgeKeys`).
  Ejemplo canónico: `kb_clipboard_images_enabled` (SPK-10).
- Claves Dart-only (sin puente) no entran al contrato: `_recordModeKey`,
  `groq_api_key` (bóveda, jamás en prefs). `floating_bubble_enabled` dejó de ser
  Dart-only en la fase 2B: `DockLink` la lee para saber si la barra del complemento
  debe dibujarse (contrato de 69 claves desde T14 del plan de lanzamiento, que suma `kb_emoji_key` (tecla de emojis); 68 desde T10, que suma `kb_top_row_numbers` (números al mantener q…p); 67 desde T6, que sumó `kb_auto_caps` (mayúscula automática); 66 desde la etapa 4 de la Ruta IA, que suma `kb_app_locale`, el idioma de la app que leen `AppLocale.kt` y Flutter; 65 desde la etapa 2, que sumó `kb_ai_notes_provider` y `kb_translate_target/_mode/_dictation`; antes 61: las 55 anteriores + `dock_island_x/_y/_w/_h/_side`
  + `floating_bubble_enabled`). En Kotlin se leen con el literal completo
  (`"flutter.dock_island_x"`…), nunca componiendo el prefijo: así las ve la paridad. En cambio `kb_stt_url/model/
  language` SÍ entran porque el IME los lee (ver `docs/contrato-stt.md`).
- Prefijos históricos: `kb_` teclado/trackpad, `vb_` credenciales, `voice_`/`transcriptions` legado Flutter, `bubble_` burbuja. No unificar.
