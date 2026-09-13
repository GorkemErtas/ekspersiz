import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_icon_box.dart';

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.iconGradient = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final bool iconGradient;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        final iconWidget = AppIconBox(
          icon: icon,

          size: isWide ? 62 : 56,

          iconSize: isWide ? 30 : 28,

          borderRadius: isWide ? 20 : 18,

          iconColor: iconGradient ? Colors.white : colorScheme.primary,

          gradient: iconGradient
              ? const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],

                  begin: Alignment.topLeft,

                  end: Alignment.bottomRight,
                )
              : null,

          showShadow: iconGradient,
        );

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,

                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,

                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),

                child: Text(
                  badge!,

                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,

                    fontWeight: FontWeight.w900,

                    letterSpacing: 0.4,
                  ),
                ),
              ),

              const SizedBox(height: 10),
            ],

            Text(
              title,

              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              subtitle,

              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,

                height: 1.5,
              ),
            ),
          ],
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              iconWidget,

              const SizedBox(width: 18),

              Expanded(child: content),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            iconWidget,

            const SizedBox(height: AppTheme.spacingM),

            content,
          ],
        );
      },
    );
  }
}
