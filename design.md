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

- **Prohibido el desenfoque** (`BackdropFilter`, `ImageFilter.blur`, blur de ventana como `setBackgroundBlurRadius`) en la app, el teclado, la burbuja y el widget. Sin excepciones: desde la fase 4 el **widget** también es sólido (decisión del dueño), ver §14.
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
| brasa texto (ember-t) | `#B04706` | `#FF9A3D` | `kEmberText*` / `kTintText*` | `hz_ember_t` | Texto/ícono brasa sobre superficie |
| brasa suave (ember-soft) | `#FBE4CF` | `#3A2410` | `kEmberSoft*` | `hz_ember_soft` | Fondo de chip / estado activo |
| sobre brasa (on-ember) | `#1A0E00` | `#1A0E00` | `kOnEmber` | `hz_on_ember` | Texto sobre relleno brasa |
| destello (hot) | `#FFC766` | `#FFC766` | `kHot` / `kWarning` | `hz_hot` | Brillo del disco, avisos intermedios |
| enlace/info (plasma) | `#3557C8` | `#8FB0FF` | `kPlasma*` | `hz_plasma` | Enlaces, información |
| borrar (danger) | `#C8372B` | `#FF6A5C` | `kDanger*` | `hz_danger` | Solo destructivo |
| listo (ok) | `#1E874A` | `#5FD38D` | `kOk*` / `kSuccess*` | `hz_ok` | Confirmaciones |
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
| ember-t / surf | 5.60 | 8.70 |
| ember-t / ember-soft | 4.56 | 6.91 |
| ok / surf | 4.55 | 9.79 |
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
| Buscador y campo de formulario | 12 dp | `kRadiusField` |
| Agujero y botones de ícono | círculo | — |

`kSettingsGroupRadius` ya vale `kRadiusCard` (14). Burbuja y widget ya usan la escala de arriba (fase 4, §14; el historial flotante usa 18 por nacer de la burbuja). De los tokens Dart históricos, `kBorderRadiusCapsule` y `kBorderRadiusCard` todavía tienen uso en pantallas; el resto de `kBorderRadius*` y los `kGlassShadow*` solo siguen vivos por contratos de tests.

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
- Estados: Reposo (agujero: anillo fino + glifo on-hole) → Grabando (voz viva, ver abajo) → Transcribiendo (arco giratorio + renglones) → Resultado.

### Voz: el micrófono reacciona al volumen

El nivel de entrada real (RMS → dB → 0..1 con piso de ruido, ataque rápido y caída lenta) mueve el agujero. Dos animaciones, mismas reglas en Flutter y nativo (maqueta: `laboratorio_ui/horizonte.html`, `drawA`/`drawC`):

| Animación | Dónde | Grabando | Pensando |
|---|---|---|---|
| **A · Acreción** | Pastilla del teclado y pastilla de dictado de la app | Agujero a la izquierda con anillo cuyo grosor y halo siguen el volumen (destello `hot` con volumen alto); entran por la derecha puntos, rayas y 0/1/{/} en mono que convergen al agujero (más y más rápido cuanto más fuerte; goteo mínimo en silencio), color on-hole → brasa → destello al acercarse | Nada entra; arco con cola gira sobre el anillo y salen renglones hacia la derecha que se frenan y desvanecen |
| **C · Corona** | Burbuja y barra flotante, teclado mini sin pastilla | ~44 espigas radiales cuya longitud sigue el volumen | Arco giratorio |

- Fondo siempre `hole` (también en claro); partículas en on-hole/brasa/destello. **Sin rectángulos de corte recto** sobre la animación:
  - *Cronómetro* (pastilla de la app): mono, 13,5 pt, **centrado en la pastilla completa** (si en anchos mínimos o con letra grande chocara con el agujero o con la ✕, se centra en el espacio libre entre ambos; siempre a ≥ 8 dp del borde máximo del agujero). Lleva detrás una *mini píldora* difuminada: cápsula color `hole` apenas más grande que el texto (8 dp horizontal, 3 dp vertical) cuyo borde se desvanece hacia afuera ~9 dp (cápsulas concéntricas con alfa acumulado precalculado; sin blur ni capas). Las partículas pasan por detrás y se atenúan según la distancia al texto, de modo que el número siempre se lee.
  - *✕ de cancelar*: sin bloque; el extremo derecho es un degradado horizontal de transparente a `hole` (~22 dp) sobre el que va la ✕ (área táctil ≥ 44 dp). Las partículas nacen con fundido de entrada antes del degradado.
  - La geometría (agujero, cronómetro, ✕) sale de una sola fuente (`HoleGeometry`) usada por layout, pintor y simulación.
- **Corte limpio** al pasar de grabando a pensando (y a reposo): se vacían al instante las partículas de la grabación (no terminan de caer) y arranca solo la animación de pensando, como en el teclado nativo.
- **Widget** (RemoteViews, sin vistas propias ni dibujo por cuadro): versión A en `AnimatedVectorDrawable` dentro de un `ProgressBar` indeterminado, por niveles (ver §14).
- Presupuesto: ≤ 60 partículas en pastilla, pool fijo, sin asignaciones por cuadro; el animador se detiene fuera de grabando/pensando o con la vista oculta.
- Reducir movimiento / animaciones del sistema desactivadas: anillo fijo cuyo grosor sigue el volumen, sin partículas, espigas ni arco.

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
| `kb_key_stroke` | `#FFC3C5D3` | `#FF262A38` | Línea inferior de tecla en claro (vía `kb_key_shadow`), borde del swatch "sin color" |
| `kb_key_shadow` | `@color/kb_key_stroke` | `#00000000` | Línea inferior de 1 dp de toda tecla (maqueta: sombra `0 1px 0`); en oscuro sin sombra visible |
| `kb_key_pressed` | `#FFCDCFDC` | `#FF262A38` | Tecla presionada |
| `kb_key_bg_accent` | `@color/hz_ember` `#F27A14` | `#FF8A1F` | Enter y tecla de capa activa (brasa) |
| `kb_accent_pressed` | `#FFD96A0E` | `#FFE5761A` | Brasa presionada |
| `kb_label` | `@color/hz_fg` | `@color/hz_fg` | Glifos de teclas |
| `kb_label_secondary` | `@color/hz_fg2` | `@color/hz_fg2` | Hints de capa superior |
| `kb_label_on_accent` | `@color/hz_on_ember` `#1A0E00` | `#1A0E00` | Texto/glifo sobre brasa (Enter, grabando) |
| `kb_recording` | `@color/hz_ember` | `@color/hz_ember` | Acento grabando (**brasa**, ya no rojo) en burbuja y barra; la pastilla del teclado es `hz_hole` + anillo `hz_ember` (`kb_mic_pill`, §8) |
| `kb_danger` | `@color/hz_danger` `#C8372B` | `#FF6A5C` | Borrar snippet, chip en modo borrado (único rojo) |
| `kb_danger_pressed` | `#FFA82D23` | `#FFE85A4D` | Borrar presionado |
| `kb_label_on_danger` | `#FFFFFFFF` | `#FF1A0E00` | Texto sobre `kb_danger` (≥ 4.5:1 en ambos modos) |

### Paleta de snippets (color por snippet)

Solo **6 ids fijos** (nunca color libre; los ids no cambian). `color` es opcional en el JSON (`null` = sin color).

- **Chip del teclado** (Horizonte fase 2): fondo de tecla normal (`kb_key_bg`), **punto de 6 dp** (`kb_snippet_dot_size`) con el color base (`snippet_base_*`) a la izquierda y nombre en JetBrains Mono medium; sin color = sin punto. En modo editar/borrar, borde punteado brasa/rojo (`kb_chip_edit`/`kb_chip_delete`).
- **Selector de color** (editor inline): círculos sólidos del color base; el elegido lleva un anillo separado por un respiro.
- **Tonos teñidos** (siguen vigentes para la tarjeta de la burbuja y la app): fondo ~20% (`0x33`, `snippet_fill_*`) + stroke ~40% (`alpha: 0.40` / `0x66`, `snippet_stroke_*`) del color base; texto `kb_label`.

| id | Base claro | Base oscuro |
|---|---|---|
| `azul` | `#3557C8` | `#8FB0FF` |
| `verde` | `#1E874A` | `#5FD38D` |
| `rojo` | `#C8372B` | `#FF6A5C` |
| `naranja` | `#D9750F` | `#FFA24A` |
| `violeta` | `#8B4FD0` | `#C79BFF` |
| `gris` | `#7B7E8C` | `#9A9DAB` |

Selectores de color: editor inline del teclado (`SnippetsLayer`) y hoja de Ajustes › Snippets (`snippets_tab.dart`), ambos con las mismas 6 opciones + "Sin color".

### Métricas

| Medida | Valor | Nota |
|---|---|---|
| Altura de tecla | 42–48 dp | 4 filas QWERTY; gap entre teclas 6 dp |
| **Chip de snippet** | **40 dp** + **16 sp** JetBrains Mono medium | Excepción firmada a 48 dp por densidad/legibilidad (pedido del dueño); respeta perfil de altura. Punto de color 6 dp |
| **Barra snippet** (`kb_snippet_bar_height`) | **28 dp** | Excepción firmada de diseño para la barra compacta/slim del editor inline de snippets, optimizando espacio vertical |
| **Tecla mini** (`kb_mini_key_height`) | **40 dp** | Excepción firmada de diseño para el modo mini 2 filas (MEJ-12): perfil compacto que escala con el multiplicador de altura |
| Radio de tecla | 7 dp | `kb_key_radius` (Horizonte) |
| Línea inferior de tecla | 1 dp | `kb_key_shadow` (claro: `kb_key_stroke`; oscuro: transparente) en teclas normales, alt y Enter, también presionadas; sin borde perimetral |
| **Barra de herramientas** | íconos sueltos, target ≥ 44 dp | Sin fondo ni borde, ícono `hz_fg2`; activa (panel abierto) = fondo `hz_ember_soft` + ícono `hz_ember_t`, radio `kb_tool_radius` 10 dp; presionada = `kb_key_pressed` (`hz_surf2` no se distingue de `kb_surface` en claro). Alto táctil = máx(`kb_tool_min_target` 44 dp, micrófono 38 dp + márgenes): la barra no cambia de alto |
| Íconos de la barra | 24 dp, trazo 1.8 | Extremos y uniones redondeados, sin rellenos (paths `P` de la maqueta); achicar = `mini` (contorno atenuado + barra llena), agrandar = `full` (contorno atenuado + grilla y barra) |
| Fila terminal | misma altura que teclas | TAB/ESC/CTRL/ALT/flechas presente en todas las capas; ocultable desde Settings para quien ya tiene teclas propias (ej. Termux) |
| Target táctil mínimo | 44×44 dp | regla §9 innegociable |
| Estado presionado | escala 0.96→1.0 + háptico | sonido de tecla OFF por defecto |

### Tipografía del teclado

Las familias `@font/inter`, `@font/sora` y `@font/jetbrains_mono` están disponibles como recursos (`KbFonts` en `KeyboardSupport.kt`, con respaldo a la del sistema).

- **Inter**: letras, símbolos (semibold si van en negrita), popups de acentos e historial.
- **JetBrains Mono medium**: etiquetas de capa de las teclas alt (`?123`, `ABC`, `ES/EN`, `TAB/ESC/CTRL/ALT`, operadores), nombres de snippet.
- **JetBrains Mono**: contenido de la cinta del portapapeles (etiqueta de tipo en bold con tracking: URL/CODE/IMG en `hz_ember_t`, TXT en `hz_fg2`), comando del editor de snippets, usuario en Claves, cronómetro de grabación.

Paneles: buscador de snippets sobre `kb_key_bg` (dentro del teclado `hz_surf2` coincide con el fondo en claro); +, editar y borrar como íconos sueltos (editar activo en brasa suave, borrar activo en `kb_danger`). «Limpiar libres» del portapapeles es un ícono de tacho al final de la cinta. Micrófono ocupado = el mismo agujero atenuado (alfa 0.5).

### Movimiento

- Cambio de capa (letras ↔ código ↔ snippets): crossfade + slide sutil 150–200 ms.
- Micrófono: reposo = agujero (`hz_hole` + anillo brasa + glifo on-hole); grabando = pastilla A (Acreción) con cronómetro mono y ✕; procesando = A en modo pensando. Vista nativa `HorizonView` (modos `ACCRETION`/`CORONA`, §8).
- Reduced Motion: crossfades directos sin rebote y anillo estático cuyo grosor sigue el volumen (igual que §9).

### Avisos del teclado (cápsula superpuesta)

Los avisos (cambio mini/completo, ciclo de mayúsculas, errores de dictado, conexión perdida) son una **cápsula flotante** y no una fila: se dibujan en un marco que envuelve la raíz del teclado (`StatusLayer`, `noticeHost`), centrada sobre la barra de herramientas y dentro de los límites actuales. **No cambian la altura, las mediciones ni los insets**, no empujan ninguna tecla y fuera de la cápsula los toques llegan al teclado.

- **Aspecto:** 32 dp visibles (fila táctil de 44 dp), radio completo (16 dp si el texto ocupa 2 líneas), padding horizontal 14 dp, ancho según contenido hasta el ancho del teclado − 32 dp, texto en una línea con elipsis (máx. 2). Fondo `hz_hole`, texto `hz_on_hole` en Inter medium 13 sp, borde 1 dp `hz_ember` con alfa bajo.
- **Error:** borde y punto inicial (6 dp) en `kb_danger`. **Con acción** (`Reintentar`/`Retry`): la acción en `hz_ember` semibold con target ≥ 44 dp.
- **Animación:** entrada 160 ms (alfa 0→1 + 6 dp hacia arriba, desaceleración), salida 180 ms (alfa → 0). Un aviso nuevo con otro visible solo cambia el texto con un fundido corto (sin reiniciar la entrada ni apilar vistas). Con las animaciones del sistema desactivadas (`ValueAnimator.areAnimatorsEnabled()`), aparece y desaparece sin movimiento.
- **Duración:** informativo 1,4 s; error 3 s; con acción (o que abre Ajustes) 4 s. Tocar la cápsula fuera de la acción la cierra. Los temporizadores y animaciones se cancelan al reconstruir, ocultar la ventana o destruir el servicio.
- **Accesibilidad:** no toma el foco de escritura; el texto se anuncia a TalkBack (`announceForAccessibility`).

### Pastilla de grabación del teclado (cronómetro y ✕)

La geometría sale de una única fuente, `HorizonView.updateGeometry()`, recalculada con el tamaño real de la pastilla en cada layout (perfiles de altura y modo mini):

- **Cronómetro** en JetBrains Mono 11, **centrado en la pastilla completa**; si no cabe entre el borde máximo del agujero (+ 8 dp) y el inicio sólido de la ✕, se corre dentro de ese espacio libre (o se centra en él si es menor que el texto).
- **Sin rectángulo opaco:** detrás del número, una **mini píldora `hz_hole` difuminada** (degradado radial elíptico, ~9 dp de desvanecido a cada lado, sin blur). Las partículas pasan por detrás y multiplican su alfa por la distancia al centro del cronómetro, así el número siempre se lee.
- **✕ de cancelar:** sin bloque de borde recto; el extremo derecho se resuelve con un degradado horizontal transparente → `hz_hole` de 22 dp bajo la ✕ (área táctil ≥ 44 dp, mismo `contentDescription`). Las partículas nacen con fundido antes de ese degradado.

### Reglas específicas del teclado

- **Superficie sólida siempre**: el teclado no usa vidrio ni desenfoque; su fondo es `kb_surface` opaco.
- **Insets obligatorios**: con targetSdk edge-to-edge, la vista del teclado aplica los insets de `navigationBars` + `displayCutout` como padding inferior — la fila inferior nunca queda bajo la barra de gestos ni bajo los controles del sistema (flecha minimizar, selector de IME). Prohibido compensar con porcentajes fijos.
- Claro/oscuro siguen el modo del sistema; nunca toggle manual en el teclado.
- Campos de contraseña: micrófono oculto, snippets deshabilitados, cero sugerencias visuales. La burbuja tampoco inyecta jamás ahí: solo portapapeles neutro (Hito 4 BLOQUEADO 2026-09-05, perfil anti-Play-Protect; spec archivada en `plan-hito4-burbuja-hibrida.md` §6).
- Prohibido por alcance (anti-patrones `docs/archive/teclado-voice.md` §8): temas, emojis, autocorrector predictivo, glide typing, portapapeles multinivel.
- Burbuja (2 caminos vigentes): sin componentes nuevos. El feedback por camino (`Insertado en el campo` / `Copiado al portapapeles`) reutiliza Snackbar Material existente e i18n es/en; Reduced Motion = texto estático sin rebote. El tercer camino híbrido (HB2+, `Pegado` por accesibilidad con tercer teclado) quedó BLOQUEADO 2026-09-05 por perfil anti-Play-Protect: archivado, no vigente (ver `plan-hito4-burbuja-hibrida.md` §6).

---

## 13. Componentes de la app (Horizonte, fase 3)

Maqueta: `laboratorio_ui/horizonte.html`, bloque «app». Etiqueta de grupo = `kTextGroupLabel` (JetBrains Mono 500, mayúsculas con tracking, fg2); el lector de pantalla lee el texto sin forzar mayúsculas (`semanticsLabel`) salvo en las secciones de Inicio, que ya se anunciaban así.

| Componente | Regla |
|---|---|
| **Inicio** | Título grande Sora 700 (`kTextLargeTitle`). Ajustes = botón de ícono circular sólido (surf + line, sin halo). El agujero de dictar va abajo al centro y la lista se desvanece al color de fondo con un degradado (sin desenfoque). |
| **Pestañas Notas / Historial** | Texto sin caja sobre una línea inferior line: Sora 600, contador en mono; la activa en fg con subrayado brasa de 2 dp (`kHomeTabUnderline`), la otra en fg2. Alto táctil 44 (`kHomeTabHeight`). |
| **Buscador** | Relleno surf2, radio 12, sin borde (foco: borde brasa de 1 px). |
| **Encabezado de grupo** | «HOY», «AYER», «ESTA SEMANA»… con la etiqueta de grupo. |
| **Tarjeta de nota** | surf + line 1 px, radio 14, sin sombra. Título Sora 600 (`kTextCardTitle`), cuerpo 2 líneas en fg2, fila meta: hora en mono, chip de audio (fondo ember-soft, ícono y duración ember-t, duración en mono) y copiar como ícono fg2 a la derecha. La tarjeta de audio pendiente es la misma tarjeta con su estado en ember-t. |
| **Historial** | Agrupado por día (Hoy / Ayer / «6 nov») en la presentación. Filas sueltas sobre el fondo con separador line: hora sola en mono en una columna fija (`kHistoryTimeColumn`), texto Inter, copiar a la derecha. |
| **Editor de nota** | Volver = ícono circular sólido; guardar = círculo brasa con check on-ember (surf2 atenuado sin cambios). Meta en mono + chip de audio, título Sora 700, cuerpo Inter con interlineado 1.6. Barra inferior en pastilla sólida (surf + line): pegar, copiar, IA en ember-t, borrar en danger. |
| **Lista de Ajustes** | Grupos como lista sólida (surf + line, radio 14) con separadores line a todo el ancho. Íconos de línea en fg2 sin pastilla (fg con alto contraste); el valor de la fila en mono a la derecha: ember-t si está encendido/activo, fg2 si está apagado o es neutro. Interruptores en brasa. La fila «VoiceBubble» lleva un agujero chico (hole + anillo brasa + micrófono on-hole). Sin sombras: los menús desplegables son surf + line. |
| **Snippets** | Marca vertical de 3 dp con el color del snippet al borde izquierdo (sin color = sin marca), nombre Inter 600, texto en mono fg2 en una línea; pie con el contador en mono; «Ordenar» como acción de texto ember-t. |
| **Hojas** | Fondo bg, radio superior 22, borde line, agarradera line, sin sombra (el velo las separa). Cerrar = ícono circular sólido; guardar = círculo brasa (atenuado mientras guarda). Campos `.fld`: caja surf + line radio 12, etiqueta mono en mayúsculas arriba y valor abajo (texto de snippet y contraseña en mono). Selector de color: círculos sólidos y anillo solo en el elegido. Eliminar = texto danger, sin caja. |
| **Pantallas vacías** | Sin notas, sin historial, sin claves, sin snippets: `SymbolField` (tres renglones quietos de 0 1 { } [ ] < > · en mono, fg2 al 50 %) sobre el título y la ayuda. Decorativo (fuera de la semántica), sin animación; nunca detrás de una lista con contenido ni en «sin resultados». Tokens y regla completa en §15. |

---

## 14. Widget y burbuja (Horizonte, fase 4)

Maqueta: `laboratorio_ui/horizonte.html`, bloque «widget y burbuja» (Widget · lista, Widget · lectura, Burbuja · historial). Mismas reglas que la app: superficies sólidas, un acento, el micrófono es el agujero. **Sin desenfoque ni translucidez en ningún lado.**

### Widget de notas (RemoteViews)

RemoteViews no admite vistas propias ni dibujo por cuadro: todo es drawable XML (`shape`/`selector`/`animated-vector`) + `ImageView`/`TextView`/`ProgressBar`, y las fuentes van por `android:fontFamily="@font/…"` en el layout (minSdk 28). Nunca `setImageViewBitmap` por cuadro.

| Pieza | Regla | Recurso |
|---|---|---|
| Contenedor (lista y lector) | `hz_bg` sólido, borde 1 dp `hz_line`, radio 22 | `widget_bg` |
| Encabezado | «Notas» Sora 600; contador `15 / 50` y pendientes en mono fg2, sin pastilla | — |
| Tarjeta de nota | La de la app: `hz_surf` + line, radio 14; título Sora 600, cuerpo Inter 2 líneas fg2, fecha mono fg2, marca de audio ember-t | `widget_note_card_bg`, `widget_ic_audio` |
| Audio pendiente | La misma tarjeta con un agujero chico y el estado en ember-t | `widget_hole_bg` |
| «+» | Botón de ícono circular sólido (surf + line), glifo ember-t | `widget_icon_btn_bg` |
| Micrófono | **Agujero**: círculo `hz_hole` con anillo `hz_ember` de 2 dp, glifo on-hole | `widget_hole_bg` |
| Grabando / procesando / guardado | Píldora agujero (`hz_hole` + anillo brasa de 1.5 dp), tiempo en mono on-hole, X de cancelar (danger). A la izquierda, en su propio cuadro de 88 × 44 dp (las partículas nunca pasan sobre el cronómetro ni la X), la **voz animada**: `ProgressBar` indeterminado con un `AnimatedVectorDrawable` en bucle (agujero + 6/11/16 partículas que caen a él, claro → brasa → destello, inicios desfasados). Tres variantes por nivel (goteo / medio / fuerte); el servicio solo alterna la visible con `partiallyUpdateAppWidget` cuando cambia el nivel (histéresis, ≤ ~3 cambios/s, `WidgetVoiceLevel`). Procesando = anillo girando; guardado/pendiente o animaciones del sistema desactivadas = anillo estático. AVD generados por script (fuera del repo) | `widget_rec_bar_bg`, `widget_voice_{low,mid,high,think,static}` |
| Lector | Volver y editar como botones de ícono circulares (44 dp); título Sora 600, fecha mono, cuerpo Inter con interlineado 1.5; abajo copiar · título IA · resumen como botones parejos `hz_surf2` radio 10 (IA en ember-t) | `widget_secondary_bg`, `widget_ic_title` |
| IA: resultado | Primario (Reemplazar, Escuchar y transcribir) en brasa con texto on-ember; secundario (Descartar) surf2 | `widget_primary_bg`, `widget_secondary_bg` |
| Íconos sobre superficie clara | `hz_ember_t` (nunca `kb_key_bg_accent`/ember como glifo fino: 2.77:1 en claro) | — |

### Hoja de edición del widget

Hoja sólida `hz_bg` + line, radio 22, sin sombra (la separa el velo), agarradera `hz_line`. Título («Nueva nota» / «Editar nota» / «Audio sin transcribir») en Sora 600. Campos como en la app: `hz_surf` + line, radio 12, Inter (título semibold). Fila de acciones como botones de ícono parejos (`hz_surf` + line, radio 10): cancelar (fg2), borrar (danger), título IA (ember-t), resumen, copiar y **guardar como único botón brasa** con check on-ember. Diálogos de confirmación: misma hoja; secundario surf2, primario brasa, eliminar danger.

### Burbuja y barra flotante

- Ventana transparente sin blur (`GlassWindow` conserva el nombre); la vista pinta `dock_surface` (`hz_surf`) + borde `dock_line` (`hz_line`) de 1 dp.
- El micrófono (burbuja con una herramienta, burbuja dictando, lugar del micrófono en la barra abierta) es el agujero: disco `hz_hole` con anillo brasa de 2 dp y un `HorizonView` en modo `CORONA` encima, con las fases reposo / grabando / pensando del dictado. El animador se detiene solo con la vista oculta o desacoplada.
- Nivel de voz: el dictado de la burbuja graba en Dart; mientras no exista un puente de nivel Dart → Kotlin la corona recibe nivel 0 (espigas mínimas), sin inventar volumen.
- Las demás herramientas (puntero, concentrador) son íconos fg2; activa (trackpad abierto) = `hz_ember_soft` + `hz_ember_t`; presionada = `hz_surf2`. En el abanico, cada herramienta es un botón circular sólido (el micrófono, un agujero).
- Gestos, arrastre, geometría y tamaños no cambian.

### Historial flotante de la burbuja

Tarjeta sólida `hz_bg` + borde `hz_line`, radio 18 (nace de la burbuja). Título «Historial de transcripciones» / «Snippets» con la etiqueta de grupo (mono 500 en mayúsculas con tracking, fg2). Cada fila: hora en mono fg2 en una columna fija de 44 dp (`HistoryCardView.TIME_COLUMN_DP`), texto Inter fg, copiar como ícono fg2 (target 44 dp) y separador `hz_line`. Selección y copiado: `hz_ember_soft` + borde `hz_ember` (check ember-t); copiar-todo confirmado = círculo brasa con check on-ember. El micrófono del pie es el agujero; la agarradera, una línea `hz_line`.

---

## 15. Arranque y fondos (Horizonte, fase 5)

Maqueta: `laboratorio_ui/horizonte.html`, escena `drawHole` y bloque «arranque» (primer segundo, final, pantalla vacía). Dibujado con código (`CustomPainter`), sin video ni imágenes nuevas.

### Animación de arranque

`app_source/lib/ui/horizon_intro.dart`: `HorizonIntroHost` (en `main()`, `VoiceBubbleApp(showIntro: true)`) monta Inicio y, encima, la capa `HorizonIntro`.

| Regla | Detalle |
|---|---|
| **Fase 1** (`kIntroSwallow`, 700 ms) | Agujero grande (radio 0,13 × lado menor; centro a lo ancho y al 40 % del alto) con disco inclinado (−0,32 rad, órbitas aplastadas al 40 %). Símbolos en espiral: `0 1 { } [ ] < > / ;` y palabras fijas (`voz`, `nota`, `texto`, `ssh`, `tmux`, `dev`, `hola`), nunca contenido del usuario. Lejos: glifo mono en fg (tinta en claro); cerca: brasa; junto al horizonte: trazo corto brasa/destello. La mitad trasera del disco se dibuja antes del agujero y la delantera después; halo elíptico de brasa; borde destello. |
| **Fase 2** (`kIntroLand`, 450 ms) | El agujero se achica y viaja (`easeInOutCubic`) hasta el centro y radio **medidos** del botón de dictar en reposo (`GlobalKey` del lienzo del botón, sin números mágicos); el anillo pasa de destello 1,5 dp a brasa 2 dp por dentro del borde (como el botón), el micrófono on-hole aparece en la segunda mitad, halo y símbolos se apagan sin reaparecer y el fondo de la capa se desvanece mostrando Inicio. El botón real queda tapado mientras el agujero viaja: nunca se ven dos agujeros. El último cuadro es idéntico al botón y la capa se desmonta. |
| **Duración** | 1,15 s en total (≤ 1,2 s). Paso por cuadro acotado a 50 ms: un primer cuadro lento no salta etapas. |
| **Saltear** | Un toque en la fase 1 pasa a la fase 2 acelerada (`kIntroSkipLand`, 200 ms); ese toque no llega a Inicio. En la fase 2 la capa ya no recibe toques. |
| **Cuándo** | Solo en el arranque en frío: una vez por proceso (rotar, volver de recientes o reconstruir el árbol no la repite). Si encima de Inicio se abre otra pantalla (p. ej. una nota pedida por el widget), termina en el acto. Apagada por defecto en `VoiceBubbleApp`: los tests la piden explícitamente. |
| **Reducir movimiento / TalkBack** | `MediaQuery.disableAnimations` o navegación accesible → sin arranque: Inicio directo. |
| **Alto contraste** | Sin halo translúcido; anillo brasa sólido desde el primer cuadro. |
| **Fondo y arranque nativo** | El fondo de la capa es `kHzBg*` (= `hz_bg` = `splash_background` en claro y oscuro), igual que la ventana nativa (`launch_background`, `NormalTheme`, `windowSplashScreenBackground` en Android 12+, que mantiene el ícono del sistema): sin parpadeo ni cambio de fondo al primer cuadro de Flutter. |
| **Presupuesto** | Pool fijo de ≤ 120 partículas (`kIntroMaxParticles`); un solo `AnimationController` que se libera al desmontar; pinceles, colores con opacidad cuantizada, halo y `TextPainter` de glifos cacheados una vez por modo (como mucho `HorizonIntroPainter.textPainterCapacity`); sin `saveLayer`, sin blur; `RepaintBoundary`. Inicio y su carga de datos arrancan en el mismo primer cuadro (la capa no difiere nada). |

### Fondos: campo de símbolos

`SymbolField` (`app_source/lib/ui/symbol_field.dart`): tres renglones quietos de símbolos en mono, fg2 con opacidad por token. Siempre estático, fuera de la semántica y sin recibir toques.

| Dónde | Opacidad | Token |
|---|---|---|
| Pantallas vacías (Notas, Historial, Claves, Snippets) sobre el título y la ayuda, con `kSymbolFieldGap` (14) hasta el texto | 50 % | `kSymbolFieldOpacity` |
| Encabezado de Ajustes, detrás del título grande, a la derecha (`SymbolField.header`) | 22 % | `kSymbolFieldHeaderOpacity` |

Cuerpo 13 (`kSymbolFieldFontSize`). Nunca detrás de una lista con contenido, de un formulario ni en «sin resultados» / «cargando».

