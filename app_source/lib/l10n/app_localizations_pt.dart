// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get copyButtonLabel => 'Copiar';

  @override
  String get copyTooltipMessage => 'Copiar para a área de transferência';

  @override
  String get copiedToClipboardMessage => 'Texto copiado';

  @override
  String get clipboardFailureMessage =>
      'Não foi possível copiar para a área de transferência';

  @override
  String get historyEmptyMessage => 'Ainda não há transcrições';

  @override
  String get noteAudioNotFound => 'Áudio não encontrado';

  @override
  String get noteAudioCorrupt => 'Áudio danificado; apague e grave de novo';

  @override
  String get noteAudioChip => 'Áudio';

  @override
  String get noteUntitled => 'Sem título';

  @override
  String get noteCopyTooltip => 'Copiar texto';

  @override
  String get noteCardHint => 'Toque e segure para mais ações';

  @override
  String get recordingStatusRecording => 'Gravando...';

  @override
  String get recordingStatusProcessing => 'Processando...';

  @override
  String get recordingStatusError => 'Erro, toque para tentar de novo';

  @override
  String get recordingStatusReady => 'Pronto para transcrever';

  @override
  String islandMockupDescription(
      String cx, String top, String width, String height, String side) {
    return 'Prévia da ilha: centro a $cx pixels da borda esquerda, borda superior a $top pixels, $width de largura por $height de altura. Microfone à $side.';
  }

  @override
  String get islandMicLeft => 'esquerda';

  @override
  String get islandMicRight => 'direita';

  @override
  String get noteAudioStop => 'Parar áudio';

  @override
  String get noteAudioPlay => 'Ouvir áudio';

  @override
  String noteAudioPlayWithDuration(String duration) {
    return 'Ouvir áudio, $duration';
  }

  @override
  String noteCardSemantics(String title) {
    return 'Nota: $title';
  }

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Salvar';

  @override
  String get homeTabNotes => 'Notas';

  @override
  String get homeTabHistory => 'Histórico';

  @override
  String get homeSearchClear => 'Limpar busca';

  @override
  String get noteActionOpen => 'Abrir e editar';

  @override
  String get noteActionCopy => 'Copiar texto';

  @override
  String get noteActionDeleteAudio => 'Apagar áudio, manter texto';

  @override
  String get noteActionDelete => 'Excluir nota';

  @override
  String get recordStop => 'Parar gravação';

  @override
  String get recordTranscribing => 'Transcrevendo';

  @override
  String get recordHoldToRecord => 'Segure para gravar';

  @override
  String get recordStart => 'Iniciar gravação';

  @override
  String get recordDiscard => 'Descartar gravação';

  @override
  String pendingAgoMinutes(String n) {
    return 'há $n min';
  }

  @override
  String pendingAgoHours(String n) {
    return 'há $n h';
  }

  @override
  String get pendingYesterday => 'ontem';

  @override
  String pendingAgoDays(String n) {
    return 'há $n d';
  }

  @override
  String pendingSemantics(String when) {
    return 'Áudio não transcrito, $when';
  }

  @override
  String get pendingTitle => 'Áudio não transcrito';

  @override
  String get pendingUnplayable => 'Não foi possível reproduzir este áudio';

  @override
  String get pendingTranscribe => 'Transcrever';

  @override
  String get pendingDiscard => 'Descartar áudio';

  @override
  String get pendingPause => 'Pausar';

  @override
  String get pendingPlay => 'Ouvir áudio';

  @override
  String get pendingClosePlayer => 'Fechar player';

  @override
  String get unitPx => 'px';

  @override
  String get unitPxSpoken => 'pixels';

  @override
  String get credentialsDeleteTitle => 'Apagar login';

  @override
  String credentialsDeleteConfirm(String name) {
    return 'Apagar \"$name\"? Não é possível desfazer.';
  }

  @override
  String get credentialsDeleteButton => 'Apagar';

  @override
  String get credentialsShowUserFooter =>
      'Ao lado do nome, na lista do teclado.';

  @override
  String get credentialsShowUser => 'Mostrar usuário';

  @override
  String get credentialsEmptyTitle => 'Nenhum login salvo';

  @override
  String get credentialsEmptyMessage =>
      'Salve usuário e senha para preenchê-los pelo botão de chave do teclado.';

  @override
  String get credentialsAdd => 'Adicionar login';

  @override
  String get credentialsSavedHeader => 'Salvos';

  @override
  String credentialsCountFooter(String count, String max) {
    return '$count de $max · A senha nunca é exibida.';
  }

  @override
  String credentialsDeleteNamed(String name) {
    return 'Apagar $name';
  }

  @override
  String get credentialsFormError =>
      'Revise os campos: nome e usuário não podem ficar vazios.';

  @override
  String get credentialsNewTitle => 'Novo login';

  @override
  String get credentialsFieldName => 'Nome';

  @override
  String get credentialsFieldNameHint => 'Ex.: Banco';

  @override
  String get credentialsFieldUser => 'Usuário';

  @override
  String get credentialsFieldUserHint => 'Usuário ou e-mail';

  @override
  String get credentialsFieldPassword => 'Senha';

  @override
  String get credentialsFieldPasswordHint => 'Só é digitada, nunca exibida';

  @override
  String get credentialsFormHint =>
      'Fica salva criptografada. O teclado a preenche só em campos de senha.';

  @override
  String get islandTitle => 'Ajustar ilha';

  @override
  String get islandNeedsPointer =>
      'A ilha precisa do VoiceBubble Ponteiro ativado: sem ele, ela aparece como bolha e estes ajustes não têm efeito.';

  @override
  String get islandNeedsBar =>
      'Ative a barra flutuante para ver a ilha na sua tela.';

  @override
  String get islandPositionHeader => 'Posição';

  @override
  String get islandPositionFooter =>
      'Horizontal: o centro da ilha. Vertical: a borda superior. Em pixels da tela inteira.';

  @override
  String get islandPositionX => 'Posição horizontal';

  @override
  String get islandPixelLeft => 'Um pixel para a esquerda';

  @override
  String get islandPixelRight => 'Um pixel para a direita';

  @override
  String get islandPositionY => 'Posição vertical';

  @override
  String get islandPixelUp => 'Um pixel para cima';

  @override
  String get islandPixelDown => 'Um pixel para baixo';

  @override
  String get islandSizeHeader => 'Tamanho em repouso';

  @override
  String get islandSizeFooter => 'Ao gravar, a ilha cresce sozinha.';

  @override
  String get islandWidth => 'Largura';

  @override
  String get islandNarrower => 'Um pixel mais estreita';

  @override
  String get islandWider => 'Um pixel mais larga';

  @override
  String get islandHeight => 'Altura';

  @override
  String get islandShorter => 'Um pixel mais baixa';

  @override
  String get islandTaller => 'Um pixel mais alta';

  @override
  String get islandSideFooter => 'O ponteiro fica do outro lado.';

  @override
  String get islandSideTitle => 'Lado do microfone';

  @override
  String get islandSideLeft => 'Esquerda';

  @override
  String get islandSideRight => 'Direita';

  @override
  String get islandCenterTop => 'Centralizar em cima';

  @override
  String get islandReset => 'Restaurar';

  @override
  String get noteEditorWriteFirst => 'Escreva ou dite uma nota primeiro';

  @override
  String noteEditorUnexpectedError(String error) {
    return 'Erro inesperado: $error';
  }

  @override
  String get noteEditorAiErrorTitle => 'Erro de IA';

  @override
  String get noteEditorClose => 'Fechar';

  @override
  String get noteEditorAiTitleSuggested => 'Título sugerido';

  @override
  String get noteEditorAiSummaryTitle => 'Resumo da nota';

  @override
  String get noteEditorDiscard => 'Descartar';

  @override
  String get noteEditorReplace => 'Substituir';

  @override
  String get noteEditorBodyRequired => 'Texto obrigatório';

  @override
  String get noteEditorLimitOrError => 'Limite atingido ou erro';

  @override
  String get noteEditorClipboardEmpty => 'A área de transferência está vazia';

  @override
  String get noteEditorNothingToCopy => 'Nada para copiar';

  @override
  String get noteEditorDelete => 'Excluir nota';

  @override
  String get noteEditorDeleteWithAudio =>
      'O texto e o áudio serão apagados. Não é possível desfazer.';

  @override
  String get noteEditorDeleteTextOnly => 'Não é possível desfazer esta ação.';

  @override
  String get noteEditorDeleteConfirm => 'Excluir';

  @override
  String get noteEditorNewNote => 'Nova nota';

  @override
  String noteEditorMetaGroupTime(String group, String time) {
    return '$group, $time';
  }

  @override
  String get noteEditorTitleLabel => 'Título';

  @override
  String get noteEditorAiTitleButton => 'Gerar título com IA';

  @override
  String get noteEditorBodyHint => 'Digite ou cole o texto da nota';

  @override
  String get commonBack => 'Voltar';

  @override
  String get noteEditorPaste => 'Colar';

  @override
  String get noteEditorCopy => 'Copiar texto';

  @override
  String get noteEditorAiSummarize => 'Resumir com IA';

  @override
  String get snippetSaveFailed => 'Não foi possível salvar o snippet.';

  @override
  String snippetSaveFailedLimit(String max) {
    return 'Não foi possível salvar o snippet: limite de $max snippets atingido ou dados temporários ilegíveis.';
  }

  @override
  String get snippetColorBlue => 'azul';

  @override
  String get snippetColorGreen => 'verde';

  @override
  String get snippetColorRed => 'vermelho';

  @override
  String get snippetColorOrange => 'laranja';

  @override
  String get snippetColorViolet => 'violeta';

  @override
  String get snippetColorGray => 'cinza';

  @override
  String get snippetDelete => 'Excluir snippet';

  @override
  String snippetDeleteConfirm(String name) {
    return 'Excluir \"$name\"? Não é possível desfazer esta ação.';
  }

  @override
  String get snippetDeleteButton => 'Excluir';

  @override
  String get snippetsEmptyTitle => 'Nenhum snippet';

  @override
  String get snippetsEmptyMessage =>
      'Salve textos que você usa sempre e cole com um toque pelo teclado.';

  @override
  String get snippetsCreate => 'Criar snippet';

  @override
  String snippetsNoResults(String query) {
    return 'Nenhum resultado para \"$query\".';
  }

  @override
  String snippetsCountFooter(String count, String max) {
    return '$count de $max · Inseridos com um toque pelo teclado.';
  }

  @override
  String get snippetsReorderDone => 'Pronto';

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
    return 'Descer $name';
  }

  @override
  String get snippetNameRequired => 'O nome é obrigatório';

  @override
  String snippetMaxChars(String max) {
    return 'Máximo de $max caracteres';
  }

  @override
  String get snippetSheetEdit => 'Editar snippet';

  @override
  String get snippetSheetNew => 'Novo snippet';

  @override
  String get snippetFieldName => 'Nome';

  @override
  String get snippetFieldNameHint => 'Ex.: Assinatura';

  @override
  String get snippetFieldText => 'Texto';

  @override
  String get snippetFieldTextHint => 'O que será inserido';

  @override
  String snippetContentCounter(String length, String max) {
    return '$length / $max';
  }

  @override
  String get snippetColorLabel => 'Cor';

  @override
  String get snippetColorNone => 'Sem cor';

  @override
  String get homeStatusRelease => 'Solte para terminar';

  @override
  String get homeStatusTranscribing => 'Transcrevendo…';

  @override
  String get homeStatusError => 'Erro, toque para tentar de novo';

  @override
  String homeRecordStartError(String error) {
    return 'Erro ao iniciar a gravação: $error';
  }

  @override
  String get homeNoteSaved => 'Nota salva';

  @override
  String homeNoteNotSavedFull(String max) {
    return 'Nota não salva: você chegou a $max notas. O texto foi copiado e ficou no Histórico.';
  }

  @override
  String get homeAudioNotKept =>
      'Não foi possível manter o áudio. O texto ficou no Histórico.';

  @override
  String get homeNoteNotSavedTextKept =>
      'Nota não salva; o texto ficou no Histórico';

  @override
  String homeError(String error) {
    return 'Erro: $error';
  }

  @override
  String get homeRetry => 'Tentar de novo';

  @override
  String get homeOfflineAudioSaved => 'Sem conexão · áudio salvo em Notas';

  @override
  String get homePendingAudioGone =>
      'O áudio pendente não está mais disponível';

  @override
  String get homeAudioNotKeptShort => 'Não foi possível manter o áudio';

  @override
  String get homeNoteNotSavedAudioKept => 'Nota não salva; o áudio foi mantido';

  @override
  String get homeNoteSavedAudioPending => 'Nota salva; o áudio fica pendente';

  @override
  String get homeApiKeyMissing => 'Falta a chave de API. Configure em Ajustes.';

  @override
  String get homeStillOffline => 'Ainda sem rede. O áudio fica pendente.';

  @override
  String get homeDiscardAudioTitle => 'Descartar áudio';

  @override
  String get homeDiscardAudioMessage =>
      'O áudio não transcrito será apagado. Não é possível desfazer esta ação.';

  @override
  String get homeDiscardConfirm => 'Descartar';

  @override
  String get homeDeleteAudioTitle => 'Apagar áudio';

  @override
  String get homeDeleteAudioMessage =>
      'O áudio original será apagado. A transcrição fica.';

  @override
  String get homeNoteDeleted => 'Nota excluída';

  @override
  String get homeNoteDeleteFailed => 'Não foi possível excluir a nota';

  @override
  String get homeSettingsTooltip => 'Configurações';

  @override
  String get homeSearchNotesEmpty => 'Buscar';

  @override
  String homeSearchNotes(String count) {
    return 'Buscar em $count notas';
  }

  @override
  String get homeSearchHistory => 'Buscar no histórico';

  @override
  String get homeNotesLoading => 'Carregando notas…';

  @override
  String get homeNotesUnavailable => 'Notas indisponíveis';

  @override
  String get homeNotesUnavailableMessage => 'Não foi possível ler as notas';

  @override
  String get homeEmptyNotesTitle => 'Sua primeira nota';

  @override
  String get homeEmptyNotesHold =>
      'Segure a bolha e fale.\nO que você disser fica escrito aqui.';

  @override
  String get homeEmptyNotesTap =>
      'Toque na bolha e fale.\nO que você disser fica escrito aqui.';

  @override
  String get homeNoResultsTitle => 'Nenhum resultado';

  @override
  String homeNoResultsMessage(String query) {
    return 'Nada corresponde a “$query”.';
  }

  @override
  String homePendingHeader(String count) {
    return 'Pendentes · $count';
  }

  @override
  String get homePendingInfo =>
      'Ainda sem transcrição no aparelho: o áudio fica salvo no telefone e só vai para a nuvem quando você toca em Transcrever.';

  @override
  String get homePendingQueueUnavailable => 'Fila indisponível';

  @override
  String homeHistoryFooter(String max) {
    return 'As últimas $max transcrições do app, da bolha e do teclado. As mais antigas são apagadas sozinhas.';
  }

  @override
  String get settingsKeepOneTool => 'Deixe pelo menos uma ferramenta';

  @override
  String get settingsPointerNeedsCompanion =>
      'Para clicar em outros apps, ative o VoiceBubble Ponteiro em Trackpad';

  @override
  String get settingsPointerCompanionTitle => 'VoiceBubble Ponteiro';

  @override
  String get settingsPointerCompanionMessage =>
      'É um app pequeno que faz os cliques do ponteiro em outros apps. É baixado junto com o VoiceBubble, no mesmo lugar do GitHub. Instale e volte aqui para ativá-lo.';

  @override
  String get settingsPointerCompanionOk => 'Entendi';

  @override
  String get settingsOverlayGranted => 'Permissão de sobreposição concedida';

  @override
  String get settingsOverlayTitle => 'Permissão de sobreposição';

  @override
  String get settingsOverlayMessage =>
      'Para mostrar a bolha sobre outros apps, o VoiceBubble precisa da permissão de sobreposição a outros apps.';

  @override
  String get settingsOverlayConfigure => 'Configurar';

  @override
  String get settingsBubbleStartFailed =>
      'Não foi possível ativar a bolha flutuante';

  @override
  String get settingsTranslateAiTitle => 'Traduzir com IA?';

  @override
  String settingsTranslateAiMessage(String name) {
    return 'Quando você traduzir, o texto selecionado ou ditado será enviado para $name (o provedor de “Título e resumo com”) para ser traduzido. O VoiceBubble não o guarda. Nunca é usado em campos de senha.\n\nVocê pode voltar para “No telefone” quando quiser.';
  }

  @override
  String get settingsTranslateAiAuthorize => 'Autorizar';

  @override
  String get settingsKeyPasteToContinue => 'Cole sua chave para continuar.';

  @override
  String get settingsKeyIncomplete =>
      'Parece incompleta: confira se você a copiou inteira.';

  @override
  String get settingsGroqKeyPrefix => 'As chaves do Groq começam com gsk_.';

  @override
  String get settingsKeySaveFailed => 'Não foi possível salvar a chave de API';

  @override
  String get settingsKeySaved => 'Chave salva';

  @override
  String get settingsGoogleKeyPaste =>
      'Cole sua chave do Google AI Studio para continuar.';

  @override
  String get settingsGoogleKeySaved => 'Chave do Google AI salva';

  @override
  String get settingsGoogleKeyDeleted => 'Chave do Google AI excluída';

  @override
  String settingsConnected(String name) {
    return 'Conectado ao $name';
  }

  @override
  String settingsConnectFailed(String name) {
    return 'Não foi possível conectar ao $name: confira a chave';
  }

  @override
  String get settingsKeyDeleteFailed =>
      'Não foi possível excluir a chave de API';

  @override
  String get settingsKeyDeleted => 'Chave excluída';

  @override
  String get settingsSnippetsTitle => 'Snippets';

  @override
  String get settingsCredentialsTitle => 'Logins';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsSetupHeader => 'Termine a configuração';

  @override
  String get settingsSetupFooter =>
      'Com isso você já pode ditar em qualquer app.';

  @override
  String get settingsSetupAddGroqKey => 'Adicionar chave do Groq';

  @override
  String get settingsMissing => 'Falta';

  @override
  String get settingsSetupEnableKeyboard => 'Ativar o teclado';

  @override
  String get settingsAppSubtitle => 'Ditado com Groq Whisper';

  @override
  String get settingsNavTranscription => 'Transcrição';

  @override
  String get settingsNoKey => 'Sem chave';

  @override
  String get settingsNavAi => 'Inteligência artificial';

  @override
  String get settingsAiActive => 'Ativa';

  @override
  String get settingsAiHidden => 'Oculta';

  @override
  String get settingsAiOptional => 'Opcional';

  @override
  String get settingsWhereHeader => 'Onde ditar';

  @override
  String get settingsNavKeyboard => 'Teclado';

  @override
  String get settingsKeyboardActive => 'Ativo';

  @override
  String get settingsKeyboardInactive => 'Inativo';

  @override
  String get settingsNavBubble => 'Barra flutuante';

  @override
  String get settingsBubbleOn => 'Ativada';

  @override
  String get settingsBubbleOff => 'Desativada';

  @override
  String get settingsNavTrackpad => 'Trackpad';

  @override
  String get settingsTrackpadOn => 'Ativado';

  @override
  String get settingsTrackpadOff => 'Desativado';

  @override
  String get settingsContentHeader => 'Seu conteúdo';

  @override
  String get settingsNavNotes => 'Notas e widgets';

  @override
  String get settingsAppearance => 'Aparência';

  @override
  String get settingsThemeAuto => 'Automática';

  @override
  String get settingsThemeLight => 'Clara';

  @override
  String get settingsThemeDark => 'Escura';

  @override
  String get settingsAboutTitle => 'Sobre';

  @override
  String get settingsAboutTagline =>
      'Transcrição de voz para texto com Groq Whisper.';

  @override
  String get settingsAboutPrivacy =>
      'Sem analytics nem telemetria. O áudio só sai do telefone quando você dita, e o teclado nunca guarda o que você digita.';

  @override
  String get settingsAboutVersion => 'Versão';

  @override
  String get settingsAboutEngine => 'Motor';

  @override
  String get settingsAboutChannelErrors => 'Erros de canal';

  @override
  String get settingsAiProviderGroqHint =>
      'Groq: rápido e grátis, com a mesma chave da transcrição.';

  @override
  String get settingsAiProviderGroqNoKey =>
      'Groq: rápido e grátis, com a mesma chave da transcrição. Falta a chave do Groq (Ajustes › Transcrição).';

  @override
  String get settingsAiProviderGoogleHint =>
      'Google: precisa da própria chave (abaixo).';

  @override
  String get settingsAiProviderGoogleNoKey =>
      'Google: precisa da própria chave (abaixo). Enquanto você não a adicionar, o Groq é usado.';

  @override
  String get settingsTranslateFooterAi =>
      'Botão “Traduzir” do teclado: com texto selecionado, traduz; sem seleção, o próximo ditado sai traduzido. Toque e segure: desfazer. Com IA: o texto é enviado ao provedor acima para ser traduzido. Nunca em campos de senha.';

  @override
  String get settingsTranslateFooterLocal =>
      'Botão “Traduzir” do teclado: com texto selecionado, traduz; sem seleção, o próximo ditado sai traduzido. Toque e segure: desfazer. No telefone: o texto não sai do telefone; na primeira vez baixa o idioma (uns 30 MB) e depois traduz sem internet. Nunca em campos de senha.';

  @override
  String get settingsApiKeyHeader => 'Chave de API';

  @override
  String get settingsApiKeyFooter =>
      'Fica salva criptografada neste telefone. Você a consegue grátis em console.groq.com.';

  @override
  String get settingsAdd => 'Adicionar';

  @override
  String get settingsRecordingHeader => 'Gravação';

  @override
  String get settingsRecordHoldFooter =>
      'Segure enquanto fala e solte para transcrever.';

  @override
  String get settingsRecordTapFooter =>
      'Toque para começar e toque de novo para transcrever.';

  @override
  String get settingsRecordButton => 'Botão de gravar';

  @override
  String get settingsRecordTap => 'Tocar';

  @override
  String get settingsRecordHold => 'Segurar';

  @override
  String get settingsEngineHeader => 'Motor';

  @override
  String get settingsEnginePreciseFooter =>
      'Preciso: menos erros e melhor pontuação, só um pouco mais lento. O áudio só sai do telefone quando você dita.';

  @override
  String get settingsEngineFastFooter =>
      'Rápido: a menor espera. O áudio só sai do telefone quando você dita.';

  @override
  String get settingsModel => 'Modelo';

  @override
  String get settingsModelFast => 'Rápido';

  @override
  String get settingsModelPrecise => 'Preciso';

  @override
  String get settingsAiProviderHeader => 'Provedor';

  @override
  String get settingsAiProviderTitle => 'Título e resumo com';

  @override
  String get settingsGoogleKeyHeader => 'Chave do Google';

  @override
  String get settingsGoogleKeyFooter =>
      'Opcional. Você a consegue em aistudio.google.com.';

  @override
  String get settingsAiActionsFooter =>
      'Título e resumo com um toque no editor de cada nota.';

  @override
  String get settingsAiActionsSwitch => 'Ações de IA nas notas';

  @override
  String get settingsAiTestConnection => 'Testar conexão';

  @override
  String get settingsTranslateHeader => 'Tradução';

  @override
  String get settingsTranslateTo => 'Traduzir para';

  @override
  String get settingsTranslateHow => 'Como traduzir';

  @override
  String get settingsTranslateLocal => 'No telefone';

  @override
  String get settingsTranslateLocalDetail => 'Privado';

  @override
  String get settingsTranslateAi => 'Com IA';

  @override
  String get settingsTranslateAiDetail => 'Melhor qualidade';

  @override
  String get settingsTranslateDictation =>
      'Sempre traduzir o ditado do teclado';

  @override
  String get settingsBubbleFooter =>
      'Dite e use o ponteiro por cima de qualquer app. Arraste-a para o centro para usá-la como bolha; encoste-a numa borda para voltar à barra.';

  @override
  String get settingsDockForm => 'Forma';

  @override
  String get settingsDockEdge => 'Barra na borda';

  @override
  String get settingsDockBubble => 'Bolha';

  @override
  String get settingsDockIsland => 'Ilha';

  @override
  String get settingsDockUnavailable => 'Indisponível';

  @override
  String get settingsIslandNeedsFooter =>
      'Precisa do VoiceBubble Ponteiro ativado: só um serviço de Acessibilidade pode desenhar sobre a câmera e a barra de status.';

  @override
  String get settingsToolsHeader => 'Ferramentas';

  @override
  String get settingsToolsFooter =>
      'Com uma só ferramenta, tocar na bolha a usa direto.';

  @override
  String get settingsToolMic => 'Microfone';

  @override
  String get settingsToolPointer => 'Ponteiro';

  @override
  String get settingsBubbleHistoryFooter =>
      'Toque e segure a barra ou a bolha para ver o que você ditou por último.';

  @override
  String get settingsBubbleHistory => 'Histórico';

  @override
  String get settingsPermissionHeader => 'Permissão';

  @override
  String get settingsPermissionFooter =>
      'O Android pede para mostrar a barra por cima de outros apps.';

  @override
  String get settingsOverlayRow => 'Sobrepor a outros apps';

  @override
  String get settingsReview => 'Revisar';

  @override
  String get settingsNotesHeader => 'Notas';

  @override
  String get settingsNotesQueueFooter =>
      'Sem rede, o áudio fica em Notas e você o transcreve quando a conexão voltar. Transcrever sem internet: ainda não disponível.';

  @override
  String get settingsNotesQueueSwitch => 'Salvar áudio sem conexão';

  @override
  String get settingsWidgetHeader => 'Widget de notas';

  @override
  String get commonLeft => 'À esquerda';

  @override
  String get commonRight => 'À direita';

  @override
  String get settingsGroqKeyTitle => 'Chave do Groq';

  @override
  String settingsKeySavedHint(String tail) {
    return 'Salva: $tail';
  }

  @override
  String get settingsGroqKeyHelp =>
      'Cole exatamente como você copiou de console.groq.com.';

  @override
  String get settingsGoogleKeyTitle => 'Chave do Google AI';

  @override
  String settingsGoogleKeySavedHint(String tail) {
    return 'Salva: $tail';
  }

  @override
  String get settingsGoogleKeyHelp =>
      'Cole exatamente como você copiou de aistudio.google.com.';

  @override
  String get settingsKeyField => 'Chave';

  @override
  String get settingsKeyDelete => 'Excluir chave';

  @override
  String get translateTargetEn => 'Inglês';

  @override
  String get translateTargetEs => 'Espanhol';

  @override
  String get translateTargetPt => 'Português';

  @override
  String get translateTargetFr => 'Francês';

  @override
  String get translateTargetIt => 'Italiano';

  @override
  String get translateTargetDe => 'Alemão';

  @override
  String get keyboardSizeHeader => 'Tamanho';

  @override
  String get keyboardHeight => 'Altura';

  @override
  String get keyboardHeightLow => 'Baixa';

  @override
  String get keyboardHeightMedium => 'Média';

  @override
  String get keyboardHeightHigh => 'Alta';

  @override
  String get keyboardHeightVeryHigh => 'Muito alta';

  @override
  String get keyboardSpacing => 'Espaçamento';

  @override
  String get keyboardSpacingCompact => 'Compacto';

  @override
  String get keyboardNormal => 'Normal';

  @override
  String get keyboardSpacingWide => 'Amplo';

  @override
  String get keyboardSpacingMax => 'Máximo';

  @override
  String get keyboardBottomDistance => 'Distância da borda';

  @override
  String get keyboardBottomNone => 'Nenhuma';

  @override
  String get keyboardKeysHeader => 'Teclas';

  @override
  String get keyboardKeysFooter =>
      'Oculte as que você não usa e o teclado ganha espaço.';

  @override
  String get keyboardTerminalRow => 'Fileira de terminal';

  @override
  String get keyboardCodeKey => 'Tecla de código';

  @override
  String get keyboardLanguageKey => 'Tecla de idioma';

  @override
  String get keyboardCredentialsKey => 'Tecla de logins';

  @override
  String get keyboardTypingHeader => 'Digitação';

  @override
  String get keyboardMoveCursor => 'Mover o cursor';

  @override
  String get keyboardCursorHold2dDetail => 'em 2D';

  @override
  String get keyboardCursorSlide => 'Deslizar';

  @override
  String get keyboardCursorSlideDetail => 'lateral';

  @override
  String get keyboardSpacebar => 'Barra de espaço';

  @override
  String get keyboardAlignCenter => 'Centralizada';

  @override
  String get keyboardMicLeft => 'Microfone à esquerda';

  @override
  String get keyboardLongPressSymbols => 'Símbolos ao segurar';

  @override
  String get keyboardLongPressDelay => 'Espera';

  @override
  String get keyboardDelayShort => 'Curta';

  @override
  String get keyboardDelayLong => 'Longa';

  @override
  String get settingsHapticsSound => 'Vibração e som';

  @override
  String get keyboardHapticsOn => 'Ativados';

  @override
  String get keyboardHapticsOff => 'Sem vibração';

  @override
  String get keyboardClipboardHeader => 'Área de transferência';

  @override
  String get keyboardClipboardFooter =>
      'Desativado guarda só texto e ocupa menos memória.';

  @override
  String get keyboardClipboardImages => 'Salvar imagens';

  @override
  String get keyboardActiveTitle => 'O VoiceBubble está ativo';

  @override
  String get keyboardActiveSubtitle => 'É o seu teclado em todos os apps.';

  @override
  String get keyboardSwitch => 'Trocar de teclado';

  @override
  String get keyboardSetupHeader => 'Ative em dois passos';

  @override
  String get keyboardSetupFooter =>
      'Ao voltar do Android, o seletor abre sozinho.';

  @override
  String get keyboardEnabledTitle => 'Ativado no Android';

  @override
  String get keyboardEnabledSubtitle => 'Falta escolhê-lo como teclado.';

  @override
  String get keyboardStep1 => '1. Ativar no Android';

  @override
  String get keyboardStep2 => '2. Escolher o VoiceBubble';

  @override
  String get keyboardTone1 => 'Tom 1';

  @override
  String get keyboardTone2 => 'Tom 2';

  @override
  String get keyboardTone3 => 'Tom 3';

  @override
  String get keyboardTone4 => 'Tom 4';

  @override
  String get keyboardTypingSub => 'Ao digitar';

  @override
  String get keyboardHapticsToggle => 'Vibrar ao tocar';

  @override
  String get keyboardIntensity => 'Intensidade';

  @override
  String get keyboardIntensitySharp => 'Nítida';

  @override
  String get keyboardIntensitySharpDetail => 'clique seco';

  @override
  String get keyboardIntensityFirm => 'Firme';

  @override
  String get keyboardIntensityFirmDetail => 'marcada';

  @override
  String get keyboardIntensitySoft => 'Suave';

  @override
  String get keyboardIntensitySoftDetail => 'leve';

  @override
  String get keyboardDictatingHeader => 'Ao ditar';

  @override
  String get keyboardDictatingFooter =>
      'Funciona à parte da vibração das teclas.';

  @override
  String get keyboardMicVibration => 'Vibração';

  @override
  String get keyboardMicOnStart => 'Ao começar';

  @override
  String get keyboardMicWhileRecording => 'Enquanto grava';

  @override
  String get keyboardMicOnPaste => 'Ao colar';

  @override
  String get keyboardMicOnCancel => 'Ao cancelar';

  @override
  String get keyboardMicSoundsHeader => 'Sons do microfone';

  @override
  String get keyboardMicSounds => 'Sons';

  @override
  String get keyboardMicOnStop => 'Ao terminar';

  @override
  String get trackpadPointerActive => 'Ativo';

  @override
  String get trackpadPointerEnable => 'Ativar';

  @override
  String get trackpadPointerNotInstalled => 'Não instalado';

  @override
  String get trackpadRestrictedRow => 'Permitir configurações restritas';

  @override
  String get trackpadFooterReady =>
      'Os cliques do ponteiro chegam a qualquer app. Ele não lê a tela nem guarda nada.';

  @override
  String get trackpadFooterDisabled =>
      'Ative em Acessibilidade. Se o Android disser “Configuração restrita”, toque em Permitir configurações restritas e tente de novo.';

  @override
  String get trackpadFooterMissing =>
      'Para clicar em outros apps é preciso o complemento VoiceBubble Ponteiro. Sem ele, o ponteiro se move mas não clica.';

  @override
  String get trackpadOtherAppsHeader => 'Ponteiro em outros apps';

  @override
  String get trackpadOpenFooter =>
      'Abre pela barra flutuante. Para fechar, toque na linha de cima.';

  @override
  String get trackpadOpenAs => 'Abre como';

  @override
  String get trackpadOpenPanel => 'Painel embaixo';

  @override
  String get trackpadOpenWindow => 'Janela flutuante';

  @override
  String get trackpadAutoReturn => 'Ao soltar';

  @override
  String get trackpadStaysOpen => 'Fica aberto';

  @override
  String get trackpadClosesIn5 => 'Fecha após 5 s';

  @override
  String get trackpadClosesIn15 => 'Fecha após 15 s';

  @override
  String get trackpadClosesIn30 => 'Fecha após 30 s';

  @override
  String get trackpadKeyboardHeader => 'No teclado';

  @override
  String get trackpadKeyboardFooter =>
      'Um ponteiro dentro do teclado para mover o cursor com precisão.';

  @override
  String get trackpadKeyboardSwitch => 'Trackpad no teclado';

  @override
  String get trackpadToolbarSwitch => 'Atalho na barra do teclado';

  @override
  String get trackpadAcceleration => 'Aceleração';

  @override
  String get trackpadAccelDynamic => 'Dinâmica';

  @override
  String get trackpadAccelLinear => 'Linear';

  @override
  String get trackpadAccelPrecision => 'Precisão';

  @override
  String get trackpadShapeArrow => 'Seta';

  @override
  String get trackpadShapeDot => 'Ponto';

  @override
  String get trackpadShapeCross => 'Cruz';

  @override
  String get trackpadClickHeader => 'Clique';

  @override
  String get trackpadTapToClick => 'Tocar para clicar';

  @override
  String get trackpadSecondaryClick => 'Clique secundário';

  @override
  String get trackpadTwoFingers => 'Dois dedos';

  @override
  String get trackpadRightButton => 'Botão direito';

  @override
  String get trackpadButtons => 'Botões';

  @override
  String get trackpadButtonsTop => 'Em cima';

  @override
  String get trackpadButtonsSides => 'Nas laterais';

  @override
  String get trackpadScrollHeader => 'Rolagem';

  @override
  String get trackpadScrollBar => 'Barra de rolagem';

  @override
  String get trackpadScrollRight => 'Direita';

  @override
  String get trackpadScrollLeft => 'Esquerda';

  @override
  String get trackpadScrollHidden => 'Oculta';

  @override
  String get trackpadScrollDirection => 'Direção';

  @override
  String get trackpadScrollNatural => 'Natural';

  @override
  String get trackpadScrollInverted => 'Invertida';

  @override
  String get trackpadOtherHeader => 'Outros';

  @override
  String get trackpadHaptics => 'Vibração';

  @override
  String get trackpadHapticSubtle => 'Sutil';

  @override
  String get trackpadSpeed => 'Velocidade';

  @override
  String get trackpadSlow => 'Lenta';

  @override
  String trackpadSpeedSemantics(String value) {
    return 'Velocidade $value';
  }

  @override
  String get trackpadFast => 'Rápida';

  @override
  String get dateToday => 'Hoje';

  @override
  String get dateYesterday => 'Ontem';

  @override
  String get dateThisWeek => 'Esta semana';

  @override
  String get dateMonths =>
      'janeiro,fevereiro,março,abril,maio,junho,julho,agosto,setembro,outubro,novembro,dezembro';

  @override
  String get dateMonthsShort =>
      'jan,fev,mar,abr,mai,jun,jul,ago,set,out,nov,dez';

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
  String get settingsLanguageSystem => 'Do telefone';

  @override
  String get errSttKeyMissing =>
      'Falta a chave de API do Groq. Adicione em Ajustes.';

  @override
  String get errAudioNotFound => 'Arquivo de áudio não encontrado.';

  @override
  String get errAudioTooShort => 'O áudio é curto demais para transcrever.';

  @override
  String get errAudioTooLarge => 'O áudio passa do limite de 25 MB.';

  @override
  String errAudioDamaged(String detail) {
    return 'O áudio está danificado [$detail] e não pode ser transcrito. Grave de novo.';
  }

  @override
  String get errAudioUnreadable =>
      'Não foi possível ler o áudio para enviá-lo.';

  @override
  String get errSttKeyInvalid =>
      'Chave de API inválida. Confira sua chave em Ajustes.';

  @override
  String get errSttRateLimit =>
      'Limite de solicitações atingido. Aguarde um momento e tente de novo.';

  @override
  String errGroqError(String code, String detail) {
    return 'Erro $code do Groq: $detail';
  }

  @override
  String errGroqServer(String code) {
    return 'Erro do servidor do Groq ($code). Tente de novo.';
  }

  @override
  String get errInvalidResponse =>
      'Resposta inválida do servidor. Tente de novo.';

  @override
  String get errEmptyTranscript =>
      'O servidor não devolveu texto para esse áudio.';

  @override
  String get errNoInternet => 'Sem conexão com a internet.';

  @override
  String get errTimeout => 'Tempo esgotado ao conectar com o servidor.';

  @override
  String get errUnexpectedTranscribe => 'Erro inesperado ao transcrever.';

  @override
  String get errMicPermission => 'Permissão de microfone negada.';

  @override
  String get errMicBusy => 'O teclado está usando o microfone.';

  @override
  String get errUploadInFlight =>
      'Já há uma transcrição em andamento. Aguarde terminar.';

  @override
  String get errHistorySaveFailed =>
      'Não foi possível salvar a transcrição no histórico (armazenamento cheio ou erro de armazenamento).';

  @override
  String get errAiTimeout => 'Tempo esgotado';

  @override
  String get errAiNetwork => 'Erro de rede. Confira sua conexão.';

  @override
  String get errAiInvalidResponse => 'Resposta inválida do modelo';

  @override
  String get errAiEmptyResponse => 'Resposta vazia do modelo';

  @override
  String errAiKeyInvalid(String provider, String code, String detail) {
    return 'Chave do $provider inválida ($code) $detail';
  }

  @override
  String errAiModelUnavailable(String detail) {
    return 'Modelo indisponível: $detail';
  }

  @override
  String errAiLimit(String provider, String detail) {
    return 'Limite do $provider atingido: $detail';
  }

  @override
  String errAiServer(String code, String detail) {
    return 'Erro do servidor ($code): $detail';
  }

  @override
  String errAiHttp(String code, String detail) {
    return 'Erro $code: $detail';
  }

  @override
  String get errAiTooLong =>
      'A nota é longa demais para o Groq grátis (uns 20.000 caracteres no máximo). Para notas longas, escolha Google em Ajustes › Inteligência artificial.';
}
