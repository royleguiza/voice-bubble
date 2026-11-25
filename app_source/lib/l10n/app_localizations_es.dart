// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get copyButtonLabel => 'Copiar';

  @override
  String get copyTooltipMessage => 'Copiar al portapapeles';

  @override
  String get copiedToClipboardMessage => 'Texto copiado';

  @override
  String get clipboardFailureMessage => 'No se pudo copiar al portapapeles';

  @override
  String get historyEmptyMessage => 'No hay transcripciones aun';

  @override
  String get noteAudioNotFound => 'Audio no encontrado';

  @override
  String get noteAudioCorrupt => 'Audio dañado; borralo y grabalo de nuevo';

  @override
  String get noteAudioChip => 'Audio';

  @override
  String get noteUntitled => 'Sin título';

  @override
  String get noteCopyTooltip => 'Copiar texto';

  @override
  String get noteCardHint => 'Mantené presionado para más acciones';

  @override
  String get recordingStatusRecording => 'Grabando...';

  @override
  String get recordingStatusProcessing => 'Procesando...';

  @override
  String get recordingStatusError => 'Error, toca para reintentar';

  @override
  String get recordingStatusReady => 'Listo para transcribir';

  @override
  String islandMockupDescription(
      String cx, String top, String width, String height, String side) {
    return 'Maqueta de la isla: centro a $cx píxeles del borde izquierdo, borde superior a $top píxeles, $width de ancho por $height de alto. Micrófono a la $side.';
  }

  @override
  String get islandMicLeft => 'izquierda';

  @override
  String get islandMicRight => 'derecha';

  @override
  String get noteAudioStop => 'Detener audio';

  @override
  String get noteAudioPlay => 'Escuchar audio';

  @override
  String noteAudioPlayWithDuration(String duration) {
    return 'Escuchar audio, $duration';
  }

  @override
  String noteCardSemantics(String title) {
    return 'Nota: $title';
  }

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get homeTabNotes => 'Notas';

  @override
  String get homeTabHistory => 'Historial';

  @override
  String get homeSearchClear => 'Borrar búsqueda';

  @override
  String get noteActionOpen => 'Abrir y editar';

  @override
  String get noteActionCopy => 'Copiar texto';

  @override
  String get noteActionDeleteAudio => 'Borrar audio, conservar texto';

  @override
  String get noteActionDelete => 'Eliminar nota';

  @override
  String get recordStop => 'Detener grabación';

  @override
  String get recordTranscribing => 'Transcribiendo';

  @override
  String get recordHoldToRecord => 'Mantené para grabar';

  @override
  String get recordStart => 'Iniciar grabación';

  @override
  String get recordDiscard => 'Descartar grabación';

  @override
  String pendingAgoMinutes(String n) {
    return 'hace ${n}m';
  }

  @override
  String pendingAgoHours(String n) {
    return 'hace ${n}h';
  }

  @override
  String get pendingYesterday => 'ayer';

  @override
  String pendingAgoDays(String n) {
    return 'hace ${n}d';
  }

  @override
  String pendingSemantics(String when) {
    return 'Audio sin transcribir, $when';
  }

  @override
  String get pendingTitle => 'Audio sin transcribir';

  @override
  String get pendingUnplayable => 'No se pudo reproducir este audio';

  @override
  String get pendingTranscribe => 'Transcribir';

  @override
  String get pendingDiscard => 'Descartar audio';

  @override
  String get pendingPause => 'Pausar';

  @override
  String get pendingPlay => 'Escuchar audio';

  @override
  String get pendingClosePlayer => 'Cerrar reproductor';

  @override
  String get unitPx => 'px';

  @override
  String get unitPxSpoken => 'píxeles';

  @override
  String get credentialsDeleteTitle => 'Borrar clave';

  @override
  String credentialsDeleteConfirm(String name) {
    return '¿Borrar \"$name\"? No se puede deshacer.';
  }

  @override
  String get credentialsDeleteButton => 'Borrar';

  @override
  String get credentialsShowUserFooter =>
      'Junto al nombre, en la lista del teclado.';

  @override
  String get credentialsShowUser => 'Mostrar usuario';

  @override
  String get credentialsEmptyTitle => 'Sin claves guardadas';

  @override
  String get credentialsEmptyMessage =>
      'Guardá usuario y contraseña para rellenarlos desde la llave del teclado.';

  @override
  String get credentialsAdd => 'Agregar clave';

  @override
  String get credentialsSavedHeader => 'Guardadas';

  @override
  String credentialsCountFooter(String count, String max) {
    return '$count de $max · La contraseña nunca se muestra.';
  }

  @override
  String credentialsDeleteNamed(String name) {
    return 'Borrar $name';
  }

  @override
  String get credentialsFormError =>
      'Revisá los campos: nombre y usuario no pueden quedar vacíos.';

  @override
  String get credentialsNewTitle => 'Nueva clave';

  @override
  String get credentialsFieldName => 'Nombre';

  @override
  String get credentialsFieldNameHint => 'Ej. Banco';

  @override
  String get credentialsFieldUser => 'Usuario';

  @override
  String get credentialsFieldUserHint => 'Usuario o email';

  @override
  String get credentialsFieldPassword => 'Contraseña';

  @override
  String get credentialsFieldPasswordHint =>
      'Solo se escribe, nunca se muestra';

  @override
  String get credentialsFormHint =>
      'Se guarda cifrada. El teclado la rellena solo en campos de contraseña.';

  @override
  String get islandTitle => 'Ajustar isla';

  @override
  String get islandNeedsPointer =>
      'La isla necesita Orison Puntero activo: sin él se ve como burbuja y estos ajustes no se notan.';

  @override
  String get islandNeedsBar =>
      'Encendé la barra flotante para ver la isla en tu pantalla.';

  @override
  String get islandPositionHeader => 'Posición';

  @override
  String get islandPositionFooter =>
      'Horizontal: el centro de la isla. Vertical: su borde superior. En píxeles de la pantalla completa.';

  @override
  String get islandPositionX => 'Posición horizontal';

  @override
  String get islandPixelLeft => 'Un píxel a la izquierda';

  @override
  String get islandPixelRight => 'Un píxel a la derecha';

  @override
  String get islandPositionY => 'Posición vertical';

  @override
  String get islandPixelUp => 'Un píxel hacia arriba';

  @override
  String get islandPixelDown => 'Un píxel hacia abajo';

  @override
  String get islandSizeHeader => 'Tamaño en reposo';

  @override
  String get islandSizeFooter => 'Al grabar, la isla se agranda sola.';

  @override
  String get islandWidth => 'Ancho';

  @override
  String get islandNarrower => 'Un píxel más angosta';

  @override
  String get islandWider => 'Un píxel más ancha';

  @override
  String get islandHeight => 'Alto';

  @override
  String get islandShorter => 'Un píxel más baja';

  @override
  String get islandTaller => 'Un píxel más alta';

  @override
  String get islandSideFooter => 'El puntero va del otro lado.';

  @override
  String get islandSideTitle => 'Lado del micrófono';

  @override
  String get islandSideLeft => 'Izquierda';

  @override
  String get islandSideRight => 'Derecha';

  @override
  String get islandCenterTop => 'Centrar arriba';

  @override
  String get islandReset => 'Restablecer';

  @override
  String get noteEditorWriteFirst => 'Escribe o dicta una nota primero';

  @override
  String noteEditorUnexpectedError(String error) {
    return 'Error inesperado: $error';
  }

  @override
  String get noteEditorAiErrorTitle => 'Error de IA';

  @override
  String get noteEditorClose => 'Cerrar';

  @override
  String get noteEditorAiTitleSuggested => 'Título sugerido';

  @override
  String get noteEditorAiSummaryTitle => 'Resumen de la nota';

  @override
  String get noteEditorDiscard => 'Descartar';

  @override
  String get noteEditorReplace => 'Reemplazar';

  @override
  String get noteEditorBodyRequired => 'Cuerpo requerido';

  @override
  String get noteEditorLimitOrError => 'Limite alcanzado o error';

  @override
  String get noteEditorClipboardEmpty => 'El portapapeles está vacío';

  @override
  String get noteEditorNothingToCopy => 'Sin contenido para copiar';

  @override
  String get noteEditorDelete => 'Eliminar nota';

  @override
  String get noteEditorDeleteWithAudio =>
      'Se borrarán el texto y el audio. No se puede deshacer.';

  @override
  String get noteEditorDeleteTextOnly => 'Esta acción no se puede deshacer.';

  @override
  String get noteEditorDeleteConfirm => 'Eliminar';

  @override
  String get noteEditorNewNote => 'Nueva nota';

  @override
  String noteEditorMetaGroupTime(String group, String time) {
    return '$group, $time';
  }

  @override
  String get noteEditorTitleLabel => 'Título';

  @override
  String get noteEditorAiTitleButton => 'Generar título con IA';

  @override
  String get noteEditorBodyHint => 'Escribí o pegá el texto de la nota';

  @override
  String get commonBack => 'Volver';

  @override
  String get noteEditorPaste => 'Pegar';

  @override
  String get noteEditorCopy => 'Copiar texto';

  @override
  String get noteEditorAiSummarize => 'Resumir con IA';

  @override
  String get snippetSaveFailed => 'No se pudo guardar el snippet.';

  @override
  String snippetSaveFailedLimit(String max) {
    return 'No se pudo guardar el snippet: Límite de $max snippets alcanzado o datos temporales no legibles.';
  }

  @override
  String get snippetColorBlue => 'azul';

  @override
  String get snippetColorGreen => 'verde';

  @override
  String get snippetColorRed => 'rojo';

  @override
  String get snippetColorOrange => 'naranja';

  @override
  String get snippetColorViolet => 'violeta';

  @override
  String get snippetColorGray => 'gris';

  @override
  String get snippetDelete => 'Eliminar snippet';

  @override
  String snippetDeleteConfirm(String name) {
    return '¿Eliminar \"$name\"? Esta acción no se puede deshacer.';
  }

  @override
  String get snippetDeleteButton => 'Eliminar';

  @override
  String get snippetsEmptyTitle => 'Sin snippets';

  @override
  String get snippetsEmptyMessage =>
      'Guardá textos que usás seguido y pegalos con un toque desde el teclado.';

  @override
  String get snippetsCreate => 'Crear snippet';

  @override
  String snippetsNoResults(String query) {
    return 'Sin resultados para \"$query\".';
  }

  @override
  String snippetsCountFooter(String count, String max) {
    return '$count de $max · Se insertan con un toque desde el teclado.';
  }

  @override
  String get snippetsReorderDone => 'Listo';

  @override
  String get snippetsReorder => 'Ordenar';

  @override
  String get snippetsSearchHint => 'Buscar';

  @override
  String snippetRowSemantics(String name, String preview) {
    return '$name. $preview';
  }

  @override
  String snippetMoveUp(String name) {
    return 'Subir $name';
  }

  @override
  String snippetMoveDown(String name) {
    return 'Bajar $name';
  }

  @override
  String get snippetNameRequired => 'El nombre es obligatorio';

  @override
  String snippetMaxChars(String max) {
    return 'Máximo $max caracteres';
  }

  @override
  String get snippetSheetEdit => 'Editar snippet';

  @override
  String get snippetSheetNew => 'Nuevo snippet';

  @override
  String get snippetFieldName => 'Nombre';

  @override
  String get snippetFieldNameHint => 'Ej. Firma';

  @override
  String get snippetFieldText => 'Texto';

  @override
  String get snippetFieldTextHint => 'Lo que se va a insertar';

  @override
  String snippetContentCounter(String length, String max) {
    return '$length / $max';
  }

  @override
  String get snippetColorLabel => 'Color';

  @override
  String get snippetColorNone => 'Sin color';

  @override
  String get homeStatusRelease => 'Soltá para terminar';

  @override
  String get homeStatusTranscribing => 'Transcribiendo…';

  @override
  String get homeStatusError => 'Error, toca para reintentar';

  @override
  String homeRecordStartError(String error) {
    return 'Error al iniciar grabación: $error';
  }

  @override
  String get homeNoteSaved => 'Nota guardada';

  @override
  String homeNoteNotSavedFull(String max) {
    return 'Nota no guardada: llegaste a $max notas. El texto quedó copiado y en Historial.';
  }

  @override
  String get homeAudioNotKept =>
      'No se pudo conservar el audio. El texto quedó en Historial.';

  @override
  String get homeNoteNotSavedTextKept =>
      'Nota no guardada; el texto quedó en Historial';

  @override
  String homeError(String error) {
    return 'Error: $error';
  }

  @override
  String get homeRetry => 'Reintentar';

  @override
  String get homeOfflineAudioSaved => 'Sin conexión · audio guardado en Notas';

  @override
  String get homePendingAudioGone => 'El audio pendiente ya no está disponible';

  @override
  String get homeAudioNotKeptShort => 'No se pudo conservar el audio';

  @override
  String get homeNoteNotSavedAudioKept =>
      'Nota no guardada; el audio se conserva';

  @override
  String get homeNoteSavedAudioPending =>
      'Nota guardada; el audio queda pendiente';

  @override
  String get homeApiKeyMissing => 'Falta la API key. Configurala en Ajustes.';

  @override
  String get homeStillOffline => 'Sigue sin red. El audio queda pendiente.';

  @override
  String get homeDiscardAudioTitle => 'Descartar audio';

  @override
  String get homeDiscardAudioMessage =>
      'Se borrará el audio sin transcribir. Esta acción no se puede deshacer.';

  @override
  String get homeDiscardConfirm => 'Descartar';

  @override
  String get homeDeleteAudioTitle => 'Borrar audio';

  @override
  String get homeDeleteAudioMessage =>
      'Se borrará el audio original. La transcripción queda.';

  @override
  String get homeNoteDeleted => 'Nota eliminada';

  @override
  String get homeNoteDeleteFailed => 'No se pudo eliminar la nota';

  @override
  String get homeSettingsTooltip => 'Configuración';

  @override
  String get homeSearchNotesEmpty => 'Buscar';

  @override
  String homeSearchNotes(String count) {
    return 'Buscar en $count notas';
  }

  @override
  String get homeSearchHistory => 'Buscar en el historial';

  @override
  String get homeNotesLoading => 'Cargando notas…';

  @override
  String get homeNotesUnavailable => 'Notas no disponibles';

  @override
  String get homeNotesUnavailableMessage =>
      'No se pudo leer el estado de las notas';

  @override
  String get homeEmptyNotesTitle => 'Tu primera nota';

  @override
  String get homeEmptyNotesHold =>
      'Mantené la burbuja y hablá.\nLo que digas queda escrito acá.';

  @override
  String get homeEmptyNotesTap =>
      'Tocá la burbuja y hablá.\nLo que digas queda escrito acá.';

  @override
  String get homeNoResultsTitle => 'Sin resultados';

  @override
  String homeNoResultsMessage(String query) {
    return 'Nada coincide con “$query”.';
  }

  @override
  String homePendingHeader(String count) {
    return 'Pendientes · $count';
  }

  @override
  String get homePendingInfo =>
      'Sin transcripción local todavía: el audio se guarda en el teléfono y solo sale a la nube cuando tocas Transcribir.';

  @override
  String get homePendingQueueUnavailable => 'Cola no disponible';

  @override
  String homeHistoryFooter(String max) {
    return 'Las últimas $max transcripciones de la app, la burbuja y el teclado. Las más viejas se borran solas.';
  }

  @override
  String get settingsKeepOneTool => 'Dejá al menos una herramienta';

  @override
  String get settingsPointerNeedsCompanion =>
      'Para hacer clic en otras apps, activá Orison Puntero en Trackpad';

  @override
  String get settingsPointerCompanionTitle => 'Orison Puntero';

  @override
  String get settingsPointerCompanionMessage =>
      'Es una app chica que hace los clics del puntero en otras apps. Se descarga junto con Orison, en el mismo lugar de GitHub. Instalala y volvé acá para activarla.';

  @override
  String get settingsPointerCompanionOk => 'Entendido';

  @override
  String get settingsOverlayGranted => 'Permiso de superposición concedido';

  @override
  String get settingsOverlayTitle => 'Permiso de superposición';

  @override
  String get settingsOverlayMessage =>
      'Para mostrar la burbuja sobre otras apps, Orison necesita el permiso de mostrar sobre otras aplicaciones.';

  @override
  String get settingsOverlayConfigure => 'Configurar';

  @override
  String get settingsBubbleStartFailed =>
      'No se pudo activar la burbuja flotante';

  @override
  String get settingsTranslateAiTitle => '¿Traducir con IA?';

  @override
  String settingsTranslateAiMessage(String name) {
    return 'Cuando traduzcas, el texto seleccionado o dictado se va a mandar a $name (el proveedor de «Título y resumen con») para traducirlo. Orison no lo guarda. Nunca se usa en campos de contraseña.\n\nPodés volver a «En el teléfono» cuando quieras.';
  }

  @override
  String get settingsTranslateAiAuthorize => 'Autorizar';

  @override
  String get settingsKeyPasteToContinue => 'Pegá tu clave para continuar.';

  @override
  String get settingsKeyIncomplete =>
      'Parece incompleta: revisá que la copiaste entera.';

  @override
  String get settingsGroqKeyPrefix => 'Las claves de Groq empiezan con gsk_.';

  @override
  String get settingsKeySaveFailed => 'No se pudo guardar la API key';

  @override
  String get settingsKeySaved => 'Clave guardada';

  @override
  String get settingsGoogleKeyPaste =>
      'Pegá tu clave de Google AI Studio para continuar.';

  @override
  String get settingsGoogleKeySaved => 'Clave de Google AI guardada';

  @override
  String get settingsGoogleKeyDeleted => 'Clave de Google AI eliminada';

  @override
  String settingsConnected(String name) {
    return 'Conectado con $name';
  }

  @override
  String settingsConnectFailed(String name) {
    return 'No se pudo conectar con $name: revisá la clave';
  }

  @override
  String get settingsKeyDeleteFailed => 'No se pudo eliminar la API key';

  @override
  String get settingsKeyDeleted => 'Clave eliminada';

  @override
  String get settingsSnippetsTitle => 'Snippets';

  @override
  String get settingsCredentialsTitle => 'Claves';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsSetupHeader => 'Terminá de configurar';

  @override
  String get settingsSetupFooter =>
      'Con esto ya podés dictar en cualquier app.';

  @override
  String get settingsSetupAddGroqKey => 'Agregar clave de Groq';

  @override
  String get settingsMissing => 'Falta';

  @override
  String get settingsSetupEnableKeyboard => 'Activar el teclado';

  @override
  String get settingsAppSubtitle => 'Dictado con IA';

  @override
  String get settingsNavTranscription => 'Transcripción';

  @override
  String get settingsNoKey => 'Sin clave';

  @override
  String get settingsNavAi => 'Inteligencia artificial';

  @override
  String get settingsAiActive => 'Activa';

  @override
  String get settingsAiHidden => 'Oculta';

  @override
  String get settingsAiOptional => 'Opcional';

  @override
  String get settingsWhereHeader => 'Dónde dictar';

  @override
  String get settingsNavKeyboard => 'Teclado';

  @override
  String get settingsKeyboardActive => 'Activo';

  @override
  String get settingsKeyboardInactive => 'Inactivo';

  @override
  String get settingsNavBubble => 'Barra flotante';

  @override
  String get settingsBubbleOn => 'Activada';

  @override
  String get settingsBubbleOff => 'Apagada';

  @override
  String get settingsNavTrackpad => 'Trackpad';

  @override
  String get settingsTrackpadOn => 'Activado';

  @override
  String get settingsTrackpadOff => 'Apagado';

  @override
  String get settingsContentHeader => 'Tu contenido';

  @override
  String get settingsNavNotes => 'Notas y widgets';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsThemeAuto => 'Automática';

  @override
  String get settingsThemeLight => 'Clara';

  @override
  String get settingsThemeDark => 'Oscura';

  @override
  String get settingsAboutTitle => 'Acerca de';

  @override
  String get settingsAboutTagline => 'Teclado de voz y notas con IA.';

  @override
  String get settingsAboutPrivacy =>
      'Sin analytics ni telemetría. El audio sale del teléfono solo cuando dictás, y el teclado nunca guarda lo que escribís.';

  @override
  String get settingsAboutVersion => 'Versión';

  @override
  String get settingsAboutEngine => 'Motor';

  @override
  String get settingsAboutChannelErrors => 'Errores de canal';

  @override
  String get settingsAiProviderGroqHint =>
      'Groq: rápido y gratis, con la misma clave de la transcripción.';

  @override
  String get settingsAiProviderGroqNoKey =>
      'Groq: rápido y gratis, con la misma clave de la transcripción. Falta la clave de Groq (Ajustes › Transcripción).';

  @override
  String get settingsAiProviderGoogleHint =>
      'Google: necesita su propia clave (abajo).';

  @override
  String get settingsAiProviderGoogleNoKey =>
      'Google: necesita su propia clave (abajo). Mientras no la cargues, se usa Groq.';

  @override
  String get settingsTranslateFooterAi =>
      'Botón «Traducir» del teclado: con texto seleccionado lo traduce; sin selección, el próximo dictado sale traducido. Toque largo: deshacer. Con IA: el texto se manda al proveedor de arriba para traducirlo. Nunca en campos de contraseña.';

  @override
  String get settingsTranslateFooterLocal =>
      'Botón «Traducir» del teclado: con texto seleccionado lo traduce; sin selección, el próximo dictado sale traducido. Toque largo: deshacer. En el teléfono: el texto no sale del teléfono; la primera vez baja el idioma (unos 30 MB) y después traduce sin internet. Nunca en campos de contraseña.';

  @override
  String get settingsApiKeyHeader => 'Clave de API';

  @override
  String get settingsApiKeyFooter =>
      'Se guarda cifrada en este teléfono. La conseguís gratis en console.groq.com.';

  @override
  String get settingsAdd => 'Agregar';

  @override
  String get settingsRecordingHeader => 'Grabación';

  @override
  String get settingsRecordHoldFooter =>
      'Mantené presionado mientras hablás y soltá para transcribir.';

  @override
  String get settingsRecordTapFooter =>
      'Tocá para empezar y otra vez para transcribir.';

  @override
  String get settingsRecordButton => 'Botón de grabar';

  @override
  String get settingsRecordTap => 'Tocar';

  @override
  String get settingsRecordHold => 'Mantener';

  @override
  String get settingsEngineHeader => 'Motor';

  @override
  String get settingsEnginePreciseFooter =>
      'Preciso: menos errores y mejor puntuación, apenas más lento. El audio sale del teléfono solo cuando dictás.';

  @override
  String get settingsEngineFastFooter =>
      'Rápido: el de menor espera. El audio sale del teléfono solo cuando dictás.';

  @override
  String get settingsModel => 'Modelo';

  @override
  String get settingsModelFast => 'Rápido';

  @override
  String get settingsModelPrecise => 'Preciso';

  @override
  String get settingsAiProviderHeader => 'Proveedor';

  @override
  String get settingsAiProviderTitle => 'Título y resumen con';

  @override
  String get settingsGoogleKeyHeader => 'Clave de Google';

  @override
  String get settingsGoogleKeyFooter =>
      'Opcional. La conseguís en aistudio.google.com.';

  @override
  String get settingsAiActionsFooter =>
      'Título y resumen con un toque en el editor de cada nota.';

  @override
  String get settingsAiActionsSwitch => 'Acciones de IA en notas';

  @override
  String get settingsAiTestConnection => 'Probar conexión';

  @override
  String get settingsTranslateHeader => 'Traducción';

  @override
  String get settingsTranslateTo => 'Traducir a';

  @override
  String get settingsTranslateHow => 'Cómo traducir';

  @override
  String get settingsTranslateLocal => 'En el teléfono';

  @override
  String get settingsTranslateLocalDetail => 'Privado';

  @override
  String get settingsTranslateAi => 'Con IA';

  @override
  String get settingsTranslateAiDetail => 'Mejor calidad';

  @override
  String get settingsTranslateDictation =>
      'Traducir siempre el dictado del teclado';

  @override
  String get settingsBubbleFooter =>
      'Dictá y usá el puntero encima de cualquier app. Arrastrala hacia el centro para usarla como burbuja; pegala a un borde para volver a la barra.';

  @override
  String get settingsDockForm => 'Forma';

  @override
  String get settingsDockEdge => 'Barra en el borde';

  @override
  String get settingsDockBubble => 'Burbuja';

  @override
  String get settingsDockIsland => 'Isla';

  @override
  String get settingsDockUnavailable => 'No disponible';

  @override
  String get settingsIslandNeedsFooter =>
      'Necesita Orison Puntero activo: solo un servicio de Accesibilidad puede dibujar sobre la cámara y la barra de estado.';

  @override
  String get settingsToolsHeader => 'Herramientas';

  @override
  String get settingsToolsFooter =>
      'Con una sola herramienta, tocar la burbuja la usa directo.';

  @override
  String get settingsToolMic => 'Micrófono';

  @override
  String get settingsToolPointer => 'Puntero';

  @override
  String get settingsBubbleHistoryFooter =>
      'Mantené presionada la barra o la burbuja para ver lo último que dictaste.';

  @override
  String get settingsBubbleHistory => 'Historial';

  @override
  String get settingsPermissionHeader => 'Permiso';

  @override
  String get settingsPermissionFooter =>
      'Android lo pide para mostrar la barra encima de otras apps.';

  @override
  String get settingsOverlayRow => 'Mostrar sobre otras apps';

  @override
  String get settingsReview => 'Revisar';

  @override
  String get settingsNotesHeader => 'Notas';

  @override
  String get settingsNotesQueueFooter =>
      'Sin red, el audio queda en Notas y lo transcribís cuando vuelva la conexión. Transcribir sin internet: aún no disponible.';

  @override
  String get settingsNotesQueueSwitch => 'Guardar audio sin conexión';

  @override
  String get settingsWidgetHeader => 'Widget de notas';

  @override
  String get commonLeft => 'A la izquierda';

  @override
  String get commonRight => 'A la derecha';

  @override
  String get settingsGroqKeyTitle => 'Clave de Groq';

  @override
  String settingsKeySavedHint(String tail) {
    return 'Guardada: $tail';
  }

  @override
  String get settingsGroqKeyHelp =>
      'Pegala tal cual la copiaste de console.groq.com.';

  @override
  String get settingsGoogleKeyTitle => 'Clave de Google AI';

  @override
  String settingsGoogleKeySavedHint(String tail) {
    return 'Guardada: $tail';
  }

  @override
  String get settingsGoogleKeyHelp =>
      'Pegala tal cual la copiaste de aistudio.google.com.';

  @override
  String get settingsKeyField => 'Clave';

  @override
  String get settingsKeyDelete => 'Eliminar clave';

  @override
  String get translateTargetEn => 'Inglés';

  @override
  String get translateTargetEs => 'Español';

  @override
  String get translateTargetPt => 'Portugués';

  @override
  String get translateTargetFr => 'Francés';

  @override
  String get translateTargetIt => 'Italiano';

  @override
  String get translateTargetDe => 'Alemán';

  @override
  String get keyboardSizeHeader => 'Tamaño';

  @override
  String get keyboardHeight => 'Altura';

  @override
  String get keyboardHeightLow => 'Baja';

  @override
  String get keyboardHeightMedium => 'Media';

  @override
  String get keyboardHeightHigh => 'Alta';

  @override
  String get keyboardHeightVeryHigh => 'Muy alta';

  @override
  String get keyboardSpacing => 'Separación';

  @override
  String get keyboardSpacingCompact => 'Compacta';

  @override
  String get keyboardNormal => 'Normal';

  @override
  String get keyboardSpacingWide => 'Amplia';

  @override
  String get keyboardSpacingMax => 'Máxima';

  @override
  String get keyboardBottomDistance => 'Distancia al borde';

  @override
  String get keyboardBottomNone => 'Ninguna';

  @override
  String get keyboardKeysHeader => 'Teclas';

  @override
  String get keyboardKeysFooter =>
      'Ocultá las que no uses y el teclado gana espacio.';

  @override
  String get keyboardTerminalRow => 'Fila de terminal';

  @override
  String get keyboardCodeKey => 'Tecla de código';

  @override
  String get keyboardLanguageKey => 'Tecla de idioma';

  @override
  String get keyboardCredentialsKey => 'Llave de claves';

  @override
  String get keyboardTypingHeader => 'Escritura';

  @override
  String get keyboardMoveCursor => 'Mover el cursor';

  @override
  String get keyboardCursorHold2dDetail => 'en 2D';

  @override
  String get keyboardCursorSlide => 'Deslizar';

  @override
  String get keyboardCursorSlideDetail => 'lateral';

  @override
  String get keyboardSpacebar => 'Barra espaciadora';

  @override
  String get keyboardAlignCenter => 'Centrada';

  @override
  String get keyboardMicLeft => 'Micrófono a la izquierda';

  @override
  String get keyboardLongPressSymbols => 'Símbolos al mantener';

  @override
  String get keyboardLongPressDelay => 'Espera';

  @override
  String get keyboardDelayShort => 'Corta';

  @override
  String get keyboardDelayLong => 'Larga';

  @override
  String get settingsHapticsSound => 'Vibración y sonido';

  @override
  String get keyboardHapticsOn => 'Activados';

  @override
  String get keyboardHapticsOff => 'Sin vibración';

  @override
  String get keyboardClipboardHeader => 'Portapapeles';

  @override
  String get keyboardClipboardFooter =>
      'Apagado guarda solo texto y ocupa menos memoria.';

  @override
  String get keyboardClipboardImages => 'Guardar imágenes';

  @override
  String get keyboardActiveTitle => 'Orison está activo';

  @override
  String get keyboardActiveSubtitle => 'Es tu teclado en todas las apps.';

  @override
  String get keyboardSwitch => 'Cambiar de teclado';

  @override
  String get keyboardSetupHeader => 'Activalo en dos pasos';

  @override
  String get keyboardSetupFooter =>
      'Al volver de Android, el selector se abre solo.';

  @override
  String get keyboardEnabledTitle => 'Activado en Android';

  @override
  String get keyboardEnabledSubtitle => 'Falta elegirlo como teclado.';

  @override
  String get keyboardStep1 => '1. Activar en Android';

  @override
  String get keyboardStep2 => '2. Elegir Orison';

  @override
  String get keyboardTone1 => 'Tono 1';

  @override
  String get keyboardTone2 => 'Tono 2';

  @override
  String get keyboardTone3 => 'Tono 3';

  @override
  String get keyboardTone4 => 'Tono 4';

  @override
  String get keyboardTypingSub => 'Al escribir';

  @override
  String get keyboardHapticsToggle => 'Vibrar al tocar';

  @override
  String get keyboardIntensity => 'Intensidad';

  @override
  String get keyboardIntensitySharp => 'Nítida';

  @override
  String get keyboardIntensitySharpDetail => 'clic seco';

  @override
  String get keyboardIntensityFirm => 'Firme';

  @override
  String get keyboardIntensityFirmDetail => 'marcada';

  @override
  String get keyboardIntensitySoft => 'Suave';

  @override
  String get keyboardIntensitySoftDetail => 'leve';

  @override
  String get keyboardDictatingHeader => 'Al dictar';

  @override
  String get keyboardDictatingFooter =>
      'Funciona aparte de la vibración de las teclas.';

  @override
  String get keyboardMicVibration => 'Vibración';

  @override
  String get keyboardMicOnStart => 'Al empezar';

  @override
  String get keyboardMicWhileRecording => 'Mientras graba';

  @override
  String get keyboardMicOnPaste => 'Al pegar';

  @override
  String get keyboardMicOnCancel => 'Al cancelar';

  @override
  String get keyboardMicSoundsHeader => 'Sonidos del micrófono';

  @override
  String get keyboardMicSounds => 'Sonidos';

  @override
  String get keyboardMicOnStop => 'Al terminar';

  @override
  String get trackpadPointerActive => 'Activo';

  @override
  String get trackpadPointerEnable => 'Activar';

  @override
  String get trackpadPointerNotInstalled => 'No instalado';

  @override
  String get trackpadRestrictedRow => 'Permitir ajustes restringidos';

  @override
  String get trackpadFooterReady =>
      'Los clics del puntero llegan a cualquier app. No lee la pantalla ni guarda nada.';

  @override
  String get trackpadFooterDisabled =>
      'Activalo en Accesibilidad. Si Android dice «Ajuste restringido», tocá Permitir ajustes restringidos y volvé a intentar.';

  @override
  String get trackpadFooterMissing =>
      'Para hacer clic en otras apps hace falta el complemento Orison Puntero. Sin él, el puntero se mueve pero no hace clic.';

  @override
  String get trackpadOtherAppsHeader => 'Puntero en otras apps';

  @override
  String get trackpadOpenFooter =>
      'Se abre desde la barra flotante. Para cerrarlo, tocá la línea de arriba.';

  @override
  String get trackpadOpenAs => 'Se abre como';

  @override
  String get trackpadOpenPanel => 'Panel abajo';

  @override
  String get trackpadOpenWindow => 'Ventana flotante';

  @override
  String get trackpadAutoReturn => 'Al soltar';

  @override
  String get trackpadStaysOpen => 'Queda abierto';

  @override
  String get trackpadClosesIn5 => 'Se cierra a los 5 s';

  @override
  String get trackpadClosesIn15 => 'Se cierra a los 15 s';

  @override
  String get trackpadClosesIn30 => 'Se cierra a los 30 s';

  @override
  String get trackpadKeyboardHeader => 'En el teclado';

  @override
  String get trackpadKeyboardFooter =>
      'Un puntero dentro del teclado para mover el cursor con precisión.';

  @override
  String get trackpadKeyboardSwitch => 'Trackpad en el teclado';

  @override
  String get trackpadToolbarSwitch => 'Acceso en la barra del teclado';

  @override
  String get trackpadAcceleration => 'Aceleración';

  @override
  String get trackpadAccelDynamic => 'Dinámica';

  @override
  String get trackpadAccelLinear => 'Lineal';

  @override
  String get trackpadAccelPrecision => 'Precisión';

  @override
  String get trackpadShapeArrow => 'Flecha';

  @override
  String get trackpadShapeDot => 'Punto';

  @override
  String get trackpadShapeCross => 'Cruz';

  @override
  String get trackpadClickHeader => 'Clic';

  @override
  String get trackpadTapToClick => 'Tocar para hacer clic';

  @override
  String get trackpadSecondaryClick => 'Clic secundario';

  @override
  String get trackpadTwoFingers => 'Dos dedos';

  @override
  String get trackpadRightButton => 'Botón derecho';

  @override
  String get trackpadButtons => 'Botones';

  @override
  String get trackpadButtonsTop => 'Arriba';

  @override
  String get trackpadButtonsSides => 'A los lados';

  @override
  String get trackpadScrollHeader => 'Desplazamiento';

  @override
  String get trackpadScrollBar => 'Barra de scroll';

  @override
  String get trackpadScrollRight => 'Derecha';

  @override
  String get trackpadScrollLeft => 'Izquierda';

  @override
  String get trackpadScrollHidden => 'Oculta';

  @override
  String get trackpadScrollDirection => 'Dirección';

  @override
  String get trackpadScrollNatural => 'Natural';

  @override
  String get trackpadScrollInverted => 'Invertida';

  @override
  String get trackpadOtherHeader => 'Otros';

  @override
  String get trackpadHaptics => 'Vibración';

  @override
  String get trackpadHapticSubtle => 'Sutil';

  @override
  String get trackpadSpeed => 'Velocidad';

  @override
  String get trackpadSlow => 'Lenta';

  @override
  String trackpadSpeedSemantics(String value) {
    return 'Velocidad $value';
  }

  @override
  String get trackpadFast => 'Rápida';

  @override
  String get dateToday => 'Hoy';

  @override
  String get dateYesterday => 'Ayer';

  @override
  String get dateThisWeek => 'Esta semana';

  @override
  String get dateMonths =>
      'enero,febrero,marzo,abril,mayo,junio,julio,agosto,septiembre,octubre,noviembre,diciembre';

  @override
  String get dateMonthsShort =>
      'ene,feb,mar,abr,may,jun,jul,ago,sep,oct,nov,dic';

  @override
  String dateShort(String day, String month) {
    return '$day $month';
  }

  @override
  String dateShortYear(String day, String month, String year) {
    return '$day $month $year';
  }

  @override
  String dateMonthYear(String month, String year) {
    return '$month $year';
  }

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Del teléfono';

  @override
  String get errSttKeyMissing =>
      'Falta la API key de Groq. Agregala en Ajustes.';

  @override
  String get errAudioNotFound => 'No se encontró el archivo de audio.';

  @override
  String get errAudioTooShort =>
      'El audio es demasiado corto para transcribir.';

  @override
  String get errAudioTooLarge => 'El audio supera el límite de 25 MB.';

  @override
  String errAudioDamaged(String detail) {
    return 'El audio está dañado [$detail] y no se puede transcribir. Grabalo de nuevo.';
  }

  @override
  String get errAudioUnreadable => 'No se pudo leer el audio para subirlo.';

  @override
  String get errSttKeyInvalid =>
      'API key inválida. Revisá tu clave en Ajustes.';

  @override
  String get errSttRateLimit =>
      'Límite de solicitudes alcanzado. Esperá un momento e intentá de nuevo.';

  @override
  String errGroqError(String code, String detail) {
    return 'Error $code de Groq: $detail';
  }

  @override
  String errGroqServer(String code) {
    return 'Error del servidor de Groq ($code). Intentá de nuevo.';
  }

  @override
  String get errInvalidResponse =>
      'Respuesta inválida del servidor. Intentá de nuevo.';

  @override
  String get errEmptyTranscript =>
      'El servidor no devolvió texto para ese audio.';

  @override
  String get errNoInternet => 'Sin conexión a internet.';

  @override
  String get errTimeout =>
      'Tiempo de espera agotado al conectar con el servidor.';

  @override
  String get errUnexpectedTranscribe => 'Error inesperado al transcribir.';

  @override
  String get errMicPermission => 'Permiso de micrófono denegado.';

  @override
  String get errMicBusy => 'El teclado está usando el micrófono.';

  @override
  String get errUploadInFlight =>
      'Ya hay una transcripción en curso. Esperá a que termine.';

  @override
  String get errHistorySaveFailed =>
      'No se pudo guardar la transcripción en el historial (disco lleno o error de almacenamiento).';

  @override
  String get errAiTimeout => 'Tiempo de espera agotado';

  @override
  String get errAiNetwork => 'Error de red. Revisá tu conexión.';

  @override
  String get errAiInvalidResponse => 'Respuesta inválida del modelo';

  @override
  String get errAiEmptyResponse => 'Respuesta vacía del modelo';

  @override
  String errAiKeyInvalid(String provider, String code, String detail) {
    return 'Clave de $provider inválida ($code) $detail';
  }

  @override
  String errAiModelUnavailable(String detail) {
    return 'Modelo no disponible: $detail';
  }

  @override
  String errAiLimit(String provider, String detail) {
    return 'Límite de $provider alcanzado: $detail';
  }

  @override
  String errAiServer(String code, String detail) {
    return 'Error del servidor ($code): $detail';
  }

  @override
  String errAiHttp(String code, String detail) {
    return 'Error $code: $detail';
  }

  @override
  String get errAiTooLong =>
      'La nota es muy larga para Groq gratis (unos 20.000 caracteres como máximo). Para notas largas elegí Google en Ajustes › Inteligencia artificial.';

  @override
  String get settingsSpokenLanguage => 'Idioma en que hablo';

  @override
  String get settingsSpokenLanguageAuto => 'Automático';

  @override
  String get settingsSpokenLanguageAutoFooter =>
      'Automático: Whisper detecta el idioma en cada dictado. Si confunde el idioma, elegí uno fijo.';

  @override
  String get commonOk => 'Listo';

  @override
  String get settingsBackupTitle => 'Copia de seguridad';

  @override
  String get settingsBackupExport => 'Exportar copia';

  @override
  String get settingsBackupExporting => 'Exportando…';

  @override
  String get settingsBackupImport => 'Importar copia';

  @override
  String get settingsBackupImporting => 'Importando…';

  @override
  String get settingsBackupFooter =>
      'Guarda en un archivo .zip tus notas con sus audios, el historial, los snippets, el portapapeles y los ajustes. Las claves de API y las credenciales nunca entran: después de importar vas a tener que cargarlas de nuevo. Importar suma lo que falta y no borra nada de lo que ya tenés.';

  @override
  String settingsBackupExported(int notes, int snippets) {
    String _temp0 = intl.Intl.pluralLogic(
      notes,
      locale: localeName,
      other: '$notes notas',
      one: '1 nota',
    );
    String _temp1 = intl.Intl.pluralLogic(
      snippets,
      locale: localeName,
      other: '$snippets snippets',
      one: '1 snippet',
    );
    return 'Copia guardada: $_temp0 y $_temp1.';
  }

  @override
  String get settingsBackupImportedTitle => 'Copia importada';

  @override
  String settingsBackupImportedNotes(int added, int updated) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added notas nuevas',
      one: '1 nota nueva',
      zero: 'Ninguna nota nueva',
    );
    String _temp1 = intl.Intl.pluralLogic(
      updated,
      locale: localeName,
      other: ' y $updated actualizadas',
      one: ' y 1 actualizada',
      zero: '',
    );
    return '$_temp0$_temp1.';
  }

  @override
  String settingsBackupImportedNotesSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas no entraron',
      one: '1 nota no entró',
    );
    return '$_temp0 porque se llegó al máximo de notas.';
  }

  @override
  String settingsBackupImportedRest(int snippets, int history, int clips) {
    return 'Snippets nuevos: $snippets. Dictados en el historial: $history. Recortes: $clips. Los ajustes quedaron como en la copia.';
  }

  @override
  String get settingsBackupImportedKeys =>
      'Las claves de Groq y Google no viajan en la copia: cargalas en Ajustes si todavía no están.';

  @override
  String get settingsBackupErrorFormat =>
      'Ese archivo no es una copia de Orison.';

  @override
  String get settingsBackupErrorVersion =>
      'La copia es de una versión más nueva de Orison. Actualizá la app y volvé a intentar.';

  @override
  String get settingsBackupErrorBusy =>
      'Las notas están ocupadas en este momento. Probá de nuevo en unos segundos.';

  @override
  String get settingsBackupErrorTooBig =>
      'La copia es demasiado grande para importarla.';

  @override
  String get settingsBackupErrorIo => 'No se pudo leer o guardar el archivo.';
}
