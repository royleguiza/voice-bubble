# Plan y Registro de Mejoras — Septiembre 2026

> 📅 **Periodo de Recopilación y Diseño**: 26 de agosto – 1 de septiembre de 2026
> 📌 **Regla Operativa**: CERO cambios de código en `app_source/` o `voice_bubble_stt/`. Solo documentación, diseño de arquitectura y especificación de features.
> 🚀 **Gestión de Git**: Los commits y pushes a este archivo y documentación `.md` están permitidos (los cambios en archivos `.md` están excluidos del CI por `paths-ignore: '*.md'`, y además se usará `[skip ci]` en los mensajes de commit para total seguridad).

---

## 1. Planes Listos para Ejecución (Septiembre 2026)

Estos planes ya fueron analizados y aprobados previamente por el dueño:

1. **Bandeja de Portapapeles (Clipboard Tray)**: [`plan-clipboard.md`](file:///root/projects/activos/voice-bubble/plan-clipboard.md)
   * Captura de clips copiados fuera de la app (opt-in).
   * Tecla `📋` en barra inferior del teclado nativo para insertar clips en cursor.
2. **Ciclar Mayúsculas/Minúsculas con ⇧**: [`plan-ciclar-mayusculas.md`](file:///root/projects/activos/voice-bubble/plan-ciclar-mayusculas.md)
   * Ciclo `minúsculas` → `Mayúscula Inicial` → `MAYÚSCULAS` en texto seleccionado.

---

## 2. Registro de Nuevas Ideas y Propuestas

*(Añadiremos aquí cada idea conforme la vayas proponiendo, organizándola por categoría, impacto y viabilidad técnica)*

### 2.1 Teclado Nativo Kotlin (UX, Gestos, Teclas)
<!-- Espacio para ideas del teclado -->

### 2.2 Transcripción y Motor de Voz (Cloud STT / Whisper)
<!-- Espacio para ideas de dictado y audio -->

### 2.3 App Flutter y Ajustes (Liquid Glass)
<!-- Espacio para ideas de la UI principal, snippets, historial y configuración -->

---

## 3. Plantilla para Detallar Ideas

Cuando una idea sea aprobada para pasar a diseño detallado, se estructurará con:

```markdown
### [MEJ-XX] Título de la Mejora
* **Origen / Necesidad**: ¿Qué problema resuelve o qué comodidad aporta?
* **Comportamiento Esperado**: ¿Cómo interactúa el usuario paso a paso?
* **Impacto Técnico**: ¿Requiere cambios en Kotlin nativo, Flutter Dart o ambos?
* **Privacidad y Recursos**: ¿Respeta las reglas de no almacenar pulsaciones y bajo consumo de RAM?
* **Estado**: [Propuesta | En Diseño | Aprobada | Lista para Sprint Septiembre]
```

---

## 4. Registro de Decisiones y Descartes

| Fecha | Idea | Decisión | Motivo |
|---|---|---|---|
| 2026-08-26 | Creación del archivo | Aprobado | Centralizar lluvia de ideas y planes para el reinicio de CI en Septiembre 2026 |

