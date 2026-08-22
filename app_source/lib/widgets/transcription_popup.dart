import 'package:flutter/material.dart';
import '../ui/design_tokens.dart';
import '../ui/glass_container.dart';

/// Tarjeta emergente glass que flota sobre el botón de grabar mostrando la
/// última transcripción. Animación: expand (scale 0.85→1, easeOutBack) +
/// fade del shell y fade diferido del bloque de texto. El botón Copiar está
/// disponible desde t=0 (no participa del fade).
class TranscriptionPopup extends StatelessWidget {
  final String text;
  final DateTime timestamp;
  final AnimationController controller;
  final bool motionSafe;
  final VoidCallback onCopy;

  const TranscriptionPopup({
    super.key,
    required this.text,
    required this.timestamp,
    required this.controller,
    required this.motionSafe,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelPrimary = isDark ? kLabelPrimaryDark : kLabelPrimaryLight;
    final labelSecondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    final accent = isDark ? kAccentDark : kAccentLight;
    final maxHeight = MediaQuery.sizeOf(context).height * kPopupMaxHeightFactor;

    final scale = motionSafe
        ? Tween(begin: 0.85, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeOutBack))
        : const AlwaysStoppedAnimation(1.0);
    final shellFade = CurvedAnimation(
        parent: controller,
        curve:
            motionSafe ? const Interval(0.0, 0.65, curve: Curves.easeOutCubic) : Curves.easeOut);
    final textFade = CurvedAnimation(
        parent: controller,
        curve: motionSafe
            ? const Interval(0.18, 0.95, curve: Curves.easeOutCubic)
            : Curves.easeOut);

    final day = timestamp.day.toString().padLeft(2, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');

    return ScaleTransition(
      scale: scale,
      alignment: Alignment.bottomCenter,
      child: FadeTransition(
        opacity: shellFade,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: kPopupMaxWidth,
            maxHeight: maxHeight,
          ),
          child: GlassContainer(
            borderRadius: kBorderRadiusCard,
            small: false,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: FadeTransition(
                    opacity: textFade,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        text,
                        style: kTextBody.copyWith(color: labelPrimary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud, size: 16, color: labelSecondary),
                          const SizedBox(width: 6),
                          Text(
                            '$day/$month $hh:$mm',
                            style: kTextCaption.copyWith(color: labelSecondary),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: onCopy,
                        borderRadius:
                            BorderRadius.circular(kBorderRadiusCapsule),
                        child: GlassContainer(
                          borderRadius: kBorderRadiusCapsule,
                          small: true,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_rounded,
                                  size: 18, color: accent),
                              const SizedBox(width: 6),
                              Text('Copiar',
                                  style:
                                      kTextCallout.copyWith(color: accent)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
