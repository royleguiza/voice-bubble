import 'package:flutter/material.dart';
import '../models/transcription.dart';
import '../ui/transcription_feedback.dart';
import 'app_icons.dart';

class HistoryList extends StatelessWidget {
  final List<Transcription> transcriptions;

  /// Controller del DraggableScrollableSheet contenedor. Al conectarlo al
  /// ListView, arrastrar la lista expande el sheet (snap 50% / 90%).
  final ScrollController? scrollController;

  const HistoryList({
    super.key,
    required this.transcriptions,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
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
      itemBuilder: (context, index) {
        final t = transcriptions[index];
        return ListTile(
          // Motor Cloud único: sin motor Local no hay rama de ícono.
          leading: Icon(
            Icons.cloud,
            size: AppIcons.medium,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          title: Text(
            t.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            formatTranscriptionTimestamp(t.timestamp),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: IconButton(
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        );
      },
    );
  }
}
