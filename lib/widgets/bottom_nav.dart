import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class NavDestination {
  const NavDestination(this.label, this.icon, {this.showBadge = false});

  final String label;
  final IconData icon;

  /// Draws the unread dot. Notifications live behind Profile, so the tab
  /// bar is where the app signals there is something waiting.
  final bool showBadge;
}

/// Rounded white tab bar with the add button docked in its centre.
///
/// The add button used to float loose over the habit list, where it clipped
/// the screen edge and covered a row. Docking it between Calendar and Progress
/// gives it a fixed home and makes it reachable from every tab.
class RewireMindBottomNav extends StatelessWidget {
  const RewireMindBottomNav({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    required this.onAdd,
    this.addKey,
    this.tabsKey,
  });

  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  /// For the Home tour, which points at the + button and at the tabs.
  final GlobalKey? addKey;
  final GlobalKey? tabsKey;

  /// Width reserved in the bar for the docked button.
  static const double _dockWidth = 68;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final half = destinations.length ~/ 2;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          decoration: BoxDecoration(
            color: k.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            boxShadow: [
              BoxShadow(
                color: k.colors.textPrimary.withValues(alpha: 0.07),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                key: tabsKey,
                children: [
                  for (var i = 0; i < half; i++)
                    Expanded(
                      child: _NavItem(
                        destination: destinations[i],
                        selected: i == currentIndex,
                        onTap: () => onSelect(i),
                      ),
                    ),
                  const SizedBox(width: _dockWidth),
                  for (var i = half; i < destinations.length; i++)
                    Expanded(
                      child: _NavItem(
                        destination: destinations[i],
                        selected: i == currentIndex,
                        onTap: () => onSelect(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Raised so it reads as the primary action rather than a fifth tab.
        Positioned(
          top: -20,
          child: KeyedSubtree(
            key: addKey,
            child: _AddButton(onTap: onAdd),
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: k.colors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: k.colors.surface, width: 4),
        boxShadow: [
          BoxShadow(
            color: k.colors.primary.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Icon(Icons.add, color: Colors.white, size: 25),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final color = selected ? k.colors.navActive : k.colors.navInactive;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(k.geometry.chipRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? k.colors.navActiveBackground
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(k.geometry.chipRadius),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(destination.icon, size: 21, color: color),
                  if (destination.showBadge)
                    Positioned(
                      top: -1,
                      right: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: k.colors.danger,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: k.colors.surface,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              style: k.text.caption.copyWith(
                fontSize: 10.5,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
