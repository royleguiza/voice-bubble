# Iconos (SPK-15) — tabla única

> Dos lenguajes (Dart Material + 21 `ic_*` nativos) con 3 familias y 5
> tamaños. Regla: una familia, 3 tamaños, cero compensación ad-hoc.

## Dart (Material, familia `rounded`)

| Rol | Tamaño | Const | Uso |
|---|---|---|---|
| Pequeño | 18 | `AppIcons.small` | copiar, nube en listas |
| Mediano | 22 | `AppIcons.medium` | tabs, botones de barra |
| Grande | 28 | `AppIcons.large` | headers de sheets, vacíos |

Excepción: `kRecordIconSize` (42) solo para el botón héroe de grabar.
Prohibido `size:` numérico fuera de 18/22/28 (guard CI "Tokens UI").
`outlined/plain` solo con justificación en el commit.

## Nativo (`res/drawable`, 21 `ic_*` + 10 `kb_*`)

- Teclas: glifos a 16sp (`kb_key_glyph_shift/enter`) salvo puntuación 19sp
  (`kb_key_glyph_punct`: compensación documentada, no sistema nuevo).
- Chips/búsqueda/historial a 48dp mínimo táctil (SPK-16).
- `kb_ic_mic` es el mic definitivo (reemplazo del emoji); `kb_proc_dot`
  la ola de PROCESSING. No agregar `ic_*` sin mapearlo a esta tabla y
  borrar el que reemplaza.
