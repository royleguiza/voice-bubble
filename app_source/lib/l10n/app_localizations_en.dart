// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get copyButtonLabel => 'Copy';

  @override
  String get copyTooltipMessage => 'Copy to clipboard';

  @override
  String get copiedToClipboardMessage => 'Text copied';

  @override
  String get clipboardFailureMessage => 'Couldn\'t copy to the clipboard';

  @override
  String get historyEmptyMessage => 'No transcriptions yet';

  @override
  String get noteAudioNotFound => 'Audio not found';

  @override
  String get noteAudioCorrupt => 'Damaged audio; delete it and record again';

  @override
  String get noteAudioChip => 'Audio';

  @override
  String get noteUntitled => 'Untitled';

  @override
  String get noteCopyTooltip => 'Copy text';

  @override
  String get noteCardHint => 'Long press for more actions';

  @override
  String get recordingStatusRecording => 'Recording...';

  @override
  String get recordingStatusProcessing => 'Processing...';

  @override
  String get recordingStatusError => 'Error, tap to retry';

  @override
  String get recordingStatusReady => 'Ready to transcribe';

  @override
  String islandMockupDescription(
      String cx, String top, String width, String height, String side) {
    return 'Island preview: center $cx pixels from the left edge, top edge at $top pixels, $width wide by $height tall. Microphone on the $side.';
  }

  @override
  String get islandMicLeft => 'left';

  @override
  String get islandMicRight => 'right';

  @override
  String get noteAudioStop => 'Stop audio';

  @override
  String get noteAudioPlay => 'Play audio';

  @override
  String noteAudioPlayWithDuration(String duration) {
    return 'Play audio, $duration';
  }

  @override
  String noteCardSemantics(String title) {
    return 'Note: $title';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get homeTabNotes => 'Notes';

  @override
  String get homeTabHistory => 'History';

  @override
  String get homeSearchClear => 'Clear search';

  @override
  String get noteActionOpen => 'Open and edit';

  @override
  String get noteActionCopy => 'Copy text';

  @override
  String get noteActionDeleteAudio => 'Delete audio, keep text';

  @override
  String get noteActionDelete => 'Delete note';

  @override
  String get recordStop => 'Stop recording';

  @override
  String get recordTranscribing => 'Transcribing';

  @override
  String get recordHoldToRecord => 'Hold to record';

  @override
  String get recordStart => 'Start recording';

  @override
  String get recordDiscard => 'Discard recording';

  @override
  String pendingAgoMinutes(String n) {
    return '${n}m ago';
  }

  @override
  String pendingAgoHours(String n) {
    return '${n}h ago';
  }

  @override
  String get pendingYesterday => 'yesterday';

  @override
  String pendingAgoDays(String n) {
    return '${n}d ago';
  }

  @override
  String pendingSemantics(String when) {
    return 'Untranscribed audio, $when';
  }

  @override
  String get pendingTitle => 'Untranscribed audio';

  @override
  String get pendingUnplayable => 'Couldn\'t play this audio';

  @override
  String get pendingTranscribe => 'Transcribe';

  @override
  String get pendingDiscard => 'Discard audio';

  @override
  String get pendingPause => 'Pause';

  @override
  String get pendingPlay => 'Play audio';

  @override
  String get pendingClosePlayer => 'Close player';

  @override
  String get unitPx => 'px';

  @override
  String get unitPxSpoken => 'pixels';

  @override
  String get credentialsDeleteTitle => 'Delete login';

  @override
  String credentialsDeleteConfirm(String name) {
    return 'Delete \"$name\"? This can\'t be undone.';
  }

  @override
  String get credentialsDeleteButton => 'Delete';

  @override
  String get credentialsShowUserFooter =>
      'Next to the name, in the keyboard list.';

  @override
  String get credentialsShowUser => 'Show username';

  @override
  String get credentialsEmptyTitle => 'No saved logins';

  @override
  String get credentialsEmptyMessage =>
      'Save a username and password to fill them in from the keyboard\'s key button.';

  @override
  String get credentialsAdd => 'Add login';

  @override
  String get credentialsSavedHeader => 'Saved';

  @override
  String credentialsCountFooter(String count, String max) {
    return '$count of $max · The password is never shown.';
  }

  @override
  String credentialsDeleteNamed(String name) {
    return 'Delete $name';
  }

  @override
  String get credentialsFormError =>
      'Check the fields: name and username can\'t be empty.';

  @override
  String get credentialsNewTitle => 'New login';

  @override
  String get credentialsFieldName => 'Name';

  @override
  String get credentialsFieldNameHint => 'E.g. Bank';

  @override
  String get credentialsFieldUser => 'Username';

  @override
  String get credentialsFieldUserHint => 'Username or email';

  @override
  String get credentialsFieldPassword => 'Password';

  @override
  String get credentialsFieldPasswordHint => 'Write-only, never shown';

  @override
  String get credentialsFormHint =>
      'Stored encrypted. The keyboard fills it in only in password fields.';

  @override
  String get islandTitle => 'Adjust island';

  @override
  String get islandNeedsPointer =>
      'The island needs Orison Pointer turned on: without it, it shows as a bubble and these settings have no effect.';

  @override
  String get islandNeedsBar =>
      'Turn on the floating bar to see the island on your screen.';

  @override
  String get islandPositionHeader => 'Position';

  @override
  String get islandPositionFooter =>
      'Horizontal: the center of the island. Vertical: its top edge. In full-screen pixels.';

  @override
  String get islandPositionX => 'Horizontal position';

  @override
  String get islandPixelLeft => 'One pixel left';

  @override
  String get islandPixelRight => 'One pixel right';

  @override
  String get islandPositionY => 'Vertical position';

  @override
  String get islandPixelUp => 'One pixel up';

  @override
  String get islandPixelDown => 'One pixel down';

  @override
  String get islandSizeHeader => 'Resting size';

  @override
  String get islandSizeFooter =>
      'While recording, the island grows on its own.';

  @override
  String get islandWidth => 'Width';

  @override
  String get islandNarrower => 'One pixel narrower';

  @override
  String get islandWider => 'One pixel wider';

  @override
  String get islandHeight => 'Height';

  @override
  String get islandShorter => 'One pixel shorter';

  @override
  String get islandTaller => 'One pixel taller';

  @override
  String get islandSideFooter => 'The pointer goes on the other side.';

  @override
  String get islandSideTitle => 'Microphone side';

  @override
  String get islandSideLeft => 'Left';

  @override
  String get islandSideRight => 'Right';

  @override
  String get islandCenterTop => 'Center at top';

  @override
  String get islandReset => 'Reset';

  @override
  String get noteEditorWriteFirst => 'Write or dictate a note first';

  @override
  String noteEditorUnexpectedError(String error) {
    return 'Unexpected error: $error';
  }

  @override
  String get noteEditorAiErrorTitle => 'AI error';

  @override
  String get noteEditorClose => 'Close';

  @override
  String get noteEditorAiTitleSuggested => 'Suggested title';

  @override
  String get noteEditorAiSummaryTitle => 'Note summary';

  @override
  String get noteEditorDiscard => 'Discard';

  @override
  String get noteEditorReplace => 'Replace';

  @override
  String get noteEditorBodyRequired => 'Body required';

  @override
  String get noteEditorLimitOrError => 'Limit reached or error';

  @override
  String get noteEditorClipboardEmpty => 'The clipboard is empty';

  @override
  String get noteEditorNothingToCopy => 'Nothing to copy';

  @override
  String get noteEditorDelete => 'Delete note';

  @override
  String get noteEditorDeleteWithAudio =>
      'The text and audio will be deleted. This can\'t be undone.';

  @override
  String get noteEditorDeleteTextOnly => 'This can\'t be undone.';

  @override
  String get noteEditorDeleteConfirm => 'Delete';

  @override
  String get noteEditorNewNote => 'New note';

  @override
  String noteEditorMetaGroupTime(String group, String time) {
    return '$group, $time';
  }

  @override
  String get noteEditorTitleLabel => 'Title';

  @override
  String get noteEditorAiTitleButton => 'Generate title with AI';

  @override
  String get noteEditorBodyHint => 'Type or paste the note\'s text';

  @override
  String get commonBack => 'Back';

  @override
  String get noteEditorPaste => 'Paste';

  @override
  String get noteEditorCopy => 'Copy text';

  @override
  String get noteEditorAiSummarize => 'Summarize with AI';

  @override
  String get snippetSaveFailed => 'Couldn\'t save the snippet.';

  @override
  String snippetSaveFailedLimit(String max) {
    return 'Couldn\'t save the snippet: limit of $max snippets reached or temporary data unreadable.';
  }

  @override
  String get snippetColorBlue => 'blue';

  @override
  String get snippetColorGreen => 'green';

  @override
  String get snippetColorRed => 'red';

  @override
  String get snippetColorOrange => 'orange';

  @override
  String get snippetColorViolet => 'violet';

  @override
  String get snippetColorGray => 'gray';

  @override
  String get snippetDelete => 'Delete snippet';

  @override
  String snippetDeleteConfirm(String name) {
    return 'Delete \"$name\"? This can\'t be undone.';
  }

  @override
  String get snippetDeleteButton => 'Delete';

  @override
  String get snippetsEmptyTitle => 'No snippets';

  @override
  String get snippetsEmptyMessage =>
      'Save text you use often and paste it with one tap from the keyboard.';

  @override
  String get snippetsCreate => 'Create snippet';

  @override
  String snippetsNoResults(String query) {
    return 'No results for \"$query\".';
  }

  @override
  String snippetsCountFooter(String count, String max) {
    return '$count of $max · Inserted with one tap from the keyboard.';
  }

  @override
  String get snippetsReorderDone => 'Done';

  @override
  String get snippetsReorder => 'Reorder';

  @override
  String get snippetsSearchHint => 'Search';

  @override
  String snippetRowSemantics(String name, String preview) {
    return '$name. $preview';
  }

  @override
  String snippetMoveUp(String name) {
    return 'Move $name up';
  }

  @override
  String snippetMoveDown(String name) {
    return 'Move $name down';
  }

  @override
  String get snippetNameRequired => 'Name is required';

  @override
  String snippetMaxChars(String max) {
    return 'Up to $max characters';
  }

  @override
  String get snippetSheetEdit => 'Edit snippet';

  @override
  String get snippetSheetNew => 'New snippet';

  @override
  String get snippetFieldName => 'Name';

  @override
  String get snippetFieldNameHint => 'E.g. Signature';

  @override
  String get snippetFieldText => 'Text';

  @override
  String get snippetFieldTextHint => 'What will be inserted';

  @override
  String snippetContentCounter(String length, String max) {
    return '$length / $max';
  }

  @override
  String get snippetColorLabel => 'Color';

  @override
  String get snippetColorNone => 'No color';

  @override
  String get homeStatusRelease => 'Release to finish';

  @override
  String get homeStatusTranscribing => 'Transcribing…';

  @override
  String get homeStatusError => 'Error, tap to retry';

  @override
  String homeRecordStartError(String error) {
    return 'Couldn\'t start recording: $error';
  }

  @override
  String get homeNoteSaved => 'Note saved';

  @override
  String homeNoteNotSavedFull(String max) {
    return 'Note not saved: you reached $max notes. The text was copied and kept in History.';
  }

  @override
  String get homeAudioNotKept =>
      'Couldn\'t keep the audio. The text is in History.';

  @override
  String get homeNoteNotSavedTextKept =>
      'Note not saved; the text is in History';

  @override
  String homeError(String error) {
    return 'Error: $error';
  }

  @override
  String get homeRetry => 'Retry';

  @override
  String get homeOfflineAudioSaved => 'Offline · audio saved in Notes';

  @override
  String get homePendingAudioGone => 'The pending audio is no longer available';

  @override
  String get homeAudioNotKeptShort => 'Couldn\'t keep the audio';

  @override
  String get homeNoteNotSavedAudioKept => 'Note not saved; the audio is kept';

  @override
  String get homeNoteSavedAudioPending => 'Note saved; the audio stays pending';

  @override
  String get homeApiKeyMissing => 'API key missing. Set it up in Settings.';

  @override
  String get homeStillOffline => 'Still offline. The audio stays pending.';

  @override
  String get homeDiscardAudioTitle => 'Discard audio';

  @override
  String get homeDiscardAudioMessage =>
      'The untranscribed audio will be deleted. This can\'t be undone.';

  @override
  String get homeDiscardConfirm => 'Discard';

  @override
  String get homeDeleteAudioTitle => 'Delete audio';

  @override
  String get homeDeleteAudioMessage =>
      'The original audio will be deleted. The transcription stays.';

  @override
  String get homeNoteDeleted => 'Note deleted';

  @override
  String get homeNoteDeleteFailed => 'Couldn\'t delete the note';

  @override
  String get homeSettingsTooltip => 'Settings';

  @override
  String get homeSearchNotesEmpty => 'Search';

  @override
  String homeSearchNotes(String count) {
    return 'Search $count notes';
  }

  @override
  String get homeSearchHistory => 'Search history';

  @override
  String get homeNotesLoading => 'Loading notes…';

  @override
  String get homeNotesUnavailable => 'Notes unavailable';

  @override
  String get homeNotesUnavailableMessage => 'Couldn\'t read the notes';

  @override
  String get homeEmptyNotesTitle => 'Your first note';

  @override
  String get homeEmptyNotesHold =>
      'Hold the bubble and speak.\nWhatever you say gets written here.';

  @override
  String get homeEmptyNotesTap =>
      'Tap the bubble and speak.\nWhatever you say gets written here.';

  @override
  String get homeNoResultsTitle => 'No results';

  @override
  String homeNoResultsMessage(String query) {
    return 'Nothing matches “$query”.';
  }

  @override
  String homePendingHeader(String count) {
    return 'Pending · $count';
  }

  @override
  String get homePendingInfo =>
      'No on-device transcription yet: the audio is stored on the phone and only goes to the cloud when you tap Transcribe.';

  @override
  String get homePendingQueueUnavailable => 'Queue unavailable';

  @override
  String homeHistoryFooter(String max) {
    return 'The last $max transcriptions from the app, the bubble and the keyboard. Older ones are deleted automatically.';
  }

  @override
  String get settingsKeepOneTool => 'Keep at least one tool';

  @override
  String get settingsPointerNeedsCompanion =>
      'To click in other apps, turn on Orison Pointer in Trackpad';

  @override
  String get settingsPointerCompanionTitle => 'Orison Pointer';

  @override
  String get settingsPointerCompanionMessage =>
      'It\'s a small app that performs the pointer\'s clicks in other apps. It\'s downloaded with Orison, from the same GitHub page. Install it and come back here to turn it on.';

  @override
  String get settingsPointerCompanionOk => 'Got it';

  @override
  String get settingsOverlayGranted => 'Display over other apps allowed';

  @override
  String get settingsOverlayTitle => 'Display over other apps';

  @override
  String get settingsOverlayMessage =>
      'To show the bubble over other apps, Orison needs permission to display over other apps.';

  @override
  String get settingsOverlayConfigure => 'Set up';

  @override
  String get settingsBubbleStartFailed =>
      'Couldn\'t turn on the floating bubble';

  @override
  String get settingsTranslateAiTitle => 'Translate with AI?';

  @override
  String settingsTranslateAiMessage(String name) {
    return 'When you translate, the selected or dictated text will be sent to $name (the “Title and summary with” provider) to be translated. Orison doesn\'t store it. It\'s never used in password fields.\n\nYou can switch back to “On the phone” anytime.';
  }

  @override
  String get settingsTranslateAiAuthorize => 'Allow';

  @override
  String get settingsKeyPasteToContinue => 'Paste your key to continue.';

  @override
  String get settingsKeyIncomplete =>
      'It looks incomplete: make sure you copied all of it.';

  @override
  String get settingsGroqKeyPrefix => 'Groq keys start with gsk_.';

  @override
  String get settingsKeySaveFailed => 'Couldn\'t save the API key';

  @override
  String get settingsKeySaved => 'Key saved';

  @override
  String get settingsGoogleKeyPaste =>
      'Paste your Google AI Studio key to continue.';

  @override
  String get settingsGoogleKeySaved => 'Google AI key saved';

  @override
  String get settingsGoogleKeyDeleted => 'Google AI key deleted';

  @override
  String settingsConnected(String name) {
    return 'Connected to $name';
  }

  @override
  String settingsConnectFailed(String name) {
    return 'Couldn\'t connect to $name: check the key';
  }

  @override
  String get settingsKeyDeleteFailed => 'Couldn\'t delete the API key';

  @override
  String get settingsKeyDeleted => 'Key deleted';

  @override
  String get settingsSnippetsTitle => 'Snippets';

  @override
  String get settingsCredentialsTitle => 'Logins';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSetupHeader => 'Finish setting up';

  @override
  String get settingsSetupFooter => 'With this you can dictate in any app.';

  @override
  String get settingsSetupAddGroqKey => 'Add Groq key';

  @override
  String get settingsMissing => 'Missing';

  @override
  String get settingsSetupEnableKeyboard => 'Turn on the keyboard';

  @override
  String get settingsAppSubtitle => 'AI dictation';

  @override
  String get settingsNavTranscription => 'Transcription';

  @override
  String get settingsNoKey => 'No key';

  @override
  String get settingsNavAi => 'Artificial intelligence';

  @override
  String get settingsAiActive => 'On';

  @override
  String get settingsAiHidden => 'Hidden';

  @override
  String get settingsAiOptional => 'Optional';

  @override
  String get settingsWhereHeader => 'Where to dictate';

  @override
  String get settingsNavKeyboard => 'Keyboard';

  @override
  String get settingsKeyboardActive => 'Active';

  @override
  String get settingsKeyboardInactive => 'Inactive';

  @override
  String get settingsNavBubble => 'Floating bar';

  @override
  String get settingsBubbleOn => 'On';

  @override
  String get settingsBubbleOff => 'Off';

  @override
  String get settingsNavTrackpad => 'Trackpad';

  @override
  String get settingsTrackpadOn => 'On';

  @override
  String get settingsTrackpadOff => 'Off';

  @override
  String get settingsContentHeader => 'Your content';

  @override
  String get settingsNavNotes => 'Notes and widgets';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeAuto => 'Automatic';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsAboutTitle => 'About';

  @override
  String get settingsAboutTagline => 'AI voice keyboard and notes.';

  @override
  String get settingsAboutPrivacy =>
      'No analytics or telemetry. Audio leaves the phone only when you dictate, and the keyboard never stores what you type.';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutEngine => 'Engine';

  @override
  String get settingsAboutChannelErrors => 'Channel errors';

  @override
  String get settingsAiProviderGroqHint =>
      'Groq: fast and free, with the same key as transcription.';

  @override
  String get settingsAiProviderGroqNoKey =>
      'Groq: fast and free, with the same key as transcription. The Groq key is missing (Settings › Transcription).';

  @override
  String get settingsAiProviderGoogleHint =>
      'Google: needs its own key (below).';

  @override
  String get settingsAiProviderGoogleNoKey =>
      'Google: needs its own key (below). Until you add it, Groq is used.';

  @override
  String get settingsTranslateFooterAi =>
      'Keyboard “Translate” button: with text selected, it translates it; with no selection, your next dictation comes out translated. Long press: undo. With AI: the text is sent to the provider above to be translated. Never in password fields.';

  @override
  String get settingsTranslateFooterLocal =>
      'Keyboard “Translate” button: with text selected, it translates it; with no selection, your next dictation comes out translated. Long press: undo. On the phone: the text never leaves the phone; the first time it downloads the language (about 30 MB) and then translates offline. Never in password fields.';

  @override
  String get settingsApiKeyHeader => 'API key';

  @override
  String get settingsApiKeyFooter =>
      'Stored encrypted on this phone. Get it for free at console.groq.com.';

  @override
  String get settingsAdd => 'Add';

  @override
  String get settingsRecordingHeader => 'Recording';

  @override
  String get settingsRecordHoldFooter =>
      'Hold while you speak and release to transcribe.';

  @override
  String get settingsRecordTapFooter =>
      'Tap to start and tap again to transcribe.';

  @override
  String get settingsRecordButton => 'Record button';

  @override
  String get settingsRecordTap => 'Tap';

  @override
  String get settingsRecordHold => 'Hold';

  @override
  String get settingsEngineHeader => 'Engine';

  @override
  String get settingsEnginePreciseFooter =>
      'Precise: fewer errors and better punctuation, just slightly slower. Audio leaves the phone only when you dictate.';

  @override
  String get settingsEngineFastFooter =>
      'Fast: the shortest wait. Audio leaves the phone only when you dictate.';

  @override
  String get settingsModel => 'Model';

  @override
  String get settingsModelFast => 'Fast';

  @override
  String get settingsModelPrecise => 'Precise';

  @override
  String get settingsAiProviderHeader => 'Provider';

  @override
  String get settingsAiProviderTitle => 'Title and summary with';

  @override
  String get settingsGoogleKeyHeader => 'Google key';

  @override
  String get settingsGoogleKeyFooter =>
      'Optional. Get it at aistudio.google.com.';

  @override
  String get settingsAiActionsFooter =>
      'Title and summary with one tap in each note\'s editor.';

  @override
  String get settingsAiActionsSwitch => 'AI actions in notes';

  @override
  String get settingsAiTestConnection => 'Test connection';

  @override
  String get settingsTranslateHeader => 'Translation';

  @override
  String get settingsTranslateTo => 'Translate to';

  @override
  String get settingsTranslateHow => 'How to translate';

  @override
  String get settingsTranslateLocal => 'On the phone';

  @override
  String get settingsTranslateLocalDetail => 'Private';

  @override
  String get settingsTranslateAi => 'With AI';

  @override
  String get settingsTranslateAiDetail => 'Better quality';

  @override
  String get settingsTranslateDictation =>
      'Always translate keyboard dictation';

  @override
  String get settingsBubbleFooter =>
      'Dictate and use the pointer on top of any app. Drag it toward the center to use it as a bubble; snap it to an edge to go back to the bar.';

  @override
  String get settingsDockForm => 'Shape';

  @override
  String get settingsDockEdge => 'Edge bar';

  @override
  String get settingsDockBubble => 'Bubble';

  @override
  String get settingsDockIsland => 'Island';

  @override
  String get settingsDockUnavailable => 'Unavailable';

  @override
  String get settingsIslandNeedsFooter =>
      'Needs Orison Pointer turned on: only an Accessibility service can draw over the camera and the status bar.';

  @override
  String get settingsToolsHeader => 'Tools';

  @override
  String get settingsToolsFooter =>
      'With a single tool, tapping the bubble uses it directly.';

  @override
  String get settingsToolMic => 'Microphone';

  @override
  String get settingsToolPointer => 'Pointer';

  @override
  String get settingsBubbleHistoryFooter =>
      'Long press the bar or the bubble to see what you dictated last.';

  @override
  String get settingsBubbleHistory => 'History';

  @override
  String get settingsPermissionHeader => 'Permission';

  @override
  String get settingsPermissionFooter =>
      'Android requires it to show the bar on top of other apps.';

  @override
  String get settingsOverlayRow => 'Display over other apps';

  @override
  String get settingsReview => 'Review';

  @override
  String get settingsNotesHeader => 'Notes';

  @override
  String get settingsNotesQueueFooter =>
      'With no network, the audio stays in Notes and you transcribe it when the connection is back. Offline transcription: not available yet.';

  @override
  String get settingsNotesQueueSwitch => 'Save audio when offline';

  @override
  String get settingsWidgetHeader => 'Notes widget';

  @override
  String get commonLeft => 'On the left';

  @override
  String get commonRight => 'On the right';

  @override
  String get settingsGroqKeyTitle => 'Groq key';

  @override
  String settingsKeySavedHint(String tail) {
    return 'Saved: $tail';
  }

  @override
  String get settingsGroqKeyHelp =>
      'Paste it exactly as you copied it from console.groq.com.';

  @override
  String get settingsGoogleKeyTitle => 'Google AI key';

  @override
  String settingsGoogleKeySavedHint(String tail) {
    return 'Saved: $tail';
  }

  @override
  String get settingsGoogleKeyHelp =>
      'Paste it exactly as you copied it from aistudio.google.com.';

  @override
  String get settingsKeyField => 'Key';

  @override
  String get settingsKeyDelete => 'Delete key';

  @override
  String get translateTargetEn => 'English';

  @override
  String get translateTargetEs => 'Spanish';

  @override
  String get translateTargetPt => 'Portuguese';

  @override
  String get translateTargetFr => 'French';

  @override
  String get translateTargetIt => 'Italian';

  @override
  String get translateTargetDe => 'German';

  @override
  String get keyboardSizeHeader => 'Size';

  @override
  String get keyboardHeight => 'Height';

  @override
  String get keyboardHeightLow => 'Low';

  @override
  String get keyboardHeightMedium => 'Medium';

  @override
  String get keyboardHeightHigh => 'High';

  @override
  String get keyboardHeightVeryHigh => 'Very high';

  @override
  String get keyboardSpacing => 'Spacing';

  @override
  String get keyboardSpacingCompact => 'Compact';

  @override
  String get keyboardNormal => 'Normal';

  @override
  String get keyboardSpacingWide => 'Wide';

  @override
  String get keyboardSpacingMax => 'Maximum';

  @override
  String get keyboardBottomDistance => 'Distance from edge';

  @override
  String get keyboardBottomNone => 'None';

  @override
  String get keyboardKeysHeader => 'Keys';

  @override
  String get keyboardKeysFooter =>
      'Hide the ones you don\'t use and the keyboard gains space.';

  @override
  String get keyboardTerminalRow => 'Terminal row';

  @override
  String get keyboardCodeKey => 'Code key';

  @override
  String get keyboardLanguageKey => 'Language key';

  @override
  String get keyboardCredentialsKey => 'Logins key';

  @override
  String get keyboardTypingHeader => 'Typing';

  @override
  String get keyboardMoveCursor => 'Move the cursor';

  @override
  String get keyboardCursorHold2dDetail => 'in 2D';

  @override
  String get keyboardCursorSlide => 'Slide';

  @override
  String get keyboardCursorSlideDetail => 'sideways';

  @override
  String get keyboardSpacebar => 'Spacebar';

  @override
  String get keyboardAlignCenter => 'Centered';

  @override
  String get keyboardMicLeft => 'Microphone on the left';

  @override
  String get keyboardLongPressSymbols => 'Symbols on long press';

  @override
  String get keyboardLongPressDelay => 'Delay';

  @override
  String get keyboardDelayShort => 'Short';

  @override
  String get keyboardDelayLong => 'Long';

  @override
  String get settingsHapticsSound => 'Vibration and sound';

  @override
  String get keyboardHapticsOn => 'On';

  @override
  String get keyboardHapticsOff => 'No vibration';

  @override
  String get keyboardClipboardHeader => 'Clipboard';

  @override
  String get keyboardClipboardFooter =>
      'Off saves text only and uses less memory.';

  @override
  String get keyboardClipboardImages => 'Save images';

  @override
  String get keyboardActiveTitle => 'Orison is active';

  @override
  String get keyboardActiveSubtitle => 'It\'s your keyboard in every app.';

  @override
  String get keyboardSwitch => 'Switch keyboard';

  @override
  String get keyboardSetupHeader => 'Turn it on in two steps';

  @override
  String get keyboardSetupFooter =>
      'When you come back from Android, the picker opens by itself.';

  @override
  String get keyboardEnabledTitle => 'Turned on in Android';

  @override
  String get keyboardEnabledSubtitle =>
      'You still need to pick it as your keyboard.';

  @override
  String get keyboardStep1 => '1. Turn on in Android';

  @override
  String get keyboardStep2 => '2. Pick Orison';

  @override
  String get keyboardTone1 => 'Tone 1';

  @override
  String get keyboardTone2 => 'Tone 2';

  @override
  String get keyboardTone3 => 'Tone 3';

  @override
  String get keyboardTone4 => 'Tone 4';

  @override
  String get keyboardTypingSub => 'While typing';

  @override
  String get keyboardHapticsToggle => 'Vibrate on tap';

  @override
  String get keyboardIntensity => 'Intensity';

  @override
  String get keyboardIntensitySharp => 'Sharp';

  @override
  String get keyboardIntensitySharpDetail => 'crisp click';

  @override
  String get keyboardIntensityFirm => 'Firm';

  @override
  String get keyboardIntensityFirmDetail => 'strong';

  @override
  String get keyboardIntensitySoft => 'Soft';

  @override
  String get keyboardIntensitySoftDetail => 'light';

  @override
  String get keyboardDictatingHeader => 'While dictating';

  @override
  String get keyboardDictatingFooter => 'Works separately from key vibration.';

  @override
  String get keyboardMicVibration => 'Vibration';

  @override
  String get keyboardMicOnStart => 'On start';

  @override
  String get keyboardMicWhileRecording => 'While recording';

  @override
  String get keyboardMicOnPaste => 'On paste';

  @override
  String get keyboardMicOnCancel => 'On cancel';

  @override
  String get keyboardMicSoundsHeader => 'Microphone sounds';

  @override
  String get keyboardMicSounds => 'Sounds';

  @override
  String get keyboardMicOnStop => 'On finish';

  @override
  String get trackpadPointerActive => 'Active';

  @override
  String get trackpadPointerEnable => 'Turn on';

  @override
  String get trackpadPointerNotInstalled => 'Not installed';

  @override
  String get trackpadRestrictedRow => 'Allow restricted settings';

  @override
  String get trackpadFooterReady =>
      'The pointer\'s clicks reach any app. It doesn\'t read the screen or store anything.';

  @override
  String get trackpadFooterDisabled =>
      'Turn it on in Accessibility. If Android says “Restricted setting”, tap Allow restricted settings and try again.';

  @override
  String get trackpadFooterMissing =>
      'To click in other apps you need the Orison Pointer companion. Without it, the pointer moves but doesn\'t click.';

  @override
  String get trackpadOtherAppsHeader => 'Pointer in other apps';

  @override
  String get trackpadOpenFooter =>
      'It opens from the floating bar. To close it, tap the line at the top.';

  @override
  String get trackpadOpenAs => 'Opens as';

  @override
  String get trackpadOpenPanel => 'Bottom panel';

  @override
  String get trackpadOpenWindow => 'Floating window';

  @override
  String get trackpadAutoReturn => 'On release';

  @override
  String get trackpadStaysOpen => 'Stays open';

  @override
  String get trackpadClosesIn5 => 'Closes after 5 s';

  @override
  String get trackpadClosesIn15 => 'Closes after 15 s';

  @override
  String get trackpadClosesIn30 => 'Closes after 30 s';

  @override
  String get trackpadKeyboardHeader => 'On the keyboard';

  @override
  String get trackpadKeyboardFooter =>
      'A pointer inside the keyboard to move the cursor precisely.';

  @override
  String get trackpadKeyboardSwitch => 'Trackpad on the keyboard';

  @override
  String get trackpadToolbarSwitch => 'Shortcut in the keyboard bar';

  @override
  String get trackpadAcceleration => 'Acceleration';

  @override
  String get trackpadAccelDynamic => 'Dynamic';

  @override
  String get trackpadAccelLinear => 'Linear';

  @override
  String get trackpadAccelPrecision => 'Precision';

  @override
  String get trackpadShapeArrow => 'Arrow';

  @override
  String get trackpadShapeDot => 'Dot';

  @override
  String get trackpadShapeCross => 'Cross';

  @override
  String get trackpadClickHeader => 'Click';

  @override
  String get trackpadTapToClick => 'Tap to click';

  @override
  String get trackpadSecondaryClick => 'Secondary click';

  @override
  String get trackpadTwoFingers => 'Two fingers';

  @override
  String get trackpadRightButton => 'Right button';

  @override
  String get trackpadButtons => 'Buttons';

  @override
  String get trackpadButtonsTop => 'Top';

  @override
  String get trackpadButtonsSides => 'On the sides';

  @override
  String get trackpadScrollHeader => 'Scrolling';

  @override
  String get trackpadScrollBar => 'Scroll bar';

  @override
  String get trackpadScrollRight => 'Right';

  @override
  String get trackpadScrollLeft => 'Left';

  @override
  String get trackpadScrollHidden => 'Hidden';

  @override
  String get trackpadScrollDirection => 'Direction';

  @override
  String get trackpadScrollNatural => 'Natural';

  @override
  String get trackpadScrollInverted => 'Inverted';

  @override
  String get trackpadOtherHeader => 'Other';

  @override
  String get trackpadHaptics => 'Vibration';

  @override
  String get trackpadHapticSubtle => 'Subtle';

  @override
  String get trackpadSpeed => 'Speed';

  @override
  String get trackpadSlow => 'Slow';

  @override
  String trackpadSpeedSemantics(String value) {
    return 'Speed $value';
  }

  @override
  String get trackpadFast => 'Fast';

  @override
  String get dateToday => 'Today';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String get dateThisWeek => 'This week';

  @override
  String get dateMonths =>
      'january,february,march,april,may,june,july,august,september,october,november,december';

  @override
  String get dateMonthsShort =>
      'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec';

  @override
  String dateShort(String day, String month) {
    return '$month $day';
  }

  @override
  String dateShortYear(String day, String month, String year) {
    return '$month $day, $year';
  }

  @override
  String dateMonthYear(String month, String year) {
    return '$month $year';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'Phone language';

  @override
  String get errSttKeyMissing => 'Groq API key missing. Add it in Settings.';

  @override
  String get errAudioNotFound => 'Audio file not found.';

  @override
  String get errAudioTooShort => 'The audio is too short to transcribe.';

  @override
  String get errAudioTooLarge => 'The audio is over the 25 MB limit.';

  @override
  String errAudioDamaged(String detail) {
    return 'The audio is damaged [$detail] and can\'t be transcribed. Record it again.';
  }

  @override
  String get errAudioUnreadable => 'Couldn\'t read the audio to upload it.';

  @override
  String get errSttKeyInvalid => 'Invalid API key. Check your key in Settings.';

  @override
  String get errSttRateLimit =>
      'Request limit reached. Wait a moment and try again.';

  @override
  String errGroqError(String code, String detail) {
    return 'Groq error $code: $detail';
  }

  @override
  String errGroqServer(String code) {
    return 'Groq server error ($code). Try again.';
  }

  @override
  String get errInvalidResponse => 'Invalid server response. Try again.';

  @override
  String get errEmptyTranscript =>
      'The server returned no text for that audio.';

  @override
  String get errNoInternet => 'No internet connection.';

  @override
  String get errTimeout => 'Timed out connecting to the server.';

  @override
  String get errUnexpectedTranscribe => 'Unexpected error while transcribing.';

  @override
  String get errMicPermission => 'Microphone permission denied.';

  @override
  String get errMicBusy => 'The keyboard is using the microphone.';

  @override
  String get errUploadInFlight =>
      'A transcription is already in progress. Wait for it to finish.';

  @override
  String get errHistorySaveFailed =>
      'Couldn\'t save the transcription to history (storage full or storage error).';

  @override
  String get errAiTimeout => 'Timed out';

  @override
  String get errAiNetwork => 'Network error. Check your connection.';

  @override
  String get errAiInvalidResponse => 'Invalid response from the model';

  @override
  String get errAiEmptyResponse => 'Empty response from the model';

  @override
  String errAiKeyInvalid(String provider, String code, String detail) {
    return 'Invalid $provider key ($code) $detail';
  }

  @override
  String errAiModelUnavailable(String detail) {
    return 'Model not available: $detail';
  }

  @override
  String errAiLimit(String provider, String detail) {
    return '$provider limit reached: $detail';
  }

  @override
  String errAiServer(String code, String detail) {
    return 'Server error ($code): $detail';
  }

  @override
  String errAiHttp(String code, String detail) {
    return 'Error $code: $detail';
  }

  @override
  String get errAiTooLong =>
      'The note is too long for free Groq (about 20,000 characters at most). For long notes, choose Google in Settings › Artificial intelligence.';

  @override
  String get settingsSpokenLanguage => 'Language I speak';

  @override
  String get settingsSpokenLanguageAuto => 'Automatic';

  @override
  String get settingsSpokenLanguageAutoFooter =>
      'Automatic: Whisper detects the language in each dictation. If it gets the language wrong, pick a fixed one.';

  @override
  String get commonOk => 'Done';

  @override
  String get settingsBackupTitle => 'Backup';

  @override
  String get settingsBackupExport => 'Export backup';

  @override
  String get settingsBackupExporting => 'Exporting…';

  @override
  String get settingsBackupImport => 'Import backup';

  @override
  String get settingsBackupImporting => 'Importing…';

  @override
  String get settingsBackupFooter =>
      'Saves your notes with their audio, the history, snippets, clipboard and settings to a .zip file. API keys and credentials are never included: you will need to enter them again after importing. Importing adds what is missing and never deletes anything you already have.';

  @override
  String settingsBackupExported(int notes, int snippets) {
    String _temp0 = intl.Intl.pluralLogic(
      notes,
      locale: localeName,
      other: '$notes notes',
      one: '1 note',
    );
    String _temp1 = intl.Intl.pluralLogic(
      snippets,
      locale: localeName,
      other: '$snippets snippets',
      one: '1 snippet',
    );
    return 'Backup saved: $_temp0 and $_temp1.';
  }

  @override
  String get settingsBackupImportedTitle => 'Backup imported';

  @override
  String settingsBackupImportedNotes(int added, int updated) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added new notes',
      one: '1 new note',
      zero: 'No new notes',
    );
    String _temp1 = intl.Intl.pluralLogic(
      updated,
      locale: localeName,
      other: ' and $updated updated',
      one: ' and 1 updated',
      zero: '',
    );
    return '$_temp0$_temp1.';
  }

  @override
  String settingsBackupImportedNotesSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes did not fit',
      one: '1 note did not fit',
    );
    return '$_temp0 because the note limit was reached.';
  }

  @override
  String settingsBackupImportedRest(int snippets, int history, int clips) {
    return 'New snippets: $snippets. Dictations in history: $history. Clips: $clips. Settings now match the backup.';
  }

  @override
  String get settingsBackupImportedKeys =>
      'Groq and Google keys are not part of the backup: add them in Settings if they are not there yet.';

  @override
  String get settingsBackupErrorFormat => 'That file is not an Orison backup.';

  @override
  String get settingsBackupErrorVersion =>
      'This backup comes from a newer version of Orison. Update the app and try again.';

  @override
  String get settingsBackupErrorBusy =>
      'Notes are busy right now. Try again in a few seconds.';

  @override
  String get settingsBackupErrorTooBig => 'The backup is too large to import.';

  @override
  String get settingsBackupErrorIo => 'The file could not be read or saved.';

  @override
  String get privacyNoticeTitle => 'Before you dictate';

  @override
  String get privacyNoticeAccept => 'Got it';

  @override
  String get privacyNoticeBody =>
      'When you dictate, the audio is sent to Groq with your own key to turn it into text. It never goes through Orison servers and is not stored on any server of ours.\n\nIf you use AI title, summary or translation, the text of that note or selection goes to Groq or Google, also with your key.\n\nYour notes, history, snippets and keys stay on your phone. The keyboard never stores or sends what you type.';

  @override
  String get settingsAboutPrivacyPolicy => 'Privacy policy';
}
