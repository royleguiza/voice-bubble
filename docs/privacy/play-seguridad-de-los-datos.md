# Play Console · Seguridad de los datos (Orison)

Respuestas listas para copiar en **Contenido de la app › Seguridad de los
datos**. Base: la política de `docs/privacy/index.html` (T4). Revisar si
cambia algo del envío de datos (por ejemplo al sumar GIFs con KLIPY en 1.1).

## Recolección y uso compartido

| Pregunta | Respuesta | Por qué |
|---|---|---|
| ¿La app recolecta o comparte alguno de los tipos de datos del usuario requeridos? | **Sí** | El audio del dictado y el texto de las notas viajan a Groq / Google cuando el usuario lo pide. |
| ¿Todos los datos del usuario recolectados se encriptan en tránsito? | **Sí** | Solo HTTPS (api.groq.com, generativelanguage.googleapis.com). |
| ¿Ofrecen una forma de que los usuarios soliciten la eliminación de sus datos? | **Sí** | Todo vive en el teléfono: borrar desde la app, «Borrar datos» de Android o desinstalar. No hay cuenta ni servidor propio. |

> Nota de Google: los datos que se procesan **de forma efímera** y que el
> desarrollador no guarda pueden declararse como «procesados efímeramente».
> El audio y el texto se mandan con la clave del usuario directo al
> proveedor; Orison no los guarda en ningún servidor.

## Tipos de datos

| Categoría › tipo | ¿Recolectado? | ¿Compartido? | Efímero | Obligatorio | Propósito |
|---|---|---|---|---|---|
| Audio › Grabaciones de voz o sonido | Sí | No* | Sí | Obligatorio para dictar (es la función principal) | Funcionalidad de la app |
| Mensajes de la app › Otro contenido generado por el usuario (texto de notas para título/resumen, texto a traducir con IA) | Sí | No* | Sí | Opcional (el usuario elige usar la IA) | Funcionalidad de la app |
| Información financiera › Historial de compras | No (lo maneja Google Play) | No | — | — | — |
| Ubicación, contactos, identificadores, actividad, salud, fotos | No | No | — | — | — |
| Información y rendimiento de la app (fallas, diagnósticos) | No | No | — | — | — |

\* **Compartido = No** porque, según la definición de Play, enviar datos a un
proveedor de servicios que los procesa en nombre del desarrollador o por
pedido explícito del usuario no cuenta como «compartir». Groq y Google
reciben los datos con la clave del propio usuario y para la función que él
pidió.

## Prácticas de seguridad

- Encriptación en tránsito: **Sí**.
- Eliminación: **Sí** (en el teléfono; sin cuenta).
- Revisión independiente de seguridad: **No**.
- Cumple la Política de Familias: **No aplica** (público 18+, no dirigida a niños).

## Otros formularios relacionados

- **Política de privacidad:** URL pública de `docs/privacy/index.html` (ver T4).
- **Servicio en primer plano «micrófono»:** dictado desde el widget y la
  barra flotante (`WidgetDictationService`, `DockDictationService`) con
  notificación visible; video de 30 s grabado por el dueño.
- **Público objetivo:** mayores de 18. **Anuncios:** no tiene.
- **Acceso a la app:** todo se puede probar con una clave gratis de Groq; para
  la revisión, dar instrucciones de cómo crearla (no hace falta cuenta de
  Orison).
