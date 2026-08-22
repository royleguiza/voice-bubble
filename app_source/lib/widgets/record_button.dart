import 'package:flutter/material.dart';
import '../ui/design_tokens.dart';

class RecordButton extends StatelessWidget {
  final bool isRecording;
  final bool isTranscribing;
  final VoidCallback onPressed;

  const RecordButton({
    super.key,
    required this.isRecording,
    required this.isTranscribing,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: 80,
      height: 80,
      child: FloatingActionButton.large(
        onPressed: isTranscribing ? null : onPressed,
        backgroundColor: isRecording ? kRecording : cs.primary,
        foregroundColor: cs.onPrimary,
        shape: const StadiumBorder(),
        child: isTranscribing
            ? SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: cs.onPrimary,
                ),
              )
            : Icon(
                isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                size: 36,
              ),
      ),
    );
  }
}
