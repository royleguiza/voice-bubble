import 'package:flutter/material.dart';
import '../models/transcription.dart';
import '../ui/design_tokens.dart';
import '../helpers/note_groups.dart';
import '../ui/symbol_field.dart';
import '../ui/transcription_feedback.dart';
import 'app_icons.dart';

class HistoryList extends StatelessWidget {
  final List<Transcription> transcriptions;

  /// Controller del DraggableScrollableSheet contenedor. Al conectarlo al
  /// ListView, arrastrar la lista expande el sheet (snap 50% / 90%).
  final ScrollController? scrollController;

  /// Integrada en la página principal: sin scroll propio (la página
  /// desplaza todo), filas con la hora sola en mono y separadores line; la
  /// pantalla las agrupa por día. Son 20 filas como máximo (FIFO), así que
  /// construirlas todas no cuesta.
  final bool embedded;

  const HistoryList({
    super.key,
    required this.transcriptions,
    this.scrollController,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (embedded) return _buildEmbedded(context);
    if (transcriptions.isEmpty) {
      // Scrollable conectado al sheet: permite arrastrarlo hacia arriba
      // (hasta el 90%) incluso sin contenido.
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Text(
                'No hay transcripciones aun',
                key: const ValueKey('history-empty-message'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      // Overscroll siempre disponible: con pocos ítems también se
      // puede arrastrar el sheet hacia su snap superior.
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: transcriptions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _tile(context, transcriptions[index]),
    );
  }

  Widget _buildEmbedded(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    final line = isDark ? kSeparatorDark : kSeparatorLight;
    if (transcriptions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: Column(
          children: [
            const SymbolField(),
            const SizedBox(height: 14),
            Text(
              'No hay transcripciones aun',
              key: const ValueKey('history-empty-message'),
              textAlign: TextAlign.center,
              style: kTextSubhead.copyWith(color: secondary),
            ),
          ],
        ),
      );
    }
    // Horizonte: filas sueltas sobre el fondo, separadas por line (sin
    // tarjeta). La fecha la da el encabezado del grupo del día.
    return Material(
      type: MaterialType.transparency,
      child: ListView.separated(
        shrinkWrap: true,
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: transcriptions.length,
        separatorBuilder: (_, __) => Divider(
          height: kSurfaceBorderWidth,
          thickness: kSurfaceBorderWidth,
          color: line,
        ),
        itemBuilder: (context, index) =>
            _tile(context, transcriptions[index], embedded: true),
      ),
    );
  }

  Widget _tile(BuildContext context, Transcription t, {bool embedded = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    return ListTile(
      key: ValueKey(t.id),
      // Motor Cloud único: sin motor Local no hay rama de ícono.
      // Integrada: la hora sola en mono, en una columna fija.
      leading: embedded
          ? SizedBox(
              width: kHistoryTimeColumn,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  historyTimeLabel(t.timestamp),
                  style: kTextMono.copyWith(fontSize: 12, color: secondary),
                ),
              ),
            )
          : Icon(
              Icons.cloud,
              size: AppIcons.medium,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      minLeadingWidth: embedded ? kHistoryTimeColumn : null,
      horizontalTitleGap: embedded ? 10 : null,
      titleAlignment: embedded ? ListTileTitleAlignment.top : null,
      title: SelectableText(
        t.text,
        maxLines: 2,
        style: embedded
            ? kTextSubhead.copyWith(
                height: 20 / 15,
                color: isDark ? kLabelPrimaryDark : kLabelPrimaryLight,
              )
            : null,
      ),
      subtitle: embedded
          ? null
          : Text(
              formatTranscriptionTimestamp(t.timestamp),
              style: Theme.of(context).textTheme.bodySmall,
            ),
      trailing: IconButton(
        key: ValueKey('copy_btn_${t.id}'),
        icon: Icon(Icons.copy_rounded,
            size: AppIcons.small, color: embedded ? secondary : null),
        tooltip: copyTooltipMessage,
        onPressed: () async {
          // Fallo de clipboard clasificado: avisa de portapapeles, no
          // de red, y nunca deja pendiente/reintento (ver helper).
          final copy = await copyTranscriptionText(t.text);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(copy == ClipboardCopyResult.ok
                    ? copiedToClipboardMessage
                    : clipboardFailureMessage),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      ),
      contentPadding: embedded
          ? const EdgeInsets.fromLTRB(2, 4, 0, 4)
          : const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}
