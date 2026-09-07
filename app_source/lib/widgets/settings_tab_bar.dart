import 'package:flutter/material.dart';
import '../ui/design_tokens.dart';
import '../ui/glass_container.dart';

/// Barra de pestañas inferior flotante con efecto Liquid Glass para la
/// pantalla de Configuración (Frente 1 / C2 Tabs).
class SettingsTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const SettingsTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  static const _tabs = [
    _TabItemData(
      key: ValueKey('tab-inicio'),
      icon: Icons.home_rounded,
      label: 'Inicio',
    ),
    _TabItemData(
      key: ValueKey('tab-burbuja'),
      icon: Icons.chat_bubble_outline_rounded,
      label: 'Burbuja',
    ),
    _TabItemData(
      key: ValueKey('tab-teclado'),
      icon: Icons.keyboard_outlined,
      label: 'Teclado',
    ),
    _TabItemData(
      key: ValueKey('tab-trackpad'),
      icon: Icons.touch_app_outlined,
      label: 'Trackpad',
    ),
    _TabItemData(
      key: ValueKey('tab-snippets'),
      icon: Icons.segment_rounded,
      label: 'Snippets',
    ),
    _TabItemData(
      key: ValueKey('tab-credenciales'),
      icon: Icons.vpn_key_rounded,
      label: 'Claves',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final reducedMotion =
        mediaQuery.disableAnimations || mediaQuery.accessibleNavigation;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SafeArea(
        top: false,
        child: GlassContainer(
          borderRadius: kBorderRadiusCapsule,
          small: false,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                _buildTabItem(
                  context: context,
                  data: _tabs[i],
                  isSelected: selectedIndex == i,
                  onTap: () => onTabSelected(i),
                  isDark: isDark,
                  reducedMotion: reducedMotion,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required BuildContext context,
    required _TabItemData data,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required bool reducedMotion,
  }) {
    final activeColor = isDark ? kAccentDark : kAccentLight;
    final inactiveColor = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    final color = isSelected ? activeColor : inactiveColor;
    final duration =
        reducedMotion ? Duration.zero : const Duration(milliseconds: 200);

    return Expanded(
      child: Tooltip(
        message: data.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: data.key,
            onTap: onTap,
            borderRadius: BorderRadius.circular(kBorderRadiusCapsule),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (reducedMotion)
                    Icon(data.icon, color: color, size: 22)
                  else
                    TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: color),
                      duration: duration,
                      builder: (context, animColor, _) {
                        return Icon(data.icon, color: animColor, size: 22);
                      },
                    ),
                  const SizedBox(height: 2),
                  if (reducedMotion)
                    Text(
                      data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: color,
                        letterSpacing: -0.1,
                      ),
                    )
                  else
                    AnimatedDefaultTextStyle(
                      duration: duration,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: color,
                        letterSpacing: -0.1,
                      ),
                      child: Text(data.label),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItemData {
  final Key key;
  final IconData icon;
  final String label;

  const _TabItemData({
    required this.key,
    required this.icon,
    required this.label,
  });
}
