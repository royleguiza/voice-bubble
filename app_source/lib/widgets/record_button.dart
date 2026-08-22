import 'package:flutter/material.dart';
import '../ui/design_tokens.dart';
import '../ui/glass_container.dart';

/// Botón de grabar principal: círculo glass Ø104 en la zona inferior.
/// Estados: idle (glass + mic acento), recording (rojo kRecording + glow +
/// anillo pulsante), transcribing (spinner, deshabilitado).
enum RecordButtonState { idle, recording, transcribing }

class RecordButton extends StatefulWidget {
  final RecordButtonState state;
  final VoidCallback? onPressed;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;

  const RecordButton({
    super.key,
    required this.state,
    this.onPressed,
    this.onHoldStart,
    this.onHoldEnd,
  });

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant RecordButton old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _syncPulse();
  }

  void _syncPulse() {
    final active = widget.state == RecordButtonState.recording &&
        !MediaQuery.of(context).disableAnimations;
    if (active) {
      _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0.0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  bool get _enabled =>
      widget.state != RecordButtonState.transcribing &&
      (widget.onPressed != null ||
          widget.onHoldStart != null ||
          widget.onHoldEnd != null);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? kAccentDark : kAccentLight;
    final recordingColor =
        isDark ? kRecordingDark : kRecording;
    final border = isDark ? kGlassBorderDark : kGlassBorderLight;
    final motionSafe = !MediaQuery.of(context).disableAnimations;
    final isRecording = widget.state == RecordButtonState.recording;
    final isTranscribing = widget.state == RecordButtonState.transcribing;

    final fill = isRecording
        ? recordingColor.withValues(alpha: 0.92)
        : (isDark ? Colors.black : Colors.white)
            .withValues(alpha: isDark ? kGlassOpacityDark : kGlassOpacityLight);
    final glyphColor = isRecording ? Colors.white : accent;

    return Semantics(
      button: true,
      label: isRecording ? 'Detener grabación' : 'Iniciar grabación',
      child: SizedBox(
        width: kRecordButtonSize,
        height: kRecordButtonSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isRecording && motionSafe)
              FadeTransition(
                opacity: Tween(begin: 0.35, end: 0.0).animate(_pulse),
                child: ScaleTransition(
                  scale:
                      Tween(begin: 1.0, end: 1.12).animate(_pulse),
                  child: Container(
                    width: kRecordButtonSize,
                    height: kRecordButtonSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: recordingColor, width: 2),
                    ),
                  ),
                ),
              ),
            GestureDetector(
              onTap: _enabled ? widget.onPressed : null,
              onLongPressStart:
                  (_enabled && widget.onHoldStart != null)
                      ? (_) => widget.onHoldStart!()
                      : null,
              onLongPressEnd:
                  (_enabled && widget.onHoldEnd != null)
                      ? (_) => widget.onHoldEnd!()
                      : null,
              onLongPressCancel:
                  (_enabled && widget.onHoldEnd != null)
                      ? () => widget.onHoldEnd!()
                      : null,
              child: AnimatedContainer(
                duration: kAnimMorph,
                curve: Curves.easeOutBack,
                width: kRecordButtonSize,
                height: kRecordButtonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: Border.all(color: border),
                  boxShadow: isRecording
                      ? [
                          BoxShadow(
                            color: recordingColor.withValues(alpha: 0.45),
                            blurRadius: 32,
                          ),
                          BoxShadow(
                            color: recordingColor.withValues(alpha: 0.25),
                            blurRadius: 48,
                          ),
                        ]
                      : [
                          isDark
                              ? kGlassShadowSmallDark
                              : kGlassShadowSmallLight,
                        ],
                ),
                child: Center(
                  child: isTranscribing
                      ? SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: isDark
                                ? kLabelPrimaryDark
                                : kLabelPrimaryLight,
                          ),
                        )
                      : Icon(
                          isRecording
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                          size: kRecordIconSize,
                          color: glyphColor,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
