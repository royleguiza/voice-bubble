# DESIGN.md – Sistema de Diseño VoiceBubble STT

> **Línea de diseño**: **Horizonte** (reemplaza a Liquid Glass desde la fase 0
> del rediseño, rama `horizonte`). Toda la interfaz —app Flutter, teclado
> nativo, burbuja y widget— sigue este sistema en modo claro y oscuro.
> Maqueta de referencia: `laboratorio_ui/horizonte.html`.

Este documento define el lenguaje visual de VoiceBubble STT. Es de lectura obligatoria antes de escribir cualquier UI. Los tokens viven en un único lugar por plataforma:

- Flutter: `app_source/lib/ui/design_tokens.dart` (paleta `kHz*`, `kEmber*`, `kDanger*`… y los nombres históricos `kAccent*`, `kBg*`, `kLabel*` remapeados).
- Nativo (teclado, burbuja, widget): `res/values/colors.xml` + `res/values-night/colors.xml` (paleta `hz_*`; los tokens `kb_*`, `bubble_*`, `dock_*`, `snippet_*` apuntan a ella) y `res/values/dimens.xml`.

---

## 1. Filosofía

El ícono de la app es un agujero negro con un disco de acreción naranja. Horizonte toma de ahí todo el sistema:

- **Superficies sólidas**: fondo, superficie y relleno opacos, separados por una línea de 1 px. Nada de vidrio ni desenfoque.
- **Un solo acento: la brasa** (naranja del disco). Marca la acción primaria, el Enter, el estado grabando y lo activo. Nada más compite con ella.
- **El micrófono es el agujero**: un objeto negro puro con anillo de brasa. Es el único círculo "con peso" de la interfaz.
- **El rojo es solo para borrar**: destructivo y nada más. Grabar ya no es rojo.
- **El contenido manda**: el texto dictado es el protagonista; la interfaz es plana, quieta y legible.

### Principios rectores

1. **Simplicidad radical**: el usuario debe entender la app en 10 segundos (regla de docs/archive/plan.md).
2. **Jerarquía por superficie, no por material**: fondo (bg) < superficie (surf) < relleno (surf2). La profundidad se expresa con la línea y el escalón de color, no con sombras ni transparencias.
3. **Menos es más**: un acento, tres familias tipográficas, tres radios.

---

## 2. Arquitectura de capas en VoiceBubble

```
┌──────────────────────────────────────────────┐
│  CONTROLES                                   │
│  · Micrófono (agujero + anillo brasa)        │
│  · Acción primaria (relleno brasa)           │
│  · Barras / hojas / menús (surf + line)      │
├──────────────────────────────────────────────┤
│  CONTENIDO                                   │
│  · Fondo de la app (bg)                      │
│  · Tarjetas de notas e historial (surf)      │
│  · Texto transcrito (fg)                     │
│  · Formularios de Ajustes (surf + surf2)     │
└──────────────────────────────────────────────┘
```

**Reglas duras:**

- **Prohibido el desenfoque** (`BackdropFilter`, `ImageFilter.blur`, blur de ventana) en la app, el teclado y la burbuja. Única excepción: el **widget** de pantalla de inicio, que flota sobre el fondo de pantalla del usuario y puede conservar translucidez (sin depender de ella para la legibilidad).
- `GlassContainer` conserva su nombre y su API por compatibilidad, pero pinta **surf + borde line de 1 px** (ver §7).
- No apilar superficies del mismo nivel sin línea entre ellas.

---

## 3. Acento, agujero y rojo

| Regla | Detalle |
|---|---|
| **Brasa = acción** | Relleno `ember` con texto/ícono `on-ember`: Enter, botón primario, guardar, tecla de capa activa, estado grabando. |
| **Brasa como texto** | Sobre superficie se usa `ember-t` (cumple contraste); nunca `ember` como color de texto. Estado activo de chip/pestaña: fondo `ember-soft` + texto `ember-t`. |
| **Agujero = micrófono** | Fondo `hole`, glifo `on-hole`, anillo de 1.5–2 px `ember` (con halo opcional). Es el único objeto negro puro. El círculo perfecto queda reservado al agujero y a los botones de ícono. |
| **Rojo = borrar** | `danger` solo para acciones destructivas (eliminar nota, borrar snippet, descartar). Prohibido para grabar, errores de forma o decoración. |
| **Azul = enlace** | `plasma` solo para enlaces/información. El azul dejó de ser acento. |
| **Verde = listo** | `ok` para confirmaciones (copiado, guardado). |

---

## 4. Modo Claro y Modo Oscuro

- **Seguir siempre el modo del sistema.** Excepción vigente firmada por el dueño: selector Sistema/Claro/Oscuro solo-Dart en Ajustes › Acerca (Settings v2).
- Probar siempre: claro, oscuro, y ambos + Aumentar contraste + Reducir transparencia + Reducir movimiento.

### Tokens de color (fuente de verdad)

Prohibido hardcodear colores en widgets o vistas: siempre por token.

| Token | Claro | Oscuro | Flutter | Nativo | Uso |
|---|---|---|---|---|---|
| fondo (bg) | `#EEEEF4` | `#08090E` | `kHzBg*` / `kBgBase*` | `hz_bg` | Fondo de la app |
| superficie (surf) | `#FFFFFF` | `#12141C` | `kHzSurf*` / `kBgElevated*` | `hz_surf` | Tarjetas, hojas, campos |
| relleno (surf2) | `#E3E4ED` | `#1B1E2A` | `kHzSurf2*` / `kFill*` | `hz_surf2` | Buscador, segmentado, botones secundarios |
| línea (line) | `#D5D7E2` | `#262A38` | `kHzLine*` / `kSeparator*` | `hz_line` | Bordes 1 px, separadores |
| texto (fg) | `#10121A` | `#F2F0EC` | `kHzFg*` / `kLabelPrimary*` | `hz_fg` | Texto principal |
| texto 2 (fg2) | `#5C6072` | `#9A9DAB` | `kHzFg2*` / `kLabelSecondary*` | `hz_fg2` | Metadatos, hints |
| brasa (ember) | `#F27A14` | `#FF8A1F` | `kEmber*` / `kAccent*` / `kRecording*` | `hz_ember` | Relleno de acción primaria y grabando |
| brasa texto (ember-t) | `#B84A06` | `#FF9A3D` | `kEmberText*` / `kTintText*` | `hz_ember_t` | Texto/ícono brasa sobre superficie |
| brasa suave (ember-soft) | `#FBE4CF` | `#3A2410` | `kEmberSoft*` | `hz_ember_soft` | Fondo de chip / estado activo |
| sobre brasa (on-ember) | `#1A0E00` | `#1A0E00` | `kOnEmber` | `hz_on_ember` | Texto sobre relleno brasa |
| destello (hot) | `#FFC766` | `#FFC766` | `kHot` / `kWarning` | `hz_hot` | Brillo del disco, avisos intermedios |
| enlace/info (plasma) | `#3557C8` | `#8FB0FF` | `kPlasma*` | `hz_plasma` | Enlaces, información |
| borrar (danger) | `#C8372B` | `#FF6A5C` | `kDanger*` | `hz_danger` | Solo destructivo |
| listo (ok) | `#1F8A4C` | `#5FD38D` | `kOk*` / `kSuccess*` | `hz_ok` | Confirmaciones |
| agujero (hole) | `#05060A` | `#000000` | `kHole*` | `hz_hole` | Micrófono |
| sobre agujero (on-hole) | `#FFE9CF` | `#FFE9CF` | `kOnHole` | `hz_on_hole` | Glifo del micrófono |
| teclado fondo (kb) | `#E3E4ED` | `#0E1016` | `kKb*` | `kb_surface` | Fondo del teclado |
| tecla (key) | `#FFFFFF` | `#1E212D` | `kKey*` | `kb_key_bg` | Tecla normal |
| tecla alt (key2) | `#CDCFDC` | `#151821` | `kKey2*` | `kb_key_bg_alt` | Shift, borrar, capas |

Derivados (no son paleta nueva): terciario = fg2 al 60% (`kLabelTertiary*`, placeholders y glifos deshabilitados); scrim = hole al 60% (`kScrimColor`); texto sobre `danger` = blanco en claro y on-ember en oscuro (`kb_label_on_danger`).

### Contraste verificado (WCAG 2.1, texto ≥ 4.5:1)

| Par | Claro | Oscuro |
|---|---|---|
| fg / bg | 16.17 | 17.48 |
| fg2 / surf | 6.23 | 6.81 |
| ember-t / surf | 5.22 | 8.70 |
| on-ember / ember | 6.84 | 8.05 |
| on-hole / hole | 17.18 | 17.81 |

`ember` sobre superficie clara da 2.77:1: por eso nunca es color de texto ni de ícono fino en claro (usar `ember-t`).

---

## 5. Tipografía

Tres familias empaquetadas (OFL 1.1, sin descargas en runtime): Flutter en `app_source/fonts/` (declaradas en `pubspec.yaml`), nativo en `res/font/` (`inter.xml`, `sora.xml`, `jetbrains_mono.xml`; licencias en `res/raw/ofl_*.txt`).

| Familia | Pesos | Uso | Token |
|---|---|---|---|
| **Sora** | 600, 700 | Títulos (large title, títulos de pantalla y sección, display/headline del tema) | `kFontDisplay` |
| **Inter** | 400, 500, 600 | Lectura: cuerpo, botones, listas. Familia por defecto del tema | `kFontBody` |
| **JetBrains Mono** | 400, 500 | Código, horas, contadores, duraciones, etiquetas de grupo en mayúsculas | `kFontMono` / `kTextMono` |

Escala (tamaños vigentes):

| Estilo | Peso/Tamaño | Uso |
|---|---|---|
| Large Title | Sora 34 bold | Título de Notas / Ajustes |
| Title | Sora 22 bold | Títulos de sección |
| Body | Inter 17 regular | Texto transcrito, ítems |
| Callout | Inter 16 regular | Botones con texto |
| Subhead | Inter 15 regular | Subtítulos |
| Footnote | Inter 13 regular | Notas, versión |
| Caption | Inter 12 regular | Metadatos menores |
| Mono | JetBrains Mono 13 | Horas, contadores, código |

- El texto transcrito es el protagonista: Body, seleccionable, color fg, sin cajas decorativas.
- Cifras que cambian (cronómetro, contadores): monoespaciada o `tabularFigures`.

---

## 6. Forma, espaciado y control

### Radios

| Elemento | Radio | Token |
|---|---|---|
| Tecla | 7 dp | `kRadiusKey` / `kb_key_radius` |
| Tarjeta | 14 dp | `kRadiusCard` |
| Hoja (sheet) | 22 dp | `kRadiusSheet` |
| Agujero y botones de ícono | círculo | — |

Los radios históricos (`kBorderRadius*`, `kSettingsGroupRadius`) siguen vigentes en las pantallas que aún no se rehicieron; cada fase del rediseño los migra a la escala de arriba.

### Controles

- Botón de micrófono: círculo perfecto ≥ 72 dp (`kRecordButtonSize`), agujero + anillo brasa.
- Acción primaria: relleno brasa + texto on-ember. Secundarias: relleno surf2 + texto fg.
- Al tocar: escala sutil (0.96→1.0) sin rebote exagerado; háptico al iniciar/detener grabación.

### Espaciado

- Grid base de 8 pt; padding de pantallas 16–20 pt.
- Filas generosas (≥ 44 dp de alto táctil).

---

## 7. Superficie sólida en Flutter

```dart
// Lo que pinta GlassContainer (nombre histórico, API intacta)
Container(
  decoration: BoxDecoration(
    color: isDark ? kBgElevatedDark : kBgElevatedLight,     // surf
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: isDark ? kGlassBorderDark : kGlassBorderLight, // line
                       width: kSurfaceBorderWidth),          // 1 px
  ),
  child: content,
)
```

Reglas:

1. Nadie arma superficies a mano: `GlassContainer` o tokens.
2. Sin `BackdropFilter` ni `ImageFilter.blur` en `app_source/lib`.
3. Alto contraste: fondo blanco/negro puro y borde fg de 2 px (`kGlassBorderWidthAccessible`). Reducir transparencia: borde de 2 px (la superficie ya es opaca).
4. Sombras solo donde un objeto flota sobre contenido (hojas, menús), cortas y sin color.

---

## 8. Movimiento e interacción

- Transiciones fluidas, morphing entre estados del mismo elemento; nada aparece con cortes secos.
- Duraciones: micro-interacciones 150–250 ms; morphing 350–500 ms.
- Estados: Reposo (agujero) → Grabando (anillo brasa pulsante) → Transcribiendo (puntos) → Resultado.

---

## 9. Accesibilidad (no negociable)

| Preferencia del sistema | Comportamiento esperado |
|---|---|
| **Reducir transparencia** | Superficies ya opacas; borde reforzado a 2 px |
| **Aumentar contraste** | Blanco/negro puro con borde contrastante de 2 px |
| **Reducir movimiento** | Sin rebotes ni pulsos; anillo estático; transiciones directas |

Además:

- Contraste mínimo 4.5:1 en texto (ver tabla §4); 3:1 en íconos y bordes significativos.
- Targets táctiles ≥ 44×44 dp.
- TalkBack: labels semánticos en todos los controles.
- El texto transcrito siempre seleccionable y copiable también desde accesibilidad.

---

## 10. Icono de app

- Agujero negro con disco de acreción brasa y destello (hot). Fondo adaptive negro (`ic_launcher_background`).
- Debe verse bien en claro, oscuro y tinted (`<monochrome>` pendiente).
- La burbuja y el micrófono usan la misma identidad: agujero + anillo brasa.

---

## 11. Checklist de revisión visual (por pantalla)

- [ ] ¿Sin desenfoque ni vidrio? ¿Superficies sólidas con línea de 1 px?
- [ ] ¿Un solo acento (brasa)? ¿El rojo aparece solo en acciones destructivas?
- [ ] ¿El micrófono es el agujero con anillo brasa?
- [ ] ¿Se ve correcto en claro Y oscuro?
- [ ] ¿Textos con contraste suficiente (ember-t, nunca ember, como texto)?
- [ ] ¿Títulos en Sora, lectura en Inter, horas/contadores/código en mono?
- [ ] ¿Radios 7/14/22 y círculo solo para agujero/íconos?
- [ ] ¿Se probó con Reducir transparencia / Aumentar contraste / Reducir movimiento?

---

## 12. Extensión: Modo Teclado (hitos K1–K5)

> El teclado es UI **nativa Kotlin**: estos tokens traducen Horizonte a
> recursos nativos (`res/values/colors.xml` + `dimens.xml`). Rigen las mismas
> reglas de acento (§3), modo del sistema (§4) y accesibilidad (§9). Spec
> funcional completa: `docs/archive/teclado-voice.md`.

### Tokens de color (recursos nativos)

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `kb_surface` | `#FFE3E4ED` (kb) | `#FF0E1016` | Fondo completo del teclado, sólido |
| `kb_key_bg` | `#FFFFFFFF` (key) | `#FF1E212D` | Tecla normal |
| `kb_key_bg_alt` | `#FFCDCFDC` (key2) | `#FF151821` | Shift, backspace, cambiador de capa |
| `kb_key_stroke` | `#FFC3C5D3` | `#FF262A38` | Borde 1 dp de las teclas alt |
| `kb_key_pressed` | `#FFCDCFDC` | `#FF262A38` | Tecla presionada |
| `kb_key_bg_accent` | `@color/hz_ember` `#F27A14` | `#FF8A1F` | Enter y tecla de capa activa (brasa) |
| `kb_accent_pressed` | `#FFD96A0E` | `#FFE5761A` | Brasa presionada |
| `kb_label` | `@color/hz_fg` | `@color/hz_fg` | Glifos de teclas |
| `kb_label_secondary` | `@color/hz_fg2` | `@color/hz_fg2` | Hints de capa superior |
| `kb_label_on_accent` | `@color/hz_on_ember` `#1A0E00` | `#1A0E00` | Texto/glifo sobre brasa (Enter, grabando) |
| `kb_recording` | `@color/hz_ember` | `@color/hz_ember` | Pastilla/anillo del micrófono grabando (**brasa**, ya no rojo) |
| `kb_recording_pressed` | `#FFD96A0E` | `#FFE5761A` | Pastilla grabando presionada |
| `kb_danger` | `@color/hz_danger` `#C8372B` | `#FF6A5C` | Borrar snippet, chip en modo borrado (único rojo) |
| `kb_danger_pressed` | `#FFA82D23` | `#FFE85A4D` | Borrar presionado |
| `kb_label_on_danger` | `#FFFFFFFF` | `#FF1A0E00` | Texto sobre `kb_danger` (≥ 4.5:1 en ambos modos) |

### Paleta de snippets (color por snippet)

Solo **6 ids fijos** (nunca color libre; los ids no cambian). El chip/card usa **fondo teñido ~20%** (`0x33`) + **stroke ~40%** (`alpha: 0.40` / `0x66` en Android nativo y Flutter) del color base; texto sigue `kb_label`. `color` es opcional en el JSON (`null` = sin tinte).

| id | Base claro | Base oscuro |
|---|---|---|
| `azul` | `#3557C8` | `#8FB0FF` |
| `verde` | `#1F8A4C` | `#5FD38D` |
| `rojo` | `#C8372B` | `#FF6A5C` |
| `naranja` | `#D9750F` | `#FFA24A` |
| `violeta` | `#8B4FD0` | `#C79BFF` |
| `gris` | `#7B7E8C` | `#9A9DAB` |

Selectores de color: editor inline del teclado (`SnippetsLayer`) y hoja de Ajustes › Snippets (`snippets_tab.dart`), ambos con las mismas 6 opciones + "Sin color".

### Métricas

| Medida | Valor | Nota |
|---|---|---|
| Altura de tecla | 42–48 dp | 4 filas QWERTY; gap entre teclas 6 dp |
| **Chip de snippet** | **40 dp** + **16 sp bold** | Excepción firmada a 48 dp por densidad/legibilidad (pedido del dueño); respeta perfil de altura |
| **Barra snippet** (`kb_snippet_bar_height`) | **28 dp** | Excepción firmada de diseño para la barra compacta/slim del editor inline de snippets, optimizando espacio vertical |
| **Tecla mini** (`kb_mini_key_height`) | **40 dp** | Excepción firmada de diseño para el modo mini 2 filas (MEJ-12): perfil compacto que escala con el multiplicador de altura |
| Radio de tecla | 7 dp | `kb_key_radius` (Horizonte) |
| Stroke de tecla alt | 1 dp | `kb_key_stroke`; presente también en estado presionado |
| Fila terminal | misma altura que teclas | TAB/ESC/CTRL/ALT/flechas presente en todas las capas; ocultable desde Settings para quien ya tiene teclas propias (ej. Termux) |
| Target táctil mínimo | 44×44 dp | regla §9 innegociable |
| Estado presionado | escala 0.96→1.0 + háptico | sonido de tecla OFF por defecto |

### Tipografía del teclado

Las familias `@font/inter`, `@font/sora` y `@font/jetbrains_mono` están disponibles como recursos. Las vistas del teclado las adoptan en su fase; la monoespaciada es la indicada para la capa de código, la fila terminal, el cronómetro de grabación y la cinta del portapapeles.

### Movimiento

- Cambio de capa (letras ↔ código ↔ snippets): crossfade + slide sutil 150–200 ms.
- Micrófono: anillo brasa pulsante solo mientras graba; procesando = puntos.
- Reduced Motion: crossfades directos sin rebote y anillo estático (igual que §9).

### Reglas específicas del teclado

- **Superficie sólida siempre**: el teclado no usa vidrio ni desenfoque; su fondo es `kb_surface` opaco.
- **Insets obligatorios**: con targetSdk edge-to-edge, la vista del teclado aplica los insets de `navigationBars` + `displayCutout` como padding inferior — la fila inferior nunca queda bajo la barra de gestos ni bajo los controles del sistema (flecha minimizar, selector de IME). Prohibido compensar con porcentajes fijos.
- Claro/oscuro siguen el modo del sistema; nunca toggle manual en el teclado.
- Campos de contraseña: micrófono oculto, snippets deshabilitados, cero sugerencias visuales. La burbuja tampoco inyecta jamás ahí: solo portapapeles neutro (Hito 4 BLOQUEADO 2026-09-05, perfil anti-Play-Protect; spec archivada en `plan-hito4-burbuja-hibrida.md` §6).
- Prohibido por alcance (anti-patrones `docs/archive/teclado-voice.md` §8): temas, emojis, autocorrector predictivo, glide typing, portapapeles multinivel.
- Burbuja (2 caminos vigentes): sin componentes nuevos. El feedback por camino (`Insertado en el campo` / `Copiado al portapapeles`) reutiliza Snackbar Material existente e i18n es/en; Reduced Motion = texto estático sin rebote. El tercer camino híbrido (HB2+, `Pegado` por accesibilidad con tercer teclado) quedó BLOQUEADO 2026-09-05 por perfil anti-Play-Protect: archivado, no vigente (ver `plan-hito4-burbuja-hibrida.md` §6).
