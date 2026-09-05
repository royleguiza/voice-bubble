# INSTALL.md – Instalación y configuración de VoiceBubble STT

Guía para instalar y dejar operativo VoiceBubble STT (burbuja flotante + teclado con dictado) en un teléfono Android físico.

## 1. Instalación del APK

Los APK se generan automáticamente con **GitHub Actions**; no hay builds locales.

1. Abre el repositorio en GitHub (`royleguiza/voice-bubble`) → pestaña **Actions**.
2. Entra al **run verde más reciente** (check verde junto al nombre del commit).
3. Baja a la sección **Artifacts** y descarga **`voice-bubble-debug-apk-rN`** (donde `N` es el número del run).
   - Los artefactos se conservan **7 días**; después expiran y hay que usar un run más reciente.
4. Descomprime el ZIP descargado: dentro está el archivo `.apk`.
5. En el teléfono, permite instalar apps de orígenes desconocidos para tu navegador o gestor de archivos:
   - Ajustes de Android → Aplicaciones → Acceso especial → Instalar apps desconocidas → concede el permiso al navegador/gestor de archivos que uses.
6. Abre el `.apk` y confirma la instalación. Android mostrará el aviso estándar de fuentes desconocidas (es normal: es un APK debug distribuido fuera de una tienda).

## 2. Activación de la burbuja flotante

La burbuja requiere el permiso especial de superposición (**SYSTEM_ALERT_WINDOW**, "Mostrar sobre otras apps"): Android no lo concede automáticamente.

1. Abre VoiceBubble STT y ve a la pantalla de **Ajustes**.
2. Activa el interruptor de la **burbuja**: la app te llevará al ajuste de sistema "Mostrar sobre otras apps"; concede el permiso a VoiceBubble STT y vuelve.
3. Con el permiso concedido, la burbuja aparece flotando sobre cualquier app:
   - Arrastrable, con snap al borde (o isla/píldora según tu modo de acople).
   - Tocar → graba; tocar de nuevo → detiene y transcribe → pegado híbrido en 3 caminos (prioridad fija): 1) nuestro teclado activo → directo en cursor; 2) otro teclado + accesibilidad + switch propio ON → inyectado en el campo; 3) resto → portapapeles + pegado manual. En el APK actual (pre-HB1) el paso 2 aún no inyecta: deja clipboard + aviso.
4. Mientras el servicio está activo verás su **notificación persistente** (es obligatoria en Android para un servicio en primer plano).

## 2b. Pegado con otro teclado — modo híbrido (DigiWord, Gboard…)

Solo necesario si quieres dictar con la burbuja SIN cambiar a nuestro teclado (a partir de HB2; hoy deja clipboard):

1. En la app VoiceBubble → Ajustes → activa **"Pegar dictados de la burbuja en el campo (otros teclados)"** (opt-in, apagado por defecto; clave `kb_bubble_a11y_inject_enabled`).
2. Concede **Accesibilidad** a VoiceBubble cuando el sistema lo pida (Ajustes de Android → Accesibilidad → VoiceBubble → Activar). Es un interruptor del sistema, independiente de la burbuja y del teclado.
3. Dicta con la burbuja sobre un campo normal (WhatsApp, Gmail, Chrome, Keep): el texto se inyecta solo. Si la app destino lo rechaza, se reintenta con pegado y si no, queda en portapapeles con aviso.
4. Aviso esperado de **Play Protect / sistema**: Android advierte que un servicio de accesibilidad "puede leer la pantalla". En nuestro caso solo se consulta el campo enfocado en el instante de pegar un dictado tuyo: sin monitoreo continuo, sin logs, sin guardar pantalla. La distribución sigue siendo APK directo por GitHub (sideload), no Play Store.
5. **Contraseñas y apps bancarias**: jamás se inyecta ahí por diseño; solo clipboard neutro. DigiWord sigue dueño de tus claves.
6. **Termux**: el terminal no es un campo de texto estándar y la inyección por accesibilidad suele fallar ahí. Para Termux usa nuestro teclado (inserción directa en cursor), es el camino recomendado.

## 2c. Alerta de Play Protect y Ajustes restringidos (leer si aparece un aviso)

1. Al instalar el APK, Play Protect puede mostrar "Aplicación desconocida" o advertir por los permisos sensibles (accesibilidad + overlay + micrófono). Es **esperado**: el APK es debug, firmado por el desarrollador y distribuido fuera de Play, sin verificación de identidad de desarrollador (obligatoria desde septiembre 2026). Si el aviso ofrece "Más detalles → **Instalar de todas formas**", podés continuar; es tu decisión.
2. Si el sistema **bloquea sin opción de continuar**: es la protección mejorada contra fraude de Google (activa en 185 mercados), una decisión automática, no un error de la app. Alternativas: usar la variante sin accesibilidad (cuando exista) o la distribución por Play Store.
3. Tras instalar, Android 13+ exige un paso extra para la Accesibilidad en apps sideload ("Ajustes restringidos"), si no el interruptor sale gris y la **isla exacta + trackpad con clics no funcionan** (la burbuja y el teclado sí):
   - Ajustes → Aplicaciones → VoiceBubble STT → ⋮ (arriba a la derecha) → **Permitir ajustes restringidos** → volver → Accesibilidad → activar VoiceBubble.
4. Nunca desactivar Play Protect para instalar. Si el aviso te incomoda, preferí la variante sin accesibilidad.

## 3. Activación del teclado

1. Ajustes de Android → Sistema → **Métodos de entrada / Manage keyboards** (la ruta exacta varía según fabricante).
2. Activa **VoiceBubble Keyboard**. Android mostrará la advertencia estándar sobre teclados de terceros (confirma si quieres continuar).
3. Selecciónalo como teclado actual: con el campo de texto enfocado, usa el botón selector de teclado de la barra de navegación, o la tarjeta **Teclado VoiceBubble** en los Ajustes de la app (muestra el estado y lleva directo al ajuste del sistema).

**API key (espejo)**: configura tu API key de Groq en la pantalla de **Ajustes de la app**. El teclado la reutiliza automáticamente mediante una copia espejo en las preferencias privadas de la app: no hay que configurarla dos veces. Sin key configurada, la app y el dictado del teclado no pueden transcribir.

## 4. Permisos y justificación

| Permiso | Cuándo interviene | Justificación |
|---|---|---|
| `RECORD_AUDIO` | Al iniciar la primera grabación/dictado | Capturar audio **solo** cuando el usuario inicia explícitamente una transcripción. Nunca en segundo plano por iniciativa propia. |
| `SYSTEM_ALERT_WINDOW` | Al activar la burbuja | Mostrar la burbuja flotante sobre otras apps. |
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MICROPHONE` | Automático (declarados en el manifest) | Mantener la grabación viva como servicio en primer plano, siempre visible vía notificación. |
| `POST_NOTIFICATIONS` | Android 13+ | Mostrar la notificación del servicio mientras graba. |
| `INTERNET` | Automático (declarado en el manifest) | Enviar el audio al motor de transcripción (Groq) únicamente cuando inicias una transcripción. |
| `BIND_ACCESSIBILITY_SERVICE` | Opt-in doble: switch propio (Ajustes) + interruptor del sistema (Accesibilidad) | Solo para inyectar el dictado puntual de la burbuja en el campo enfocado cuando usas OTRO teclado. Sin monitoreo continuo, sin logs, nunca en contraseñas/`FLAG_SECURE`. Sin concederlo, todo sigue funcionando por clipboard. |

Fuera de estos, no hay otros permisos: cero analytics, cero telemetría, y el teclado jamás registra lo tecleado.

## 5. Optimización de batería por fabricante

**Por qué hace falta esto**: varios fabricantes (Xiaomi, Huawei, Oppo, Samsung...) matan agresivamente los servicios en primer plano y las superposiciones de apps de terceros aunque tengan notificación visible. Si no aplicas estos pasos, es habitual que la burbuja desaparezca al cerrar la app o que el dictado se corte. VoiceBubble solo mantiene servicios vivos mientras graba, pero necesita que el sistema no los ejecute de forma anticipada.

### Xiaomi / MIUI

1. Ajustes → Aplicaciones → **VoiceBubble STT** → activa **Autostart** (Inicio automático).
2. En la misma pantalla → Ahorro de batería → **Sin restricciones**.
3. Abra la vista de aplicaciones recientes → toque largo en la tarjeta de VoiceBubble → **bloquear** (icono de candado) para que MIUI no la cierre al limpiar recientes.

### Huawei / EMUI

1. Ajustes → Batería → **Inicio de aplicaciones** → VoiceBubble STT → cambia a administración **Manual**.
2. Activa los tres interruptores: **Permitir inicio automático**, **Actividad secundaria** y **Ejecutar en segundo plano**.

### Oppo / Realme / ColorOS

1. Ajustes → Aplicaciones → VoiceBubble STT → **Consumo de batería** → permite **inicio automático** y **ejecución en segundo plano** ("Permitir" en lugar de "Inteligente").
2. Si existe, desactiva la optimización adaptativa/batería inteligente específica para esta app.

### Samsung / One UI

1. Ajustes → Cuidado del dispositivo → Batería → **Límites de uso en segundo plano**.
2. Quita VoiceBubble STT de **Apps en suspensión profunda** (y verifica que no esté en suspensión).
3. En Aplicaciones → VoiceBubble STT → Batería → selecciona **Sin restricciones**.

### Android genérico (Pixel, Motorola, etc.)

1. Ajustes → Aplicaciones → VoiceBubble STT → Batería → **Sin restricciones** (o desactivar "Optimización de batería").

## 6. Solución de problemas

| Problema | Solución |
|---|---|
| No aparece el artefacto en el run de Actions | Solo los runs **verdes** suben el APK; revisa que el run haya terminado con éxito. Si el run tiene más de 7 días, el artefacto ya expiró: usa el run verde más reciente. |
| El APK no instala | Verifica que concediste "Instalar apps desconocidas" al navegador/gestor de archivos (sección 1), que el ZIP descargó completo y que tu Android sea 9 (API 28) o superior. Reintenta la instalación tras reiniciar el teléfono. |
| La burbuja desaparece al cerrar la app | Tu fabricante está matando el servicio en primer plano. Aplica la **sección 5** (Autostart + sin restricciones de batería + bloqueo en recientes según marca) y vuelve a activar la burbuja desde los Ajustes de la app. |
| El teclado no aparece en el selector | Confirma que está activado en Ajustes → Métodos de entrada (sección 3). Si acabas de instalar, reinicia el teléfono: algunos sistemas tardan en registrar el nuevo IME. |
| El dictado falla sin conexión | El motor es únicamente cloud (Groq): la transcripción **requiere internet** por diseño. Sin red no hay transcripción; cuando vuelva la conexión, reintenta. |
| No pide permiso de micrófono | Probablemente se denegó antes ("no volver a preguntar"). Concede `RECORD_AUDIO` manualmente: Ajustes → Aplicaciones → VoiceBubble STT → Permisos → Micrófono. |
| Play Protect advierte al instalar | Esperado en sideload debug con accesibilidad (§2c): continuar con "Instalar de todas formas" o evaluar la variante sin accesibilidad. |
| El interruptor de Accesibilidad sale gris/bloqueado | Falta "Permitir ajustes restringidos" (§2c paso 3, obligatorio en Android 13+ para sideload). |
| Instalación bloqueada sin opción de continuar | Protección mejorada contra fraude de Google en tu región (§2c paso 2); no es un error de la app. |
| El historial está vacío | Es normal tras instalar o reinstalar: el historial empieza vacío y conserva las últimas **20** transcripciones. Los dictados hechos desde el teclado aparecen al volver a abrir la app (se relee el historial compartido al pasar a primer plano). |

## 7. Requisitos mínimos

- **Android 9 (API 28) o superior** (recomendado Android 12+).
- Conexión a internet para transcribir (motor cloud Groq; el audio viaja solo cuando tú inicias una transcripción).
- Micrófono funcional en el dispositivo.
