import 'package:flutter/material.dart';

import '../theme/app_theme_controller.dart';
import '../localization/app_text.dart';
import 'app_motion.dart';

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

        return Tooltip(
          message: (isDark ? 'Açık temaya geç' : 'Koyu temaya geç').tr,
          child: Semantics(
            button: true,
            child: Material(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => controller.setDarkMode(!isDark),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: AppMotion.duration(context, AppMotion.medium),
                    transitionBuilder: (child, animation) => RotationTransition(
                      turns: Tween<double>(
                        begin: 0.75,
                        end: 1,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      key: ValueKey(isDark),
                      size: 23,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
