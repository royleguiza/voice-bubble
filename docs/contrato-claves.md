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
  `groq_api_key` (bóveda, jamás en prefs), `_sttUrlKey` interno va sí porque
  el IME lo lee (ver `docs/contrato-stt.md`).
- Prefijos históricos: `kb_` teclado/trackpad, `vb_` credenciales, `voice_`/`transcriptions` legado Flutter, `bubble_` burbuja. No unificar.
