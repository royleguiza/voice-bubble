import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt')
  ];

  /// No description provided for @copyButtonLabel.
  ///
  /// In es, this message translates to:
  /// **'Copiar'**
  String get copyButtonLabel;

  /// No description provided for @copyTooltipMessage.
  ///
  /// In es, this message translates to:
  /// **'Copiar al portapapeles'**
  String get copyTooltipMessage;

  /// No description provided for @copiedToClipboardMessage.
  ///
  /// In es, this message translates to:
  /// **'Texto copiado'**
  String get copiedToClipboardMessage;

  /// No description provided for @clipboardFailureMessage.
  ///
  /// In es, this message translates to:
  /// **'No se pudo copiar al portapapeles'**
  String get clipboardFailureMessage;

  /// No description provided for @historyEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'No hay transcripciones aun'**
  String get historyEmptyMessage;

  /// No description provided for @noteAudioNotFound.
  ///
  /// In es, this message translates to:
  /// **'Audio no encontrado'**
  String get noteAudioNotFound;

  /// No description provided for @noteAudioCorrupt.
  ///
  /// In es, this message translates to:
  /// **'Audio dañado; borralo y grabalo de nuevo'**
  String get noteAudioCorrupt;

  /// No description provided for @noteAudioChip.
  ///
  /// In es, this message translates to:
  /// **'Audio'**
  String get noteAudioChip;

  /// No description provided for @noteUntitled.
  ///
  /// In es, this message translates to:
  /// **'Sin título'**
  String get noteUntitled;

  /// No description provided for @noteCopyTooltip.
  ///
  /// In es, this message translates to:
  /// **'Copiar texto'**
  String get noteCopyTooltip;

  /// No description provided for @noteCardHint.
  ///
  /// In es, this message translates to:
  /// **'Mantené presionado para más acciones'**
  String get noteCardHint;

  /// No description provided for @recordingStatusRecording.
  ///
  /// In es, this message translates to:
  /// **'Grabando...'**
  String get recordingStatusRecording;

  /// No description provided for @recordingStatusProcessing.
  ///
  /// In es, this message translates to:
  /// **'Procesando...'**
  String get recordingStatusProcessing;

  /// No description provided for @recordingStatusError.
  ///
  /// In es, this message translates to:
  /// **'Error, toca para reintentar'**
  String get recordingStatusError;

  /// No description provided for @recordingStatusReady.
  ///
  /// In es, this message translates to:
  /// **'Listo para transcribir'**
  String get recordingStatusReady;

  /// Lectura de pantalla de la maqueta de la isla
  ///
  /// In es, this message translates to:
  /// **'Maqueta de la isla: centro a {cx} píxeles del borde izquierdo, borde superior a {top} píxeles, {width} de ancho por {height} de alto. Micrófono a la {side}.'**
  String islandMockupDescription(
      String cx, String top, String width, String height, String side);

  /// No description provided for @islandMicLeft.
  ///
  /// In es, this message translates to:
  /// **'izquierda'**
  String get islandMicLeft;

  /// No description provided for @islandMicRight.
  ///
  /// In es, this message translates to:
  /// **'derecha'**
  String get islandMicRight;

  /// No description provided for @noteAudioStop.
  ///
  /// In es, this message translates to:
  /// **'Detener audio'**
  String get noteAudioStop;

  /// No description provided for @noteAudioPlay.
  ///
  /// In es, this message translates to:
  /// **'Escuchar audio'**
  String get noteAudioPlay;

  /// No description provided for @noteAudioPlayWithDuration.
  ///
  /// In es, this message translates to:
  /// **'Escuchar audio, {duration}'**
  String noteAudioPlayWithDuration(String duration);

  /// No description provided for @noteCardSemantics.
  ///
  /// In es, this message translates to:
  /// **'Nota: {title}'**
  String noteCardSemantics(String title);

  /// No description provided for @commonCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get commonSave;

  /// No description provided for @homeTabNotes.
  ///
  /// In es, this message translates to:
  /// **'Notas'**
  String get homeTabNotes;

  /// No description provided for @homeTabHistory.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get homeTabHistory;

  /// No description provided for @homeSearchClear.
  ///
  /// In es, this message translates to:
  /// **'Borrar búsqueda'**
  String get homeSearchClear;

  /// No description provided for @noteActionOpen.
  ///
  /// In es, this message translates to:
  /// **'Abrir y editar'**
  String get noteActionOpen;

  /// No description provided for @noteActionCopy.
  ///
  /// In es, this message translates to:
  /// **'Copiar texto'**
  String get noteActionCopy;

  /// No description provided for @noteActionDeleteAudio.
  ///
  /// In es, this message translates to:
  /// **'Borrar audio, conservar texto'**
  String get noteActionDeleteAudio;

  /// No description provided for @noteActionDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar nota'**
  String get noteActionDelete;

  /// No description provided for @recordStop.
  ///
  /// In es, this message translates to:
  /// **'Detener grabación'**
  String get recordStop;

  /// No description provided for @recordTranscribing.
  ///
  /// In es, this message translates to:
  /// **'Transcribiendo'**
  String get recordTranscribing;

  /// No description provided for @recordHoldToRecord.
  ///
  /// In es, this message translates to:
  /// **'Mantené para grabar'**
  String get recordHoldToRecord;

  /// No description provided for @recordStart.
  ///
  /// In es, this message translates to:
  /// **'Iniciar grabación'**
  String get recordStart;

  /// No description provided for @recordDiscard.
  ///
  /// In es, this message translates to:
  /// **'Descartar grabación'**
  String get recordDiscard;

  /// No description provided for @pendingAgoMinutes.
  ///
  /// In es, this message translates to:
  /// **'hace {n}m'**
  String pendingAgoMinutes(String n);

  /// No description provided for @pendingAgoHours.
  ///
  /// In es, this message translates to:
  /// **'hace {n}h'**
  String pendingAgoHours(String n);

  /// No description provided for @pendingYesterday.
  ///
  /// In es, this message translates to:
  /// **'ayer'**
  String get pendingYesterday;

  /// No description provided for @pendingAgoDays.
  ///
  /// In es, this message translates to:
  /// **'hace {n}d'**
  String pendingAgoDays(String n);

  /// No description provided for @pendingSemantics.
  ///
  /// In es, this message translates to:
  /// **'Audio sin transcribir, {when}'**
  String pendingSemantics(String when);

  /// No description provided for @pendingTitle.
  ///
  /// In es, this message translates to:
  /// **'Audio sin transcribir'**
  String get pendingTitle;

  /// No description provided for @pendingUnplayable.
  ///
  /// In es, this message translates to:
  /// **'No se pudo reproducir este audio'**
  String get pendingUnplayable;

  /// No description provided for @pendingTranscribe.
  ///
  /// In es, this message translates to:
  /// **'Transcribir'**
  String get pendingTranscribe;

  /// No description provided for @pendingDiscard.
  ///
  /// In es, this message translates to:
  /// **'Descartar audio'**
  String get pendingDiscard;

  /// No description provided for @pendingPause.
  ///
  /// In es, this message translates to:
  /// **'Pausar'**
  String get pendingPause;

  /// No description provided for @pendingPlay.
  ///
  /// In es, this message translates to:
  /// **'Escuchar audio'**
  String get pendingPlay;

  /// No description provided for @pendingClosePlayer.
  ///
  /// In es, this message translates to:
  /// **'Cerrar reproductor'**
  String get pendingClosePlayer;

  /// No description provided for @unitPx.
  ///
  /// In es, this message translates to:
  /// **'px'**
  String get unitPx;

  /// No description provided for @unitPxSpoken.
  ///
  /// In es, this message translates to:
  /// **'píxeles'**
  String get unitPxSpoken;

  /// No description provided for @credentialsDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'Borrar clave'**
  String get credentialsDeleteTitle;

  /// No description provided for @credentialsDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar \"{name}\"? No se puede deshacer.'**
  String credentialsDeleteConfirm(String name);

  /// No description provided for @credentialsDeleteButton.
  ///
  /// In es, this message translates to:
  /// **'Borrar'**
  String get credentialsDeleteButton;

  /// No description provided for @credentialsShowUserFooter.
  ///
  /// In es, this message translates to:
  /// **'Junto al nombre, en la lista del teclado.'**
  String get credentialsShowUserFooter;

  /// No description provided for @credentialsShowUser.
  ///
  /// In es, this message translates to:
  /// **'Mostrar usuario'**
  String get credentialsShowUser;

  /// No description provided for @credentialsEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin claves guardadas'**
  String get credentialsEmptyTitle;

  /// No description provided for @credentialsEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'Guardá usuario y contraseña para rellenarlos desde la llave del teclado.'**
  String get credentialsEmptyMessage;

  /// No description provided for @credentialsAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar clave'**
  String get credentialsAdd;

  /// No description provided for @credentialsSavedHeader.
  ///
  /// In es, this message translates to:
  /// **'Guardadas'**
  String get credentialsSavedHeader;

  /// No description provided for @credentialsCountFooter.
  ///
  /// In es, this message translates to:
  /// **'{count} de {max} · La contraseña nunca se muestra.'**
  String credentialsCountFooter(String count, String max);

  /// No description provided for @credentialsDeleteNamed.
  ///
  /// In es, this message translates to:
  /// **'Borrar {name}'**
  String credentialsDeleteNamed(String name);

  /// No description provided for @credentialsFormError.
  ///
  /// In es, this message translates to:
  /// **'Revisá los campos: nombre y usuario no pueden quedar vacíos.'**
  String get credentialsFormError;

  /// No description provided for @credentialsNewTitle.
  ///
  /// In es, this message translates to:
  /// **'Nueva clave'**
  String get credentialsNewTitle;

  /// No description provided for @credentialsFieldName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get credentialsFieldName;

  /// No description provided for @credentialsFieldNameHint.
  ///
  /// In es, this message translates to:
  /// **'Ej. Banco'**
  String get credentialsFieldNameHint;

  /// No description provided for @credentialsFieldUser.
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get credentialsFieldUser;

  /// No description provided for @credentialsFieldUserHint.
  ///
  /// In es, this message translates to:
  /// **'Usuario o email'**
  String get credentialsFieldUserHint;

  /// No description provided for @credentialsFieldPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get credentialsFieldPassword;

  /// No description provided for @credentialsFieldPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'Solo se escribe, nunca se muestra'**
  String get credentialsFieldPasswordHint;

  /// No description provided for @credentialsFormHint.
  ///
  /// In es, this message translates to:
  /// **'Se guarda cifrada. El teclado la rellena solo en campos de contraseña.'**
  String get credentialsFormHint;

  /// No description provided for @islandTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustar isla'**
  String get islandTitle;

  /// No description provided for @islandNeedsPointer.
  ///
  /// In es, this message translates to:
  /// **'La isla necesita VoiceBubble Puntero activo: sin él se ve como burbuja y estos ajustes no se notan.'**
  String get islandNeedsPointer;

  /// No description provided for @islandNeedsBar.
  ///
  /// In es, this message translates to:
  /// **'Encendé la barra flotante para ver la isla en tu pantalla.'**
  String get islandNeedsBar;

  /// No description provided for @islandPositionHeader.
  ///
  /// In es, this message translates to:
  /// **'Posición'**
  String get islandPositionHeader;

  /// No description provided for @islandPositionFooter.
  ///
  /// In es, this message translates to:
  /// **'Horizontal: el centro de la isla. Vertical: su borde superior. En píxeles de la pantalla completa.'**
  String get islandPositionFooter;

  /// No description provided for @islandPositionX.
  ///
  /// In es, this message translates to:
  /// **'Posición horizontal'**
  String get islandPositionX;

  /// No description provided for @islandPixelLeft.
  ///
  /// In es, this message translates to:
  /// **'Un píxel a la izquierda'**
  String get islandPixelLeft;

  /// No description provided for @islandPixelRight.
  ///
  /// In es, this message translates to:
  /// **'Un píxel a la derecha'**
  String get islandPixelRight;

  /// No description provided for @islandPositionY.
  ///
  /// In es, this message translates to:
  /// **'Posición vertical'**
  String get islandPositionY;

  /// No description provided for @islandPixelUp.
  ///
  /// In es, this message translates to:
  /// **'Un píxel hacia arriba'**
  String get islandPixelUp;

  /// No description provided for @islandPixelDown.
  ///
  /// In es, this message translates to:
  /// **'Un píxel hacia abajo'**
  String get islandPixelDown;

  /// No description provided for @islandSizeHeader.
  ///
  /// In es, this message translates to:
  /// **'Tamaño en reposo'**
  String get islandSizeHeader;

  /// No description provided for @islandSizeFooter.
  ///
  /// In es, this message translates to:
  /// **'Al grabar, la isla se agranda sola.'**
  String get islandSizeFooter;

  /// No description provided for @islandWidth.
  ///
  /// In es, this message translates to:
  /// **'Ancho'**
  String get islandWidth;

  /// No description provided for @islandNarrower.
  ///
  /// In es, this message translates to:
  /// **'Un píxel más angosta'**
  String get islandNarrower;

  /// No description provided for @islandWider.
  ///
  /// In es, this message translates to:
  /// **'Un píxel más ancha'**
  String get islandWider;

  /// No description provided for @islandHeight.
  ///
  /// In es, this message translates to:
  /// **'Alto'**
  String get islandHeight;

  /// No description provided for @islandShorter.
  ///
  /// In es, this message translates to:
  /// **'Un píxel más baja'**
  String get islandShorter;

  /// No description provided for @islandTaller.
  ///
  /// In es, this message translates to:
  /// **'Un píxel más alta'**
  String get islandTaller;

  /// No description provided for @islandSideFooter.
  ///
  /// In es, this message translates to:
  /// **'El puntero va del otro lado.'**
  String get islandSideFooter;

  /// No description provided for @islandSideTitle.
  ///
  /// In es, this message translates to:
  /// **'Lado del micrófono'**
  String get islandSideTitle;

  /// No description provided for @islandSideLeft.
  ///
  /// In es, this message translates to:
  /// **'Izquierda'**
  String get islandSideLeft;

  /// No description provided for @islandSideRight.
  ///
  /// In es, this message translates to:
  /// **'Derecha'**
  String get islandSideRight;

  /// No description provided for @islandCenterTop.
  ///
  /// In es, this message translates to:
  /// **'Centrar arriba'**
  String get islandCenterTop;

  /// No description provided for @islandReset.
  ///
  /// In es, this message translates to:
  /// **'Restablecer'**
  String get islandReset;

  /// No description provided for @noteEditorWriteFirst.
  ///
  /// In es, this message translates to:
  /// **'Escribe o dicta una nota primero'**
  String get noteEditorWriteFirst;

  /// No description provided for @noteEditorUnexpectedError.
  ///
  /// In es, this message translates to:
  /// **'Error inesperado: {error}'**
  String noteEditorUnexpectedError(String error);

  /// No description provided for @noteEditorAiErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'Error de IA'**
  String get noteEditorAiErrorTitle;

  /// No description provided for @noteEditorClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get noteEditorClose;

  /// No description provided for @noteEditorAiTitleSuggested.
  ///
  /// In es, this message translates to:
  /// **'Título sugerido'**
  String get noteEditorAiTitleSuggested;

  /// No description provided for @noteEditorAiSummaryTitle.
  ///
  /// In es, this message translates to:
  /// **'Resumen de la nota'**
  String get noteEditorAiSummaryTitle;

  /// No description provided for @noteEditorDiscard.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get noteEditorDiscard;

  /// No description provided for @noteEditorReplace.
  ///
  /// In es, this message translates to:
  /// **'Reemplazar'**
  String get noteEditorReplace;

  /// No description provided for @noteEditorBodyRequired.
  ///
  /// In es, this message translates to:
  /// **'Cuerpo requerido'**
  String get noteEditorBodyRequired;

  /// No description provided for @noteEditorLimitOrError.
  ///
  /// In es, this message translates to:
  /// **'Limite alcanzado o error'**
  String get noteEditorLimitOrError;

  /// No description provided for @noteEditorClipboardEmpty.
  ///
  /// In es, this message translates to:
  /// **'El portapapeles está vacío'**
  String get noteEditorClipboardEmpty;

  /// No description provided for @noteEditorNothingToCopy.
  ///
  /// In es, this message translates to:
  /// **'Sin contenido para copiar'**
  String get noteEditorNothingToCopy;

  /// No description provided for @noteEditorDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar nota'**
  String get noteEditorDelete;

  /// No description provided for @noteEditorDeleteWithAudio.
  ///
  /// In es, this message translates to:
  /// **'Se borrarán el texto y el audio. No se puede deshacer.'**
  String get noteEditorDeleteWithAudio;

  /// No description provided for @noteEditorDeleteTextOnly.
  ///
  /// In es, this message translates to:
  /// **'Esta acción no se puede deshacer.'**
  String get noteEditorDeleteTextOnly;

  /// No description provided for @noteEditorDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get noteEditorDeleteConfirm;

  /// No description provided for @noteEditorNewNote.
  ///
  /// In es, this message translates to:
  /// **'Nueva nota'**
  String get noteEditorNewNote;

  /// No description provided for @noteEditorMetaGroupTime.
  ///
  /// In es, this message translates to:
  /// **'{group}, {time}'**
  String noteEditorMetaGroupTime(String group, String time);

  /// No description provided for @noteEditorTitleLabel.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get noteEditorTitleLabel;

  /// No description provided for @noteEditorAiTitleButton.
  ///
  /// In es, this message translates to:
  /// **'Generar título con IA'**
  String get noteEditorAiTitleButton;

  /// No description provided for @noteEditorBodyHint.
  ///
  /// In es, this message translates to:
  /// **'Escribí o pegá el texto de la nota'**
  String get noteEditorBodyHint;

  /// No description provided for @commonBack.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get commonBack;

  /// No description provided for @noteEditorPaste.
  ///
  /// In es, this message translates to:
  /// **'Pegar'**
  String get noteEditorPaste;

  /// No description provided for @noteEditorCopy.
  ///
  /// In es, this message translates to:
  /// **'Copiar texto'**
  String get noteEditorCopy;

  /// No description provided for @noteEditorAiSummarize.
  ///
  /// In es, this message translates to:
  /// **'Resumir con IA'**
  String get noteEditorAiSummarize;

  /// No description provided for @snippetSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el snippet.'**
  String get snippetSaveFailed;

  /// No description provided for @snippetSaveFailedLimit.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el snippet: Límite de {max} snippets alcanzado o datos temporales no legibles.'**
  String snippetSaveFailedLimit(String max);

  /// No description provided for @snippetColorBlue.
  ///
  /// In es, this message translates to:
  /// **'azul'**
  String get snippetColorBlue;

  /// No description provided for @snippetColorGreen.
  ///
  /// In es, this message translates to:
  /// **'verde'**
  String get snippetColorGreen;

  /// No description provided for @snippetColorRed.
  ///
  /// In es, this message translates to:
  /// **'rojo'**
  String get snippetColorRed;

  /// No description provided for @snippetColorOrange.
  ///
  /// In es, this message translates to:
  /// **'naranja'**
  String get snippetColorOrange;

  /// No description provided for @snippetColorViolet.
  ///
  /// In es, this message translates to:
  /// **'violeta'**
  String get snippetColorViolet;

  /// No description provided for @snippetColorGray.
  ///
  /// In es, this message translates to:
  /// **'gris'**
  String get snippetColorGray;

  /// No description provided for @snippetDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar snippet'**
  String get snippetDelete;

  /// No description provided for @snippetDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar \"{name}\"? Esta acción no se puede deshacer.'**
  String snippetDeleteConfirm(String name);

  /// No description provided for @snippetDeleteButton.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get snippetDeleteButton;

  /// No description provided for @snippetsEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin snippets'**
  String get snippetsEmptyTitle;

  /// No description provided for @snippetsEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'Guardá textos que usás seguido y pegalos con un toque desde el teclado.'**
  String get snippetsEmptyMessage;

  /// No description provided for @snippetsCreate.
  ///
  /// In es, this message translates to:
  /// **'Crear snippet'**
  String get snippetsCreate;

  /// No description provided for @snippetsNoResults.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados para \"{query}\".'**
  String snippetsNoResults(String query);

  /// No description provided for @snippetsCountFooter.
  ///
  /// In es, this message translates to:
  /// **'{count} de {max} · Se insertan con un toque desde el teclado.'**
  String snippetsCountFooter(String count, String max);

  /// No description provided for @snippetsReorderDone.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get snippetsReorderDone;

  /// No description provided for @snippetsReorder.
  ///
  /// In es, this message translates to:
  /// **'Ordenar'**
  String get snippetsReorder;

  /// No description provided for @snippetsSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get snippetsSearchHint;

  /// No description provided for @snippetRowSemantics.
  ///
  /// In es, this message translates to:
  /// **'{name}. {preview}'**
  String snippetRowSemantics(String name, String preview);

  /// No description provided for @snippetMoveUp.
  ///
  /// In es, this message translates to:
  /// **'Subir {name}'**
  String snippetMoveUp(String name);

  /// No description provided for @snippetMoveDown.
  ///
  /// In es, this message translates to:
  /// **'Bajar {name}'**
  String snippetMoveDown(String name);

  /// No description provided for @snippetNameRequired.
  ///
  /// In es, this message translates to:
  /// **'El nombre es obligatorio'**
  String get snippetNameRequired;

  /// No description provided for @snippetMaxChars.
  ///
  /// In es, this message translates to:
  /// **'Máximo {max} caracteres'**
  String snippetMaxChars(String max);

  /// No description provided for @snippetSheetEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar snippet'**
  String get snippetSheetEdit;

  /// No description provided for @snippetSheetNew.
  ///
  /// In es, this message translates to:
  /// **'Nuevo snippet'**
  String get snippetSheetNew;

  /// No description provided for @snippetFieldName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get snippetFieldName;

  /// No description provided for @snippetFieldNameHint.
  ///
  /// In es, this message translates to:
  /// **'Ej. Firma'**
  String get snippetFieldNameHint;

  /// No description provided for @snippetFieldText.
  ///
  /// In es, this message translates to:
  /// **'Texto'**
  String get snippetFieldText;

  /// No description provided for @snippetFieldTextHint.
  ///
  /// In es, this message translates to:
  /// **'Lo que se va a insertar'**
  String get snippetFieldTextHint;

  /// No description provided for @snippetContentCounter.
  ///
  /// In es, this message translates to:
  /// **'{length} / {max}'**
  String snippetContentCounter(String length, String max);

  /// No description provided for @snippetColorLabel.
  ///
  /// In es, this message translates to:
  /// **'Color'**
  String get snippetColorLabel;

  /// No description provided for @snippetColorNone.
  ///
  /// In es, this message translates to:
  /// **'Sin color'**
  String get snippetColorNone;

  /// No description provided for @homeStatusRelease.
  ///
  /// In es, this message translates to:
  /// **'Soltá para terminar'**
  String get homeStatusRelease;

  /// No description provided for @homeStatusTranscribing.
  ///
  /// In es, this message translates to:
  /// **'Transcribiendo…'**
  String get homeStatusTranscribing;

  /// No description provided for @homeStatusError.
  ///
  /// In es, this message translates to:
  /// **'Error, toca para reintentar'**
  String get homeStatusError;

  /// No description provided for @homeRecordStartError.
  ///
  /// In es, this message translates to:
  /// **'Error al iniciar grabación: {error}'**
  String homeRecordStartError(String error);

  /// No description provided for @homeNoteSaved.
  ///
  /// In es, this message translates to:
  /// **'Nota guardada'**
  String get homeNoteSaved;

  /// No description provided for @homeNoteNotSavedFull.
  ///
  /// In es, this message translates to:
  /// **'Nota no guardada: llegaste a {max} notas. El texto quedó copiado y en Historial.'**
  String homeNoteNotSavedFull(String max);

  /// No description provided for @homeAudioNotKept.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conservar el audio. El texto quedó en Historial.'**
  String get homeAudioNotKept;

  /// No description provided for @homeNoteNotSavedTextKept.
  ///
  /// In es, this message translates to:
  /// **'Nota no guardada; el texto quedó en Historial'**
  String get homeNoteNotSavedTextKept;

  /// No description provided for @homeError.
  ///
  /// In es, this message translates to:
  /// **'Error: {error}'**
  String homeError(String error);

  /// No description provided for @homeRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get homeRetry;

  /// No description provided for @homeOfflineAudioSaved.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión · audio guardado en Notas'**
  String get homeOfflineAudioSaved;

  /// No description provided for @homePendingAudioGone.
  ///
  /// In es, this message translates to:
  /// **'El audio pendiente ya no está disponible'**
  String get homePendingAudioGone;

  /// No description provided for @homeAudioNotKeptShort.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conservar el audio'**
  String get homeAudioNotKeptShort;

  /// No description provided for @homeNoteNotSavedAudioKept.
  ///
  /// In es, this message translates to:
  /// **'Nota no guardada; el audio se conserva'**
  String get homeNoteNotSavedAudioKept;

  /// No description provided for @homeNoteSavedAudioPending.
  ///
  /// In es, this message translates to:
  /// **'Nota guardada; el audio queda pendiente'**
  String get homeNoteSavedAudioPending;

  /// No description provided for @homeApiKeyMissing.
  ///
  /// In es, this message translates to:
  /// **'Falta la API key. Configurala en Ajustes.'**
  String get homeApiKeyMissing;

  /// No description provided for @homeStillOffline.
  ///
  /// In es, this message translates to:
  /// **'Sigue sin red. El audio queda pendiente.'**
  String get homeStillOffline;

  /// No description provided for @homeDiscardAudioTitle.
  ///
  /// In es, this message translates to:
  /// **'Descartar audio'**
  String get homeDiscardAudioTitle;

  /// No description provided for @homeDiscardAudioMessage.
  ///
  /// In es, this message translates to:
  /// **'Se borrará el audio sin transcribir. Esta acción no se puede deshacer.'**
  String get homeDiscardAudioMessage;

  /// No description provided for @homeDiscardConfirm.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get homeDiscardConfirm;

  /// No description provided for @homeDeleteAudioTitle.
  ///
  /// In es, this message translates to:
  /// **'Borrar audio'**
  String get homeDeleteAudioTitle;

  /// No description provided for @homeDeleteAudioMessage.
  ///
  /// In es, this message translates to:
  /// **'Se borrará el audio original. La transcripción queda.'**
  String get homeDeleteAudioMessage;

  /// No description provided for @homeNoteDeleted.
  ///
  /// In es, this message translates to:
  /// **'Nota eliminada'**
  String get homeNoteDeleted;

  /// No description provided for @homeNoteDeleteFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar la nota'**
  String get homeNoteDeleteFailed;

  /// No description provided for @homeSettingsTooltip.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get homeSettingsTooltip;

  /// No description provided for @homeSearchNotesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get homeSearchNotesEmpty;

  /// No description provided for @homeSearchNotes.
  ///
  /// In es, this message translates to:
  /// **'Buscar en {count} notas'**
  String homeSearchNotes(String count);

  /// No description provided for @homeSearchHistory.
  ///
  /// In es, this message translates to:
  /// **'Buscar en el historial'**
  String get homeSearchHistory;

  /// No description provided for @homeNotesLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando notas…'**
  String get homeNotesLoading;

  /// No description provided for @homeNotesUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Notas no disponibles'**
  String get homeNotesUnavailable;

  /// No description provided for @homeNotesUnavailableMessage.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer el estado de las notas'**
  String get homeNotesUnavailableMessage;

  /// No description provided for @homeEmptyNotesTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu primera nota'**
  String get homeEmptyNotesTitle;

  /// No description provided for @homeEmptyNotesHold.
  ///
  /// In es, this message translates to:
  /// **'Mantené la burbuja y hablá.\nLo que digas queda escrito acá.'**
  String get homeEmptyNotesHold;

  /// No description provided for @homeEmptyNotesTap.
  ///
  /// In es, this message translates to:
  /// **'Tocá la burbuja y hablá.\nLo que digas queda escrito acá.'**
  String get homeEmptyNotesTap;

  /// No description provided for @homeNoResultsTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados'**
  String get homeNoResultsTitle;

  /// No description provided for @homeNoResultsMessage.
  ///
  /// In es, this message translates to:
  /// **'Nada coincide con “{query}”.'**
  String homeNoResultsMessage(String query);

  /// No description provided for @homePendingHeader.
  ///
  /// In es, this message translates to:
  /// **'Pendientes · {count}'**
  String homePendingHeader(String count);

  /// No description provided for @homePendingInfo.
  ///
  /// In es, this message translates to:
  /// **'Sin transcripción local todavía: el audio se guarda en el teléfono y solo sale a la nube cuando tocas Transcribir.'**
  String get homePendingInfo;

  /// No description provided for @homePendingQueueUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Cola no disponible'**
  String get homePendingQueueUnavailable;

  /// No description provided for @homeHistoryFooter.
  ///
  /// In es, this message translates to:
  /// **'Las últimas {max} transcripciones de la app, la burbuja y el teclado. Las más viejas se borran solas.'**
  String homeHistoryFooter(String max);

  /// No description provided for @settingsKeepOneTool.
  ///
  /// In es, this message translates to:
  /// **'Dejá al menos una herramienta'**
  String get settingsKeepOneTool;

  /// No description provided for @settingsPointerNeedsCompanion.
  ///
  /// In es, this message translates to:
  /// **'Para hacer clic en otras apps, activá VoiceBubble Puntero en Trackpad'**
  String get settingsPointerNeedsCompanion;

  /// No description provided for @settingsPointerCompanionTitle.
  ///
  /// In es, this message translates to:
  /// **'VoiceBubble Puntero'**
  String get settingsPointerCompanionTitle;

  /// No description provided for @settingsPointerCompanionMessage.
  ///
  /// In es, this message translates to:
  /// **'Es una app chica que hace los clics del puntero en otras apps. Se descarga junto con VoiceBubble, en el mismo lugar de GitHub. Instalala y volvé acá para activarla.'**
  String get settingsPointerCompanionMessage;

  /// No description provided for @settingsPointerCompanionOk.
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get settingsPointerCompanionOk;

  /// No description provided for @settingsOverlayGranted.
  ///
  /// In es, this message translates to:
  /// **'Permiso de superposición concedido'**
  String get settingsOverlayGranted;

  /// No description provided for @settingsOverlayTitle.
  ///
  /// In es, this message translates to:
  /// **'Permiso de superposición'**
  String get settingsOverlayTitle;

  /// No description provided for @settingsOverlayMessage.
  ///
  /// In es, this message translates to:
  /// **'Para mostrar la burbuja sobre otras apps, VoiceBubble necesita el permiso de mostrar sobre otras aplicaciones.'**
  String get settingsOverlayMessage;

  /// No description provided for @settingsOverlayConfigure.
  ///
  /// In es, this message translates to:
  /// **'Configurar'**
  String get settingsOverlayConfigure;

  /// No description provided for @settingsBubbleStartFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo activar la burbuja flotante'**
  String get settingsBubbleStartFailed;

  /// No description provided for @settingsTranslateAiTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Traducir con IA?'**
  String get settingsTranslateAiTitle;

  /// No description provided for @settingsTranslateAiMessage.
  ///
  /// In es, this message translates to:
  /// **'Cuando traduzcas, el texto seleccionado o dictado se va a mandar a {name} (el proveedor de «Título y resumen con») para traducirlo. VoiceBubble no lo guarda. Nunca se usa en campos de contraseña.\n\nPodés volver a «En el teléfono» cuando quieras.'**
  String settingsTranslateAiMessage(String name);

  /// No description provided for @settingsTranslateAiAuthorize.
  ///
  /// In es, this message translates to:
  /// **'Autorizar'**
  String get settingsTranslateAiAuthorize;

  /// No description provided for @settingsKeyPasteToContinue.
  ///
  /// In es, this message translates to:
  /// **'Pegá tu clave para continuar.'**
  String get settingsKeyPasteToContinue;

  /// No description provided for @settingsKeyIncomplete.
  ///
  /// In es, this message translates to:
  /// **'Parece incompleta: revisá que la copiaste entera.'**
  String get settingsKeyIncomplete;

  /// No description provided for @settingsGroqKeyPrefix.
  ///
  /// In es, this message translates to:
  /// **'Las claves de Groq empiezan con gsk_.'**
  String get settingsGroqKeyPrefix;

  /// No description provided for @settingsKeySaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la API key'**
  String get settingsKeySaveFailed;

  /// No description provided for @settingsKeySaved.
  ///
  /// In es, this message translates to:
  /// **'Clave guardada'**
  String get settingsKeySaved;

  /// No description provided for @settingsGoogleKeyPaste.
  ///
  /// In es, this message translates to:
  /// **'Pegá tu clave de Google AI Studio para continuar.'**
  String get settingsGoogleKeyPaste;

  /// No description provided for @settingsGoogleKeySaved.
  ///
  /// In es, this message translates to:
  /// **'Clave de Google AI guardada'**
  String get settingsGoogleKeySaved;

  /// No description provided for @settingsGoogleKeyDeleted.
  ///
  /// In es, this message translates to:
  /// **'Clave de Google AI eliminada'**
  String get settingsGoogleKeyDeleted;

  /// No description provided for @settingsConnected.
  ///
  /// In es, this message translates to:
  /// **'Conectado con {name}'**
  String settingsConnected(String name);

  /// No description provided for @settingsConnectFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar con {name}: revisá la clave'**
  String settingsConnectFailed(String name);

  /// No description provided for @settingsKeyDeleteFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar la API key'**
  String get settingsKeyDeleteFailed;

  /// No description provided for @settingsKeyDeleted.
  ///
  /// In es, this message translates to:
  /// **'Clave eliminada'**
  String get settingsKeyDeleted;

  /// No description provided for @settingsSnippetsTitle.
  ///
  /// In es, this message translates to:
  /// **'Snippets'**
  String get settingsSnippetsTitle;

  /// No description provided for @settingsCredentialsTitle.
  ///
  /// In es, this message translates to:
  /// **'Claves'**
  String get settingsCredentialsTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @settingsSetupHeader.
  ///
  /// In es, this message translates to:
  /// **'Terminá de configurar'**
  String get settingsSetupHeader;

  /// No description provided for @settingsSetupFooter.
  ///
  /// In es, this message translates to:
  /// **'Con esto ya podés dictar en cualquier app.'**
  String get settingsSetupFooter;

  /// No description provided for @settingsSetupAddGroqKey.
  ///
  /// In es, this message translates to:
  /// **'Agregar clave de Groq'**
  String get settingsSetupAddGroqKey;

  /// No description provided for @settingsMissing.
  ///
  /// In es, this message translates to:
  /// **'Falta'**
  String get settingsMissing;

  /// No description provided for @settingsSetupEnableKeyboard.
  ///
  /// In es, this message translates to:
  /// **'Activar el teclado'**
  String get settingsSetupEnableKeyboard;

  /// No description provided for @settingsAppSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Dictado con Groq Whisper'**
  String get settingsAppSubtitle;

  /// No description provided for @settingsNavTranscription.
  ///
  /// In es, this message translates to:
  /// **'Transcripción'**
  String get settingsNavTranscription;

  /// No description provided for @settingsNoKey.
  ///
  /// In es, this message translates to:
  /// **'Sin clave'**
  String get settingsNoKey;

  /// No description provided for @settingsNavAi.
  ///
  /// In es, this message translates to:
  /// **'Inteligencia artificial'**
  String get settingsNavAi;

  /// No description provided for @settingsAiActive.
  ///
  /// In es, this message translates to:
  /// **'Activa'**
  String get settingsAiActive;

  /// No description provided for @settingsAiHidden.
  ///
  /// In es, this message translates to:
  /// **'Oculta'**
  String get settingsAiHidden;

  /// No description provided for @settingsAiOptional.
  ///
  /// In es, this message translates to:
  /// **'Opcional'**
  String get settingsAiOptional;

  /// No description provided for @settingsWhereHeader.
  ///
  /// In es, this message translates to:
  /// **'Dónde dictar'**
  String get settingsWhereHeader;

  /// No description provided for @settingsNavKeyboard.
  ///
  /// In es, this message translates to:
  /// **'Teclado'**
  String get settingsNavKeyboard;

  /// No description provided for @settingsKeyboardActive.
  ///
  /// In es, this message translates to:
  /// **'Activo'**
  String get settingsKeyboardActive;

  /// No description provided for @settingsKeyboardInactive.
  ///
  /// In es, this message translates to:
  /// **'Inactivo'**
  String get settingsKeyboardInactive;

  /// No description provided for @settingsNavBubble.
  ///
  /// In es, this message translates to:
  /// **'Barra flotante'**
  String get settingsNavBubble;

  /// No description provided for @settingsBubbleOn.
  ///
  /// In es, this message translates to:
  /// **'Activada'**
  String get settingsBubbleOn;

  /// No description provided for @settingsBubbleOff.
  ///
  /// In es, this message translates to:
  /// **'Apagada'**
  String get settingsBubbleOff;

  /// No description provided for @settingsNavTrackpad.
  ///
  /// In es, this message translates to:
  /// **'Trackpad'**
  String get settingsNavTrackpad;

  /// No description provided for @settingsTrackpadOn.
  ///
  /// In es, this message translates to:
  /// **'Activado'**
  String get settingsTrackpadOn;

  /// No description provided for @settingsTrackpadOff.
  ///
  /// In es, this message translates to:
  /// **'Apagado'**
  String get settingsTrackpadOff;

  /// No description provided for @settingsContentHeader.
  ///
  /// In es, this message translates to:
  /// **'Tu contenido'**
  String get settingsContentHeader;

  /// No description provided for @settingsNavNotes.
  ///
  /// In es, this message translates to:
  /// **'Notas y widgets'**
  String get settingsNavNotes;

  /// No description provided for @settingsAppearance.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeAuto.
  ///
  /// In es, this message translates to:
  /// **'Automática'**
  String get settingsThemeAuto;

  /// No description provided for @settingsThemeLight.
  ///
  /// In es, this message translates to:
  /// **'Clara'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In es, this message translates to:
  /// **'Oscura'**
  String get settingsThemeDark;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAboutTagline.
  ///
  /// In es, this message translates to:
  /// **'Transcripción de voz a texto con Groq Whisper.'**
  String get settingsAboutTagline;

  /// No description provided for @settingsAboutPrivacy.
  ///
  /// In es, this message translates to:
  /// **'Sin analytics ni telemetría. El audio sale del teléfono solo cuando dictás, y el teclado nunca guarda lo que escribís.'**
  String get settingsAboutPrivacy;

  /// No description provided for @settingsAboutVersion.
  ///
  /// In es, this message translates to:
  /// **'Versión'**
  String get settingsAboutVersion;

  /// No description provided for @settingsAboutEngine.
  ///
  /// In es, this message translates to:
  /// **'Motor'**
  String get settingsAboutEngine;

  /// No description provided for @settingsAboutChannelErrors.
  ///
  /// In es, this message translates to:
  /// **'Errores de canal'**
  String get settingsAboutChannelErrors;

  /// No description provided for @settingsAiProviderGroqHint.
  ///
  /// In es, this message translates to:
  /// **'Groq: rápido y gratis, con la misma clave de la transcripción.'**
  String get settingsAiProviderGroqHint;

  /// No description provided for @settingsAiProviderGroqNoKey.
  ///
  /// In es, this message translates to:
  /// **'Groq: rápido y gratis, con la misma clave de la transcripción. Falta la clave de Groq (Ajustes › Transcripción).'**
  String get settingsAiProviderGroqNoKey;

  /// No description provided for @settingsAiProviderGoogleHint.
  ///
  /// In es, this message translates to:
  /// **'Google: necesita su propia clave (abajo).'**
  String get settingsAiProviderGoogleHint;

  /// No description provided for @settingsAiProviderGoogleNoKey.
  ///
  /// In es, this message translates to:
  /// **'Google: necesita su propia clave (abajo). Mientras no la cargues, se usa Groq.'**
  String get settingsAiProviderGoogleNoKey;

  /// No description provided for @settingsTranslateFooterAi.
  ///
  /// In es, this message translates to:
  /// **'Botón «Traducir» del teclado: con texto seleccionado lo traduce; sin selección, el próximo dictado sale traducido. Toque largo: deshacer. Con IA: el texto se manda al proveedor de arriba para traducirlo. Nunca en campos de contraseña.'**
  String get settingsTranslateFooterAi;

  /// No description provided for @settingsTranslateFooterLocal.
  ///
  /// In es, this message translates to:
  /// **'Botón «Traducir» del teclado: con texto seleccionado lo traduce; sin selección, el próximo dictado sale traducido. Toque largo: deshacer. En el teléfono: el texto no sale del teléfono; la primera vez baja el idioma (unos 30 MB) y después traduce sin internet. Nunca en campos de contraseña.'**
  String get settingsTranslateFooterLocal;

  /// No description provided for @settingsApiKeyHeader.
  ///
  /// In es, this message translates to:
  /// **'Clave de API'**
  String get settingsApiKeyHeader;

  /// No description provided for @settingsApiKeyFooter.
  ///
  /// In es, this message translates to:
  /// **'Se guarda cifrada en este teléfono. La conseguís gratis en console.groq.com.'**
  String get settingsApiKeyFooter;

  /// No description provided for @settingsAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar'**
  String get settingsAdd;

  /// No description provided for @settingsRecordingHeader.
  ///
  /// In es, this message translates to:
  /// **'Grabación'**
  String get settingsRecordingHeader;

  /// No description provided for @settingsRecordHoldFooter.
  ///
  /// In es, this message translates to:
  /// **'Mantené presionado mientras hablás y soltá para transcribir.'**
  String get settingsRecordHoldFooter;

  /// No description provided for @settingsRecordTapFooter.
  ///
  /// In es, this message translates to:
  /// **'Tocá para empezar y otra vez para transcribir.'**
  String get settingsRecordTapFooter;

  /// No description provided for @settingsRecordButton.
  ///
  /// In es, this message translates to:
  /// **'Botón de grabar'**
  String get settingsRecordButton;

  /// No description provided for @settingsRecordTap.
  ///
  /// In es, this message translates to:
  /// **'Tocar'**
  String get settingsRecordTap;

  /// No description provided for @settingsRecordHold.
  ///
  /// In es, this message translates to:
  /// **'Mantener'**
  String get settingsRecordHold;

  /// No description provided for @settingsEngineHeader.
  ///
  /// In es, this message translates to:
  /// **'Motor'**
  String get settingsEngineHeader;

  /// No description provided for @settingsEnginePreciseFooter.
  ///
  /// In es, this message translates to:
  /// **'Preciso: menos errores y mejor puntuación, apenas más lento. El audio sale del teléfono solo cuando dictás.'**
  String get settingsEnginePreciseFooter;

  /// No description provided for @settingsEngineFastFooter.
  ///
  /// In es, this message translates to:
  /// **'Rápido: el de menor espera. El audio sale del teléfono solo cuando dictás.'**
  String get settingsEngineFastFooter;

  /// No description provided for @settingsModel.
  ///
  /// In es, this message translates to:
  /// **'Modelo'**
  String get settingsModel;

  /// No description provided for @settingsModelFast.
  ///
  /// In es, this message translates to:
  /// **'Rápido'**
  String get settingsModelFast;

  /// No description provided for @settingsModelPrecise.
  ///
  /// In es, this message translates to:
  /// **'Preciso'**
  String get settingsModelPrecise;

  /// No description provided for @settingsAiProviderHeader.
  ///
  /// In es, this message translates to:
  /// **'Proveedor'**
  String get settingsAiProviderHeader;

  /// No description provided for @settingsAiProviderTitle.
  ///
  /// In es, this message translates to:
  /// **'Título y resumen con'**
  String get settingsAiProviderTitle;

  /// No description provided for @settingsGoogleKeyHeader.
  ///
  /// In es, this message translates to:
  /// **'Clave de Google'**
  String get settingsGoogleKeyHeader;

  /// No description provided for @settingsGoogleKeyFooter.
  ///
  /// In es, this message translates to:
  /// **'Opcional. La conseguís en aistudio.google.com.'**
  String get settingsGoogleKeyFooter;

  /// No description provided for @settingsAiActionsFooter.
  ///
  /// In es, this message translates to:
  /// **'Título y resumen con un toque en el editor de cada nota.'**
  String get settingsAiActionsFooter;

  /// No description provided for @settingsAiActionsSwitch.
  ///
  /// In es, this message translates to:
  /// **'Acciones de IA en notas'**
  String get settingsAiActionsSwitch;

  /// No description provided for @settingsAiTestConnection.
  ///
  /// In es, this message translates to:
  /// **'Probar conexión'**
  String get settingsAiTestConnection;

  /// No description provided for @settingsTranslateHeader.
  ///
  /// In es, this message translates to:
  /// **'Traducción'**
  String get settingsTranslateHeader;

  /// No description provided for @settingsTranslateTo.
  ///
  /// In es, this message translates to:
  /// **'Traducir a'**
  String get settingsTranslateTo;

  /// No description provided for @settingsTranslateHow.
  ///
  /// In es, this message translates to:
  /// **'Cómo traducir'**
  String get settingsTranslateHow;

  /// No description provided for @settingsTranslateLocal.
  ///
  /// In es, this message translates to:
  /// **'En el teléfono'**
  String get settingsTranslateLocal;

  /// No description provided for @settingsTranslateLocalDetail.
  ///
  /// In es, this message translates to:
  /// **'Privado'**
  String get settingsTranslateLocalDetail;

  /// No description provided for @settingsTranslateAi.
  ///
  /// In es, this message translates to:
  /// **'Con IA'**
  String get settingsTranslateAi;

  /// No description provided for @settingsTranslateAiDetail.
  ///
  /// In es, this message translates to:
  /// **'Mejor calidad'**
  String get settingsTranslateAiDetail;

  /// No description provided for @settingsTranslateDictation.
  ///
  /// In es, this message translates to:
  /// **'Traducir siempre el dictado del teclado'**
  String get settingsTranslateDictation;

  /// No description provided for @settingsBubbleFooter.
  ///
  /// In es, this message translates to:
  /// **'Dictá y usá el puntero encima de cualquier app. Arrastrala hacia el centro para usarla como burbuja; pegala a un borde para volver a la barra.'**
  String get settingsBubbleFooter;

  /// No description provided for @settingsDockForm.
  ///
  /// In es, this message translates to:
  /// **'Forma'**
  String get settingsDockForm;

  /// No description provided for @settingsDockEdge.
  ///
  /// In es, this message translates to:
  /// **'Barra en el borde'**
  String get settingsDockEdge;

  /// No description provided for @settingsDockBubble.
  ///
  /// In es, this message translates to:
  /// **'Burbuja'**
  String get settingsDockBubble;

  /// No description provided for @settingsDockIsland.
  ///
  /// In es, this message translates to:
  /// **'Isla'**
  String get settingsDockIsland;

  /// No description provided for @settingsDockUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No disponible'**
  String get settingsDockUnavailable;

  /// No description provided for @settingsIslandNeedsFooter.
  ///
  /// In es, this message translates to:
  /// **'Necesita VoiceBubble Puntero activo: solo un servicio de Accesibilidad puede dibujar sobre la cámara y la barra de estado.'**
  String get settingsIslandNeedsFooter;

  /// No description provided for @settingsToolsHeader.
  ///
  /// In es, this message translates to:
  /// **'Herramientas'**
  String get settingsToolsHeader;

  /// No description provided for @settingsToolsFooter.
  ///
  /// In es, this message translates to:
  /// **'Con una sola herramienta, tocar la burbuja la usa directo.'**
  String get settingsToolsFooter;

  /// No description provided for @settingsToolMic.
  ///
  /// In es, this message translates to:
  /// **'Micrófono'**
  String get settingsToolMic;

  /// No description provided for @settingsToolPointer.
  ///
  /// In es, this message translates to:
  /// **'Puntero'**
  String get settingsToolPointer;

  /// No description provided for @settingsBubbleHistoryFooter.
  ///
  /// In es, this message translates to:
  /// **'Mantené presionada la barra o la burbuja para ver lo último que dictaste.'**
  String get settingsBubbleHistoryFooter;

  /// No description provided for @settingsBubbleHistory.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get settingsBubbleHistory;

  /// No description provided for @settingsPermissionHeader.
  ///
  /// In es, this message translates to:
  /// **'Permiso'**
  String get settingsPermissionHeader;

  /// No description provided for @settingsPermissionFooter.
  ///
  /// In es, this message translates to:
  /// **'Android lo pide para mostrar la barra encima de otras apps.'**
  String get settingsPermissionFooter;

  /// No description provided for @settingsOverlayRow.
  ///
  /// In es, this message translates to:
  /// **'Mostrar sobre otras apps'**
  String get settingsOverlayRow;

  /// No description provided for @settingsReview.
  ///
  /// In es, this message translates to:
  /// **'Revisar'**
  String get settingsReview;

  /// No description provided for @settingsNotesHeader.
  ///
  /// In es, this message translates to:
  /// **'Notas'**
  String get settingsNotesHeader;

  /// No description provided for @settingsNotesQueueFooter.
  ///
  /// In es, this message translates to:
  /// **'Sin red, el audio queda en Notas y lo transcribís cuando vuelva la conexión. Transcribir sin internet: aún no disponible.'**
  String get settingsNotesQueueFooter;

  /// No description provided for @settingsNotesQueueSwitch.
  ///
  /// In es, this message translates to:
  /// **'Guardar audio sin conexión'**
  String get settingsNotesQueueSwitch;

  /// No description provided for @settingsWidgetHeader.
  ///
  /// In es, this message translates to:
  /// **'Widget de notas'**
  String get settingsWidgetHeader;

  /// No description provided for @commonLeft.
  ///
  /// In es, this message translates to:
  /// **'A la izquierda'**
  String get commonLeft;

  /// No description provided for @commonRight.
  ///
  /// In es, this message translates to:
  /// **'A la derecha'**
  String get commonRight;

  /// No description provided for @settingsGroqKeyTitle.
  ///
  /// In es, this message translates to:
  /// **'Clave de Groq'**
  String get settingsGroqKeyTitle;

  /// No description provided for @settingsKeySavedHint.
  ///
  /// In es, this message translates to:
  /// **'Guardada: {tail}'**
  String settingsKeySavedHint(String tail);

  /// No description provided for @settingsGroqKeyHelp.
  ///
  /// In es, this message translates to:
  /// **'Pegala tal cual la copiaste de console.groq.com.'**
  String get settingsGroqKeyHelp;

  /// No description provided for @settingsGoogleKeyTitle.
  ///
  /// In es, this message translates to:
  /// **'Clave de Google AI'**
  String get settingsGoogleKeyTitle;

  /// No description provided for @settingsGoogleKeySavedHint.
  ///
  /// In es, this message translates to:
  /// **'Guardada: {tail}'**
  String settingsGoogleKeySavedHint(String tail);

  /// No description provided for @settingsGoogleKeyHelp.
  ///
  /// In es, this message translates to:
  /// **'Pegala tal cual la copiaste de aistudio.google.com.'**
  String get settingsGoogleKeyHelp;

  /// No description provided for @settingsKeyField.
  ///
  /// In es, this message translates to:
  /// **'Clave'**
  String get settingsKeyField;

  /// No description provided for @settingsKeyDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar clave'**
  String get settingsKeyDelete;

  /// No description provided for @translateTargetEn.
  ///
  /// In es, this message translates to:
  /// **'Inglés'**
  String get translateTargetEn;

  /// No description provided for @translateTargetEs.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get translateTargetEs;

  /// No description provided for @translateTargetPt.
  ///
  /// In es, this message translates to:
  /// **'Portugués'**
  String get translateTargetPt;

  /// No description provided for @translateTargetFr.
  ///
  /// In es, this message translates to:
  /// **'Francés'**
  String get translateTargetFr;

  /// No description provided for @translateTargetIt.
  ///
  /// In es, this message translates to:
  /// **'Italiano'**
  String get translateTargetIt;

  /// No description provided for @translateTargetDe.
  ///
  /// In es, this message translates to:
  /// **'Alemán'**
  String get translateTargetDe;

  /// No description provided for @keyboardSizeHeader.
  ///
  /// In es, this message translates to:
  /// **'Tamaño'**
  String get keyboardSizeHeader;

  /// No description provided for @keyboardHeight.
  ///
  /// In es, this message translates to:
  /// **'Altura'**
  String get keyboardHeight;

  /// No description provided for @keyboardHeightLow.
  ///
  /// In es, this message translates to:
  /// **'Baja'**
  String get keyboardHeightLow;

  /// No description provided for @keyboardHeightMedium.
  ///
  /// In es, this message translates to:
  /// **'Media'**
  String get keyboardHeightMedium;

  /// No description provided for @keyboardHeightHigh.
  ///
  /// In es, this message translates to:
  /// **'Alta'**
  String get keyboardHeightHigh;

  /// No description provided for @keyboardHeightVeryHigh.
  ///
  /// In es, this message translates to:
  /// **'Muy alta'**
  String get keyboardHeightVeryHigh;

  /// No description provided for @keyboardSpacing.
  ///
  /// In es, this message translates to:
  /// **'Separación'**
  String get keyboardSpacing;

  /// No description provided for @keyboardSpacingCompact.
  ///
  /// In es, this message translates to:
  /// **'Compacta'**
  String get keyboardSpacingCompact;

  /// No description provided for @keyboardNormal.
  ///
  /// In es, this message translates to:
  /// **'Normal'**
  String get keyboardNormal;

  /// No description provided for @keyboardSpacingWide.
  ///
  /// In es, this message translates to:
  /// **'Amplia'**
  String get keyboardSpacingWide;

  /// No description provided for @keyboardSpacingMax.
  ///
  /// In es, this message translates to:
  /// **'Máxima'**
  String get keyboardSpacingMax;

  /// No description provided for @keyboardBottomDistance.
  ///
  /// In es, this message translates to:
  /// **'Distancia al borde'**
  String get keyboardBottomDistance;

  /// No description provided for @keyboardBottomNone.
  ///
  /// In es, this message translates to:
  /// **'Ninguna'**
  String get keyboardBottomNone;

  /// No description provided for @keyboardKeysHeader.
  ///
  /// In es, this message translates to:
  /// **'Teclas'**
  String get keyboardKeysHeader;

  /// No description provided for @keyboardKeysFooter.
  ///
  /// In es, this message translates to:
  /// **'Ocultá las que no uses y el teclado gana espacio.'**
  String get keyboardKeysFooter;

  /// No description provided for @keyboardTerminalRow.
  ///
  /// In es, this message translates to:
  /// **'Fila de terminal'**
  String get keyboardTerminalRow;

  /// No description provided for @keyboardCodeKey.
  ///
  /// In es, this message translates to:
  /// **'Tecla de código'**
  String get keyboardCodeKey;

  /// No description provided for @keyboardLanguageKey.
  ///
  /// In es, this message translates to:
  /// **'Tecla de idioma'**
  String get keyboardLanguageKey;

  /// No description provided for @keyboardCredentialsKey.
  ///
  /// In es, this message translates to:
  /// **'Llave de claves'**
  String get keyboardCredentialsKey;

  /// No description provided for @keyboardTypingHeader.
  ///
  /// In es, this message translates to:
  /// **'Escritura'**
  String get keyboardTypingHeader;

  /// No description provided for @keyboardMoveCursor.
  ///
  /// In es, this message translates to:
  /// **'Mover el cursor'**
  String get keyboardMoveCursor;

  /// No description provided for @keyboardCursorHold2dDetail.
  ///
  /// In es, this message translates to:
  /// **'en 2D'**
  String get keyboardCursorHold2dDetail;

  /// No description provided for @keyboardCursorSlide.
  ///
  /// In es, this message translates to:
  /// **'Deslizar'**
  String get keyboardCursorSlide;

  /// No description provided for @keyboardCursorSlideDetail.
  ///
  /// In es, this message translates to:
  /// **'lateral'**
  String get keyboardCursorSlideDetail;

  /// No description provided for @keyboardSpacebar.
  ///
  /// In es, this message translates to:
  /// **'Barra espaciadora'**
  String get keyboardSpacebar;

  /// No description provided for @keyboardAlignCenter.
  ///
  /// In es, this message translates to:
  /// **'Centrada'**
  String get keyboardAlignCenter;

  /// No description provided for @keyboardMicLeft.
  ///
  /// In es, this message translates to:
  /// **'Micrófono a la izquierda'**
  String get keyboardMicLeft;

  /// No description provided for @keyboardLongPressSymbols.
  ///
  /// In es, this message translates to:
  /// **'Símbolos al mantener'**
  String get keyboardLongPressSymbols;

  /// No description provided for @keyboardLongPressDelay.
  ///
  /// In es, this message translates to:
  /// **'Espera'**
  String get keyboardLongPressDelay;

  /// No description provided for @keyboardDelayShort.
  ///
  /// In es, this message translates to:
  /// **'Corta'**
  String get keyboardDelayShort;

  /// No description provided for @keyboardDelayLong.
  ///
  /// In es, this message translates to:
  /// **'Larga'**
  String get keyboardDelayLong;

  /// No description provided for @settingsHapticsSound.
  ///
  /// In es, this message translates to:
  /// **'Vibración y sonido'**
  String get settingsHapticsSound;

  /// No description provided for @keyboardHapticsOn.
  ///
  /// In es, this message translates to:
  /// **'Activados'**
  String get keyboardHapticsOn;

  /// No description provided for @keyboardHapticsOff.
  ///
  /// In es, this message translates to:
  /// **'Sin vibración'**
  String get keyboardHapticsOff;

  /// No description provided for @keyboardClipboardHeader.
  ///
  /// In es, this message translates to:
  /// **'Portapapeles'**
  String get keyboardClipboardHeader;

  /// No description provided for @keyboardClipboardFooter.
  ///
  /// In es, this message translates to:
  /// **'Apagado guarda solo texto y ocupa menos memoria.'**
  String get keyboardClipboardFooter;

  /// No description provided for @keyboardClipboardImages.
  ///
  /// In es, this message translates to:
  /// **'Guardar imágenes'**
  String get keyboardClipboardImages;

  /// No description provided for @keyboardActiveTitle.
  ///
  /// In es, this message translates to:
  /// **'VoiceBubble está activo'**
  String get keyboardActiveTitle;

  /// No description provided for @keyboardActiveSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Es tu teclado en todas las apps.'**
  String get keyboardActiveSubtitle;

  /// No description provided for @keyboardSwitch.
  ///
  /// In es, this message translates to:
  /// **'Cambiar de teclado'**
  String get keyboardSwitch;

  /// No description provided for @keyboardSetupHeader.
  ///
  /// In es, this message translates to:
  /// **'Activalo en dos pasos'**
  String get keyboardSetupHeader;

  /// No description provided for @keyboardSetupFooter.
  ///
  /// In es, this message translates to:
  /// **'Al volver de Android, el selector se abre solo.'**
  String get keyboardSetupFooter;

  /// No description provided for @keyboardEnabledTitle.
  ///
  /// In es, this message translates to:
  /// **'Activado en Android'**
  String get keyboardEnabledTitle;

  /// No description provided for @keyboardEnabledSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Falta elegirlo como teclado.'**
  String get keyboardEnabledSubtitle;

  /// No description provided for @keyboardStep1.
  ///
  /// In es, this message translates to:
  /// **'1. Activar en Android'**
  String get keyboardStep1;

  /// No description provided for @keyboardStep2.
  ///
  /// In es, this message translates to:
  /// **'2. Elegir VoiceBubble'**
  String get keyboardStep2;

  /// No description provided for @keyboardTone1.
  ///
  /// In es, this message translates to:
  /// **'Tono 1'**
  String get keyboardTone1;

  /// No description provided for @keyboardTone2.
  ///
  /// In es, this message translates to:
  /// **'Tono 2'**
  String get keyboardTone2;

  /// No description provided for @keyboardTone3.
  ///
  /// In es, this message translates to:
  /// **'Tono 3'**
  String get keyboardTone3;

  /// No description provided for @keyboardTone4.
  ///
  /// In es, this message translates to:
  /// **'Tono 4'**
  String get keyboardTone4;

  /// No description provided for @keyboardTypingSub.
  ///
  /// In es, this message translates to:
  /// **'Al escribir'**
  String get keyboardTypingSub;

  /// No description provided for @keyboardHapticsToggle.
  ///
  /// In es, this message translates to:
  /// **'Vibrar al tocar'**
  String get keyboardHapticsToggle;

  /// No description provided for @keyboardIntensity.
  ///
  /// In es, this message translates to:
  /// **'Intensidad'**
  String get keyboardIntensity;

  /// No description provided for @keyboardIntensitySharp.
  ///
  /// In es, this message translates to:
  /// **'Nítida'**
  String get keyboardIntensitySharp;

  /// No description provided for @keyboardIntensitySharpDetail.
  ///
  /// In es, this message translates to:
  /// **'clic seco'**
  String get keyboardIntensitySharpDetail;

  /// No description provided for @keyboardIntensityFirm.
  ///
  /// In es, this message translates to:
  /// **'Firme'**
  String get keyboardIntensityFirm;

  /// No description provided for @keyboardIntensityFirmDetail.
  ///
  /// In es, this message translates to:
  /// **'marcada'**
  String get keyboardIntensityFirmDetail;

  /// No description provided for @keyboardIntensitySoft.
  ///
  /// In es, this message translates to:
  /// **'Suave'**
  String get keyboardIntensitySoft;

  /// No description provided for @keyboardIntensitySoftDetail.
  ///
  /// In es, this message translates to:
  /// **'leve'**
  String get keyboardIntensitySoftDetail;

  /// No description provided for @keyboardDictatingHeader.
  ///
  /// In es, this message translates to:
  /// **'Al dictar'**
  String get keyboardDictatingHeader;

  /// No description provided for @keyboardDictatingFooter.
  ///
  /// In es, this message translates to:
  /// **'Funciona aparte de la vibración de las teclas.'**
  String get keyboardDictatingFooter;

  /// No description provided for @keyboardMicVibration.
  ///
  /// In es, this message translates to:
  /// **'Vibración'**
  String get keyboardMicVibration;

  /// No description provided for @keyboardMicOnStart.
  ///
  /// In es, this message translates to:
  /// **'Al empezar'**
  String get keyboardMicOnStart;

  /// No description provided for @keyboardMicWhileRecording.
  ///
  /// In es, this message translates to:
  /// **'Mientras graba'**
  String get keyboardMicWhileRecording;

  /// No description provided for @keyboardMicOnPaste.
  ///
  /// In es, this message translates to:
  /// **'Al pegar'**
  String get keyboardMicOnPaste;

  /// No description provided for @keyboardMicOnCancel.
  ///
  /// In es, this message translates to:
  /// **'Al cancelar'**
  String get keyboardMicOnCancel;

  /// No description provided for @keyboardMicSoundsHeader.
  ///
  /// In es, this message translates to:
  /// **'Sonidos del micrófono'**
  String get keyboardMicSoundsHeader;

  /// No description provided for @keyboardMicSounds.
  ///
  /// In es, this message translates to:
  /// **'Sonidos'**
  String get keyboardMicSounds;

  /// No description provided for @keyboardMicOnStop.
  ///
  /// In es, this message translates to:
  /// **'Al terminar'**
  String get keyboardMicOnStop;

  /// No description provided for @trackpadPointerActive.
  ///
  /// In es, this message translates to:
  /// **'Activo'**
  String get trackpadPointerActive;

  /// No description provided for @trackpadPointerEnable.
  ///
  /// In es, this message translates to:
  /// **'Activar'**
  String get trackpadPointerEnable;

  /// No description provided for @trackpadPointerNotInstalled.
  ///
  /// In es, this message translates to:
  /// **'No instalado'**
  String get trackpadPointerNotInstalled;

  /// No description provided for @trackpadRestrictedRow.
  ///
  /// In es, this message translates to:
  /// **'Permitir ajustes restringidos'**
  String get trackpadRestrictedRow;

  /// No description provided for @trackpadFooterReady.
  ///
  /// In es, this message translates to:
  /// **'Los clics del puntero llegan a cualquier app. No lee la pantalla ni guarda nada.'**
  String get trackpadFooterReady;

  /// No description provided for @trackpadFooterDisabled.
  ///
  /// In es, this message translates to:
  /// **'Activalo en Accesibilidad. Si Android dice «Ajuste restringido», tocá Permitir ajustes restringidos y volvé a intentar.'**
  String get trackpadFooterDisabled;

  /// No description provided for @trackpadFooterMissing.
  ///
  /// In es, this message translates to:
  /// **'Para hacer clic en otras apps hace falta el complemento VoiceBubble Puntero. Sin él, el puntero se mueve pero no hace clic.'**
  String get trackpadFooterMissing;

  /// No description provided for @trackpadOtherAppsHeader.
  ///
  /// In es, this message translates to:
  /// **'Puntero en otras apps'**
  String get trackpadOtherAppsHeader;

  /// No description provided for @trackpadOpenFooter.
  ///
  /// In es, this message translates to:
  /// **'Se abre desde la barra flotante. Para cerrarlo, tocá la línea de arriba.'**
  String get trackpadOpenFooter;

  /// No description provided for @trackpadOpenAs.
  ///
  /// In es, this message translates to:
  /// **'Se abre como'**
  String get trackpadOpenAs;

  /// No description provided for @trackpadOpenPanel.
  ///
  /// In es, this message translates to:
  /// **'Panel abajo'**
  String get trackpadOpenPanel;

  /// No description provided for @trackpadOpenWindow.
  ///
  /// In es, this message translates to:
  /// **'Ventana flotante'**
  String get trackpadOpenWindow;

  /// No description provided for @trackpadAutoReturn.
  ///
  /// In es, this message translates to:
  /// **'Al soltar'**
  String get trackpadAutoReturn;

  /// No description provided for @trackpadStaysOpen.
  ///
  /// In es, this message translates to:
  /// **'Queda abierto'**
  String get trackpadStaysOpen;

  /// No description provided for @trackpadClosesIn5.
  ///
  /// In es, this message translates to:
  /// **'Se cierra a los 5 s'**
  String get trackpadClosesIn5;

  /// No description provided for @trackpadClosesIn15.
  ///
  /// In es, this message translates to:
  /// **'Se cierra a los 15 s'**
  String get trackpadClosesIn15;

  /// No description provided for @trackpadClosesIn30.
  ///
  /// In es, this message translates to:
  /// **'Se cierra a los 30 s'**
  String get trackpadClosesIn30;

  /// No description provided for @trackpadKeyboardHeader.
  ///
  /// In es, this message translates to:
  /// **'En el teclado'**
  String get trackpadKeyboardHeader;

  /// No description provided for @trackpadKeyboardFooter.
  ///
  /// In es, this message translates to:
  /// **'Un puntero dentro del teclado para mover el cursor con precisión.'**
  String get trackpadKeyboardFooter;

  /// No description provided for @trackpadKeyboardSwitch.
  ///
  /// In es, this message translates to:
  /// **'Trackpad en el teclado'**
  String get trackpadKeyboardSwitch;

  /// No description provided for @trackpadToolbarSwitch.
  ///
  /// In es, this message translates to:
  /// **'Acceso en la barra del teclado'**
  String get trackpadToolbarSwitch;

  /// No description provided for @trackpadAcceleration.
  ///
  /// In es, this message translates to:
  /// **'Aceleración'**
  String get trackpadAcceleration;

  /// No description provided for @trackpadAccelDynamic.
  ///
  /// In es, this message translates to:
  /// **'Dinámica'**
  String get trackpadAccelDynamic;

  /// No description provided for @trackpadAccelLinear.
  ///
  /// In es, this message translates to:
  /// **'Lineal'**
  String get trackpadAccelLinear;

  /// No description provided for @trackpadAccelPrecision.
  ///
  /// In es, this message translates to:
  /// **'Precisión'**
  String get trackpadAccelPrecision;

  /// No description provided for @trackpadShapeArrow.
  ///
  /// In es, this message translates to:
  /// **'Flecha'**
  String get trackpadShapeArrow;

  /// No description provided for @trackpadShapeDot.
  ///
  /// In es, this message translates to:
  /// **'Punto'**
  String get trackpadShapeDot;

  /// No description provided for @trackpadShapeCross.
  ///
  /// In es, this message translates to:
  /// **'Cruz'**
  String get trackpadShapeCross;

  /// No description provided for @trackpadClickHeader.
  ///
  /// In es, this message translates to:
  /// **'Clic'**
  String get trackpadClickHeader;

  /// No description provided for @trackpadTapToClick.
  ///
  /// In es, this message translates to:
  /// **'Tocar para hacer clic'**
  String get trackpadTapToClick;

  /// No description provided for @trackpadSecondaryClick.
  ///
  /// In es, this message translates to:
  /// **'Clic secundario'**
  String get trackpadSecondaryClick;

  /// No description provided for @trackpadTwoFingers.
  ///
  /// In es, this message translates to:
  /// **'Dos dedos'**
  String get trackpadTwoFingers;

  /// No description provided for @trackpadRightButton.
  ///
  /// In es, this message translates to:
  /// **'Botón derecho'**
  String get trackpadRightButton;

  /// No description provided for @trackpadButtons.
  ///
  /// In es, this message translates to:
  /// **'Botones'**
  String get trackpadButtons;

  /// No description provided for @trackpadButtonsTop.
  ///
  /// In es, this message translates to:
  /// **'Arriba'**
  String get trackpadButtonsTop;

  /// No description provided for @trackpadButtonsSides.
  ///
  /// In es, this message translates to:
  /// **'A los lados'**
  String get trackpadButtonsSides;

  /// No description provided for @trackpadScrollHeader.
  ///
  /// In es, this message translates to:
  /// **'Desplazamiento'**
  String get trackpadScrollHeader;

  /// No description provided for @trackpadScrollBar.
  ///
  /// In es, this message translates to:
  /// **'Barra de scroll'**
  String get trackpadScrollBar;

  /// No description provided for @trackpadScrollRight.
  ///
  /// In es, this message translates to:
  /// **'Derecha'**
  String get trackpadScrollRight;

  /// No description provided for @trackpadScrollLeft.
  ///
  /// In es, this message translates to:
  /// **'Izquierda'**
  String get trackpadScrollLeft;

  /// No description provided for @trackpadScrollHidden.
  ///
  /// In es, this message translates to:
  /// **'Oculta'**
  String get trackpadScrollHidden;

  /// No description provided for @trackpadScrollDirection.
  ///
  /// In es, this message translates to:
  /// **'Dirección'**
  String get trackpadScrollDirection;

  /// No description provided for @trackpadScrollNatural.
  ///
  /// In es, this message translates to:
  /// **'Natural'**
  String get trackpadScrollNatural;

  /// No description provided for @trackpadScrollInverted.
  ///
  /// In es, this message translates to:
  /// **'Invertida'**
  String get trackpadScrollInverted;

  /// No description provided for @trackpadOtherHeader.
  ///
  /// In es, this message translates to:
  /// **'Otros'**
  String get trackpadOtherHeader;

  /// No description provided for @trackpadHaptics.
  ///
  /// In es, this message translates to:
  /// **'Vibración'**
  String get trackpadHaptics;

  /// No description provided for @trackpadHapticSubtle.
  ///
  /// In es, this message translates to:
  /// **'Sutil'**
  String get trackpadHapticSubtle;

  /// No description provided for @trackpadSpeed.
  ///
  /// In es, this message translates to:
  /// **'Velocidad'**
  String get trackpadSpeed;

  /// No description provided for @trackpadSlow.
  ///
  /// In es, this message translates to:
  /// **'Lenta'**
  String get trackpadSlow;

  /// No description provided for @trackpadSpeedSemantics.
  ///
  /// In es, this message translates to:
  /// **'Velocidad {value}'**
  String trackpadSpeedSemantics(String value);

  /// No description provided for @trackpadFast.
  ///
  /// In es, this message translates to:
  /// **'Rápida'**
  String get trackpadFast;

  /// No description provided for @dateToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get dateToday;

  /// No description provided for @dateYesterday.
  ///
  /// In es, this message translates to:
  /// **'Ayer'**
  String get dateYesterday;

  /// No description provided for @dateThisWeek.
  ///
  /// In es, this message translates to:
  /// **'Esta semana'**
  String get dateThisWeek;

  /// 12 meses en minúscula separados por coma
  ///
  /// In es, this message translates to:
  /// **'enero,febrero,marzo,abril,mayo,junio,julio,agosto,septiembre,octubre,noviembre,diciembre'**
  String get dateMonths;

  /// 12 abreviaturas de mes separadas por coma
  ///
  /// In es, this message translates to:
  /// **'ene,feb,mar,abr,may,jun,jul,ago,sep,oct,nov,dic'**
  String get dateMonthsShort;

  /// No description provided for @dateShort.
  ///
  /// In es, this message translates to:
  /// **'{day} {month}'**
  String dateShort(String day, String month);

  /// No description provided for @dateShortYear.
  ///
  /// In es, this message translates to:
  /// **'{day} {month} {year}'**
  String dateShortYear(String day, String month, String year);

  /// No description provided for @dateMonthYear.
  ///
  /// In es, this message translates to:
  /// **'{month} {year}'**
  String dateMonthYear(String month, String year);

  /// No description provided for @settingsLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In es, this message translates to:
  /// **'Del teléfono'**
  String get settingsLanguageSystem;

  /// No description provided for @errSttKeyMissing.
  ///
  /// In es, this message translates to:
  /// **'Falta la API key de Groq. Agregala en Ajustes.'**
  String get errSttKeyMissing;

  /// No description provided for @errAudioNotFound.
  ///
  /// In es, this message translates to:
  /// **'No se encontró el archivo de audio.'**
  String get errAudioNotFound;

  /// No description provided for @errAudioTooShort.
  ///
  /// In es, this message translates to:
  /// **'El audio es demasiado corto para transcribir.'**
  String get errAudioTooShort;

  /// No description provided for @errAudioTooLarge.
  ///
  /// In es, this message translates to:
  /// **'El audio supera el límite de 25 MB.'**
  String get errAudioTooLarge;

  /// No description provided for @errAudioDamaged.
  ///
  /// In es, this message translates to:
  /// **'El audio está dañado [{detail}] y no se puede transcribir. Grabalo de nuevo.'**
  String errAudioDamaged(String detail);

  /// No description provided for @errAudioUnreadable.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer el audio para subirlo.'**
  String get errAudioUnreadable;

  /// No description provided for @errSttKeyInvalid.
  ///
  /// In es, this message translates to:
  /// **'API key inválida. Revisá tu clave en Ajustes.'**
  String get errSttKeyInvalid;

  /// No description provided for @errSttRateLimit.
  ///
  /// In es, this message translates to:
  /// **'Límite de solicitudes alcanzado. Esperá un momento e intentá de nuevo.'**
  String get errSttRateLimit;

  /// No description provided for @errGroqError.
  ///
  /// In es, this message translates to:
  /// **'Error {code} de Groq: {detail}'**
  String errGroqError(String code, String detail);

  /// No description provided for @errGroqServer.
  ///
  /// In es, this message translates to:
  /// **'Error del servidor de Groq ({code}). Intentá de nuevo.'**
  String errGroqServer(String code);

  /// No description provided for @errInvalidResponse.
  ///
  /// In es, this message translates to:
  /// **'Respuesta inválida del servidor. Intentá de nuevo.'**
  String get errInvalidResponse;

  /// No description provided for @errEmptyTranscript.
  ///
  /// In es, this message translates to:
  /// **'El servidor no devolvió texto para ese audio.'**
  String get errEmptyTranscript;

  /// No description provided for @errNoInternet.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión a internet.'**
  String get errNoInternet;

  /// No description provided for @errTimeout.
  ///
  /// In es, this message translates to:
  /// **'Tiempo de espera agotado al conectar con el servidor.'**
  String get errTimeout;

  /// No description provided for @errUnexpectedTranscribe.
  ///
  /// In es, this message translates to:
  /// **'Error inesperado al transcribir.'**
  String get errUnexpectedTranscribe;

  /// No description provided for @errMicPermission.
  ///
  /// In es, this message translates to:
  /// **'Permiso de micrófono denegado.'**
  String get errMicPermission;

  /// No description provided for @errMicBusy.
  ///
  /// In es, this message translates to:
  /// **'El teclado está usando el micrófono.'**
  String get errMicBusy;

  /// No description provided for @errUploadInFlight.
  ///
  /// In es, this message translates to:
  /// **'Ya hay una transcripción en curso. Esperá a que termine.'**
  String get errUploadInFlight;

  /// No description provided for @errHistorySaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la transcripción en el historial (disco lleno o error de almacenamiento).'**
  String get errHistorySaveFailed;

  /// No description provided for @errAiTimeout.
  ///
  /// In es, this message translates to:
  /// **'Tiempo de espera agotado'**
  String get errAiTimeout;

  /// No description provided for @errAiNetwork.
  ///
  /// In es, this message translates to:
  /// **'Error de red. Revisá tu conexión.'**
  String get errAiNetwork;

  /// No description provided for @errAiInvalidResponse.
  ///
  /// In es, this message translates to:
  /// **'Respuesta inválida del modelo'**
  String get errAiInvalidResponse;

  /// No description provided for @errAiEmptyResponse.
  ///
  /// In es, this message translates to:
  /// **'Respuesta vacía del modelo'**
  String get errAiEmptyResponse;

  /// No description provided for @errAiKeyInvalid.
  ///
  /// In es, this message translates to:
  /// **'Clave de {provider} inválida ({code}) {detail}'**
  String errAiKeyInvalid(String provider, String code, String detail);

  /// No description provided for @errAiModelUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Modelo no disponible: {detail}'**
  String errAiModelUnavailable(String detail);

  /// No description provided for @errAiLimit.
  ///
  /// In es, this message translates to:
  /// **'Límite de {provider} alcanzado: {detail}'**
  String errAiLimit(String provider, String detail);

  /// No description provided for @errAiServer.
  ///
  /// In es, this message translates to:
  /// **'Error del servidor ({code}): {detail}'**
  String errAiServer(String code, String detail);

  /// No description provided for @errAiHttp.
  ///
  /// In es, this message translates to:
  /// **'Error {code}: {detail}'**
  String errAiHttp(String code, String detail);

  /// No description provided for @errAiTooLong.
  ///
  /// In es, this message translates to:
  /// **'La nota es muy larga para Groq gratis (unos 20.000 caracteres como máximo). Para notas largas elegí Google en Ajustes › Inteligencia artificial.'**
  String get errAiTooLong;

  /// No description provided for @settingsSpokenLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma en que hablo'**
  String get settingsSpokenLanguage;

  /// No description provided for @settingsSpokenLanguageAuto.
  ///
  /// In es, this message translates to:
  /// **'Automático'**
  String get settingsSpokenLanguageAuto;

  /// No description provided for @settingsSpokenLanguageAutoFooter.
  ///
  /// In es, this message translates to:
  /// **'Automático: Whisper detecta el idioma en cada dictado. Si confunde el idioma, elegí uno fijo.'**
  String get settingsSpokenLanguageAutoFooter;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
