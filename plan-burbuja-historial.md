# Plan — Modal de historial de la burbuja clásica (B1–B7)

> **Estado**: ✅ APROBADO POR EL DUEÑO (2026-09-05, validado en lab `laboratorio_ui/burbuja_lab.html` 25/25 + detector limpio).
> **Origen**: pedido del dueño: la burbuja clásica (no la píldora) abre con toque largo una modal de historial idéntica en espíritu a la de la píldora, con morph inteligente desde su punto.
> **Reglas madre**: `AGENTS.md` (privacidad sagrada, anti-patrones §8, lecciones §9), `MODO-LOOP.md`, `design.md` §12.

## 1. Decisiones cerradas (dueño, 2026-09-05)

| # | Decisión | Valor |
|---|---|---|
| D-BH0 | Gesto de apertura | Toque largo (500 ms) en la burbuja. El toque simple siempre graba/detiene: la burbuja nativa no tiene modo mantener (ese modo es del botón in-app), así que el largo está siempre libre |
| D-BH1 | Contenido modal | Sin títulos ni textos: cards + micrófono abajo-der. + rayita inferior siempre abajo |
| D-BH2 | Gestos por card | Toque = pegar de inmediato (commitText o clipboard, siempre posible); largo = expandir; swipe lateral (48 dp) = seleccionar |
| D-BH3 | Copiar-todo | Icon-only abajo-izq., visible solo con 2+ (slot permanente para no descentrar la rayita); une con `\n`, limpia selección |
| D-BH4 | Switch | `bubble_history_enabled` en Ajustes → General → Burbuja, default ON |
| D-BH5 | Teclado abierto | v1: cuadrante sobre pantalla completa + clamp; nudge por IME inset queda follow-up (la modal nunca sale de pantalla) |

## 2. Implementación (nada fuera de esto)

- `BubbleHistoryController.kt` (nuevo): overlay `TYPE_APPLICATION_OVERLAY`, morph 320 ms reversible al origen, cuadrante goLeft/goUp, Reduced Motion por `ANIMATOR_DURATION_SCALE`, cero logs de contenido.
- `FloatingBubbleService.kt`: long-press en burbuja clásica (gate switch + idle), `showBubbleHistory()`, `destroy()` en `onDestroy`, un solo `companion object`.
- Dart: `load/saveBubbleHistoryEnabled` (default true), switch en General, clave en `docs/contract-keys.txt` (paridad verificada por master suite).
- Micrófono unificado por construcción: la modal usa el vector `kb_ic_mic` (mismo que teclado y píldora); la burbuja grabando ya muestra stop + pulso.
- Sin permisos nuevos, sin cambios de manifest, sin tocar dictado/snippets/trackpad/isla.

## 3. Tests

- `test_bubble_history_suite.py` (55 checks, módulo 10 del master): API, cuadrante, gestos, wiring, recursos, privacidad, Dart, paridad.
- Dart: persistencia del switch (`storage_service_test`) + render/toggle (`settings_screen_test`, superficie 4800 intacta).
- CI (`flutter analyze` estricto + `flutter test` + APK) como red final: el Kotlin compila ahí.

## 4. Registro del loop

| Tarjeta | Ronda | Nota | Estado |
|---|---|---|---|
| Implementación directa (sin loop: feature validada en lab) | 1 | Auditoría propia: imports usados, sin `Log`, sin companion duplicado | ✅ local 10/10 suites |

> Última actualización: 2026-09-05 — implementado, pendiente CI tras autorización de push del dueño.
