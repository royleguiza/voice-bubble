import 'package:flutter/material.dart';
import '../ui/design_tokens.dart';

/// Botón de grabar principal: círculo glass Ø104 en la zona inferior.
/// Estados: idle (glass + mic acento), recording (rojo kRecording + glow +
/// anillo pulsante), transcribing (spinner, deshabilitado).
///
/// El morph animado SOLO ocurre al ENTRAR en recording. Al salir
/// (recording → transcribing) el cambio es instantáneo: interpolar la
/// decoración roja con easeOutBack extrapolaba colores/sombras fuera de
/// rango y producía artefactos visibles durante ~1 s sobre el botón.
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

  bool _pulseActive = false;

  /// Tweens del anillo pulsante creados UNA vez: antes se reconstruían
  /// (`Tween(...).animate(_pulse)`) en cada build del botón, asignando
  /// objetos de animación por frame sin necesidad.
  late final Animation<double> _ringOpacity =
      Tween(begin: 0.35, end: 0.0).animate(_pulse);
  late final Animation<double> _ringScale =
      Tween(begin: 0.88, end: 1.0).animate(_pulse);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    if (active && !_pulseActive) {
      _pulse.repeat();
      _pulseActive = true;
    } else if (!active && _pulseActive) {
      _pulse.stop();
      _pulse.value = 0.0;
      _pulseActive = false;
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
    // Solo animar la entrada a recording. Al salir, swap instantáneo:
    // ningún frame intermedio mezclando decoraciones rojas.
    final morphDuration =
        isRecording ? kAnimMorph : Duration.zero;

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
          clipBehavior: Clip.hardEdge,
          children: [
            if (isRecording && motionSafe)
              FadeTransition(
                opacity: _ringOpacity,
                child: ScaleTransition(
                  // Escala hacia adentro para no desbordar el Ø104
                  // (el overflow amarillo/negro de Flutter se veía sobre el rojo).
                  scale: _ringScale,
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
                // easeOut (sin overshoot): easeOutBack extrapola los
                // colores/sombras más allá del objetivo (t > 1).
                duration: morphDuration,
                curve: Curves.easeOut,
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
