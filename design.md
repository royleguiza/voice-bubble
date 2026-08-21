# DESIGN.md – Sistema de Diseño VoiceBubble STT

> **Línea de diseño**: Apple **Liquid Glass** (introducido en WWDC25 / iOS 26).
> Toda la interfaz de la app —en modo claro y oscuro— sigue este sistema.

Este documento define el lenguaje visual de VoiceBubble STT. Es de lectura obligatoria antes de escribir cualquier UI. Referencias oficiales:

- [HIG – Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Meet Liquid Glass (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/219/)
- [HIG – Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)

---

## 1. Filosofía

Liquid Glass es un **meta-material dinámico** que combina las propiedades ópticas del vidrio con la fluidez del líquido:

- **Translúcido**: refleja y refracta lo que hay detrás.
- **Adaptativo**: cambia según el contenido de fondo, el tamaño del elemento y el modo del sistema.
- **Vivo**: reacciona al tacto con brillos especulares, escala y rebote.
- **Al servicio del contenido**: el vidrio existe para elevar el contenido, no para competir con él.

### Principios rectores

1. **Jerarquía de capas**: hay una capa **funcional** (controles y navegación, hecha de Liquid Glass) que flota por encima de la **capa de contenido**. Nunca se mezclan.
2. **El contenido manda**: el vidrio se adapta al contenido; el contenido nunca se adapta al vidrio.
3. **Simplicidad radical**: el usuario debe entender la app en 10 segundos (regla del plan.md).
4. **Menos es más**: Liquid Glass se usa con moderación, solo en los elementos funcionales más importantes.

---

## 2. Arquitectura de capas en VoiceBubble

```
┌──────────────────────────────────────────────┐
│  CAPA FUNCIONAL (Liquid Glass)               │
│  · Burbuja flotante                          │
│  · Botón principal Grabar/Detener            │
│  · Botón Copiar                              │
│  · Selector Local/Cloud                      │
│  · Barras / sheets / menús                   │
├──────────────────────────────────────────────┤
│  CAPA DE CONTENIDO (materiales estándar)     │
│  · Fondo de la app                           │
│  · Texto transcrito                          │
│  · Lista de historial                        │
│  · Formularios de Settings                   │
└──────────────────────────────────────────────┘
```

**Reglas duras:**

- Liquid Glass **solo** en la capa funcional. Jamás en fondos, tarjetas de historial ni texto de contenido.
- Excepción permitida (según HIG): un control dentro de la capa de contenido puede "encenderse" en Liquid Glass durante la interacción activa (ej.: slider, toggle).
- No apilar vidrio sobre vidrio. Los elementos de vidrio no se contienen ni superponen entre sí salvo que estén agrupados para hacer morphing.

---

## 3. Variantes: Regular vs Clear

| | **Regular** | **Clear** |
|---|---|---|
| Comportamiento | Adaptativo: difumina y ajusta luminosidad del fondo para garantizar legibilidad | Permanentemente muy translúcido, sin adaptación |
| Legibilidad | Siempre legible, cualquier contexto | Requiere capa de atenuación (dimming) |
| Cuándo usarlo | Por defecto: botones, barras, selector de modo, burbuja sobre apps desconocidas | Solo sobre contenido multimedia rico (fotos/video) |
| Mezclar variantes | ❌ Nunca mezclar las dos en una misma pantalla |

**Decisión para VoiceBubble**: usamos **Regular como variante por defecto en toda la app**. La variante Clear queda reservada exclusivamente para la **burbuja flotante cuando flota sobre contenido claramente multimedia**, y solo si se cumplen las 3 condiciones del HIG:

1. Está sobre contenido rico en medios.
2. El dimming (~35% negro si el fondo es claro) no daña la experiencia.
3. El símbolo sobre el vidrio es audaz y brillante.

Si alguna condición falla → burbuja en Regular.

---

## 4. Modo Claro y Modo Oscuro

Liquid Glass **no tiene apariencia fija**: los elementos pequeños (burbuja, botones, chips) **flips automáticos claro ↔ oscuro** según lo que haya detrás. Los elementos grandes (sheets, menús) se adaptan pero **no** hacen flip (sería distraído). Los símbolos/glyphs espejan el comportamiento del vidrio para maximizar contraste.

### Reglas de aparición

- **Seguir siempre el modo del sistema.** Sin toggle de tema dentro de la app (práctica HIG: evitar configuraciones de apariencia por-app). La app debe verse perfecta en claro, en oscuro y en Auto.
- Los elementos pequeños de la capa funcional invierten su estilo según el fondo inmediato, independientemente del modo general.
- Probar siempre: claro, oscuro, y ambos + Increase Contrast + Reduce Transparency.

### Tokens de color (modo claro / modo oscuro)

Definir como pares adaptativos en un único lugar (`lib/ui/theme/`). Prohibido hardcodear colores en widgets.

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `bgBase` | `#F2F2F7` | `#000000` | Fondo de la app (capa contenido) |
| `bgElevated` | `#FFFFFF` | `#1C1C1E` | Superficies elevadas (sheet de settings) |
| `bgSecondary` | `#FFFFFF` | `#2C2C2E` | Tarjetas de historial |
| `labelPrimary` | `#000000` | `#FFFFFF` | Texto principal (contraste ≥ 7:1 ideal, mínimo 4.5:1) |
| `labelSecondary` | `rgba(60,60,67,.6)` | `rgba(235,235,245,.6)` | Texto secundario (timestamps, hints) |
| `labelTertiary` | `rgba(60,60,67,.3)` | `rgba(235,235,245,.3)` | Placeholder, separadores sutiles |
| `separator` | `rgba(60,60,67,.29)` | `rgba(84,84,88,.6)` | Líneas divisorias |
| `tintAccent` | `#007AFF` | `#0A84FF` | Acción primaria (Copiar), links |
| `tintRecord` | `#FF3B30` | `#FF453A` | Estado grabando (único uso semántico del rojo) |
| `glassLight` | blanco ~65% opacidad + blur | — | Material glass en contexto claro |
| `glassDark` | — | negro ~45% opacidad + blur | Material glass en contexto oscuro |

Notas:

- En oscuro existen dos niveles de fondo (**base** y **elevated**) para dar sensación de profundidad al apilar interfaces. Respetarlo: sheet > tarjeta > fondo.
- Los colores de tinte sobre vidrio se renderizan **vibrantes**: el sistema ajusta el tono según el brillo del contenido detrás. Al portarlo a Flutter, simular con opacidades moderadas (ver §7).
- El rojo es **exclusivamente semántico** (grabando). Nada más en la app lleva rojo.

---

## 5. Tipografía

- Fuente del sistema: **SF Pro** en iOS; en Android usar el equivalente más cercano disponible por defecto del sistema (Roboto) o empaquetar SF Pro respetando licencia. Prioridad: look nativo del sistema anfitrión.
- Estilo Apple (large title → caption):

| Estilo | Peso/Tamaño aprox. | Uso en VoiceBubble |
|---|---|---|
| Large Title | 34 bold | Título de pantalla Home ("VoiceBubble") |
| Title | 22 bold | Títulos de sección en Settings |
| Body | 17 regular | Texto transcribio, ítems de historial |
| Callout | 16 regular | Botones con texto |
| Subhead | 15 regular | Timestamps, subtítulo de modo activo |
| Footnote | 13 regular | Notas de permisos, versión |
| Caption | 12 regular | Metadatos menores |

- El texto transcrito es el protagonista: Body grande, seleccionable, color `labelPrimary`, sin cajas decorativas alrededor.

---

## 6. Forma, espaciado y control

### Radios y concéntricidad

- Las curvas de los controles son **concéntricas** con su contenedor (principio hardware-software de Apple).
- Escala de radios: controles pill/cápsula → tarjetas 16–20 px → sheets 24+ px (mayor radio en sheets, ya aumentado en iOS 26).
- El botón principal de grabar: **círculo perfecto**, proporción generosa (≥ 72 px de diámetro).

### Controles

- Forma por defecto de botones: **cápsula**.
- Los controles "cobran vida" al tocarlos: escala sutil (0.96→1.0), rebote tipo spring, shimmer del material.
- El selector Local/Cloud: segmented control estilo iOS 26 — pastillas de vidrio dentro de un contenedor de vidrio con separadores finos.
- Feedback háptico al iniciar/detener grabación (ya previsto en plan.md, Hito 2).

### Espaciado

- Grid base de 8 pt; padding de pantallas 16–20 pt.
- Listas y formularios: altura de fila generosa (estilo iOS 26: más alto y más aireado que antes).
- Dejar "respirar": en estado reposo, el contenido no intersecta los elementos de vidrio (reposicionar o escalar contenido para mantener separación).

---

## 7. Receta Liquid Glass para Flutter

iOS 26 lo resuelve el sistema; en Flutter lo simulamos. Componentes estándar de la receta:

```dart
// Material "glass" (variante Regular, contexto claro)
ClipRRect(
  borderRadius: BorderRadius.circular(radius),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
    child: Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(.45) : Colors.white.withOpacity(.65),
        borderRadius: BorderRadius.circular(radius),
        // borde especular superior: highlight fino
        border: Border.all(color: isDark ? Colors.white.withOpacity(.18) : Colors.white.withOpacity(.55)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? .45 : .12), blurRadius: 24, offset: Offset(0,8))],
      ),
      child: content,
    ),
  ),
)
```

Reglas de implementación:

1. Un único widget `GlassContainer` reutilizable en `lib/ui/theme/`. Nadie arma glass a mano.
2. Blur σ 20–28 para elementos grandes; σ 10–14 para chips pequeños (el vidrio chico es "más claro").
3. Elemento pequeño (≤ 100 pt): puede hacer flip claro/oscuro según luminancia del fondo estimada. Elemento grande: mantener tono estable.
4. Sombra: más difusa y profunda a medida que el elemento crece (simula vidrio más grueso).
5. Highlight: borde de 1 px blanco translúcido (lado superior más intenso) para simular refracción.
6. Animaciones: springs (duración ~350–500 ms). Morphing entre estados del mismo elemento (ej.: botón grabar → detener) con `AnimatedContainer`/`Hero`.
7. Agrupar elementos de vidrio que interactúan (selector de modo + botón copiar en una misma zona) para que compartan adaptación — equivalente Flutter del `GlassEffectContainer`.

---

## 8. Movimiento e interacción

- **Fluidity**: transiciones fluidas, morphing entre estados; nada aparece/desaparece con cortes secos.
- Duraciones: micro-interacciones 150–250 ms; morphing/materiales 350–500 ms; curvas spring (sin overshoot exagerado).
- La burbuja se arrastra con física (inercia leve) y hace snap opcional al borde.
- Estados de la app con feedback visual + háptico: Idle → Grabando (pulso rojo suave) → Transcribiendo (spinner + texto) → Resultado (aparición fluida del texto).

---

## 9. Accesibilidad (no negociable)

El material se adapta automáticamente a estas preferencias del sistema; verificarlas SIEMPRE en testing:

| Preferencia del sistema | Comportamiento esperado |
|---|---|
| **Reducir transparencia** | El vidrio se vuelve escarchado/opaco — aumentar opacidad del fill, reducir blur |
| **Aumentar contraste** | Elementos casi blanco/negro puros con borde contrastante de 1–2 px |
| **Reducir movimiento** | Desactivar rebotes/elasticidad y pulsos; transiciones directas |

Además:

- Contraste mínimo 4.5:1 (ideal 7:1) en texto sobre cualquier material.
- Targets táctiles ≥ 44×44 pt.
- Soporte TalkBack: labels semánticos en todos los controles de la capa funcional.
- El texto transcrito siempre seleccionable y copiable también desde accesibilidad.

---

## 10. Icono de app (Hito 5)

- Diseño **por capas** (fondo, medio, primer plano): formas sólidas simples y semi-translúcidas superpuestas.
- Debe verse bien en las variantes claro, oscuro, tinted y clear.
- Motivo sugerido: micrófono + burbuja (círculo), monocromo, audaz, centrado en la grilla.
- La burbuja flotante usa la misma identidad visual (círculo de vidrio + glifo de mic).

---

## 11. Checklist de revisión visual (por pantalla)

- [ ] ¿La jerarquía funcional/contenido está clara? ¿El vidrio está solo en la capa funcional?
- [ ] ¿Se ve correcto en claro Y oscuro?
- [ ] ¿Los textos tienen contraste suficiente sobre el material?
- [ ] ¿Se probó con Reduce Transparency / Increase Contrast / Reduce Motion?
- [ ] ¿Las esquinas son concéntricas y consistentes?
- [ ] ¿Hay animación fluida en cada cambio de estado (sin cortes)?
- [ ] ¿El elemento más importante de la pantalla es evidente en 1 segundo?
