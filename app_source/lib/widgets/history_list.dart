import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transcription.dart';

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
          leading: Icon(
            t.isLocal ? Icons.phone_android : Icons.cloud,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          title: Text(
            t.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _formatTimestamp(t.timestamp),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: t.text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Texto copiado'),
                    duration: Duration(seconds: 2),
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

  String _formatTimestamp(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} $hour:$minute';
  }
}
