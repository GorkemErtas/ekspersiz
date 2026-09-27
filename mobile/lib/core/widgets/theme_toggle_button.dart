import 'package:flutter/material.dart';

import '../theme/app_theme_controller.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isDark = controller.isDarkMode;
        final colorScheme = Theme.of(context).colorScheme;

        return Material(
          color: colorScheme.surface.withValues(alpha: 0.92),
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.18),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => controller.setDarkMode(!isDark),
            child: SizedBox(
              width: 40,
              height: 40,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => RotationTransition(
                  turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  key: ValueKey(isDark),
                  size: 21,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
