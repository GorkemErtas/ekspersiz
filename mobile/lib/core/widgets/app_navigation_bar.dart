import 'package:flutter/material.dart';

import '../localization/app_text.dart';
import 'app_motion.dart';

class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            animationDuration: AppMotion.duration(context, AppMotion.medium),
            destinations:
                const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: 'Ana Sayfa',
                        tooltip: 'Ana Sayfa',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.directions_car_outlined),
                        selectedIcon: Icon(Icons.directions_car_rounded),
                        label: 'Araçlar',
                        tooltip: 'Araçlar',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.description_outlined),
                        selectedIcon: Icon(Icons.description_rounded),
                        label: 'Analizler',
                        tooltip: 'Analizler',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline_rounded),
                        selectedIcon: Icon(Icons.person_rounded),
                        label: 'Profil',
                        tooltip: 'Profil',
                      ),
                    ]
                    .map(
                      (destination) => NavigationDestination(
                        icon: destination.icon,
                        selectedIcon: destination.selectedIcon,
                        label: destination.label.tr,
                        tooltip: destination.tooltip?.tr,
                      ),
                    )
                    .toList(growable: false),
          ),
        ),
      ),
    );
  }
}
