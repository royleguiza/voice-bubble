import 'package:flutter/material.dart';
import '../models/transcription.dart';
import '../ui/design_tokens.dart';
import '../ui/transcription_feedback.dart';
import 'app_icons.dart';

class HistoryList extends StatelessWidget {
  final List<Transcription> transcriptions;

  /// Controller del DraggableScrollableSheet contenedor. Al conectarlo al
  /// ListView, arrastrar la lista expande el sheet (snap 50% / 90%).
  final ScrollController? scrollController;

  /// Integrada en la página principal: sin scroll propio (la página
  /// desplaza todo) y agrupada en una tarjeta. Son 20 filas como máximo
  /// (FIFO), así que construirlas todas no cuesta.
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
    if (transcriptions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Center(
          child: Text(
            'No hay transcripciones aun',
            key: const ValueKey('history-empty-message'),
            style: kTextSubhead.copyWith(color: secondary),
          ),
        ),
      );
    }
    return Material(
      color: isDark ? kBgElevatedDark : kBgSecondaryLight,
      borderRadius: BorderRadius.circular(kBorderRadiusNoteCard),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: transcriptions.length,
        separatorBuilder: (_, __) => Divider(
          height: 0.5,
          thickness: 0.5,
          indent: 16,
          color: isDark ? kSeparatorDark : kSeparatorLight,
        ),
        itemBuilder: (context, index) =>
            _tile(context, transcriptions[index], embedded: true),
      ),
    );
  }

  Widget _tile(BuildContext context, Transcription t, {bool embedded = false}) {
    return ListTile(
      key: ValueKey(t.id),
      // Motor Cloud único: sin motor Local no hay rama de ícono.
      leading: embedded
          ? null
          : Icon(
              Icons.cloud,
              size: AppIcons.medium,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      title: SelectableText(
        t.text,
        maxLines: 2,
      ),
      subtitle: Text(
        formatTranscriptionTimestamp(t.timestamp),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: IconButton(
        key: ValueKey('copy_btn_${t.id}'),
        icon: const Icon(Icons.copy_rounded, size: 18),
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
          ? const EdgeInsets.fromLTRB(16, 2, 6, 2)
          : const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}
