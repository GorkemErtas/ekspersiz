import 'package:mobile/core/localization/app_text.dart';
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
    this.iconGradient = false,
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
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final isWide =
            constraints.maxWidth >= 720 ||
            (constraints.maxWidth >= 340 && textScale <= 1.3);

        final iconWidget = AppIconBox(
          icon: icon,

          size: 48,

          iconSize: 24,

          borderRadius: AppTheme.radiusMedium,

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

                child: AppText(
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

            Semantics(
              header: true,
              child: AppText(
                title,

                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            const SizedBox(height: 7),

            AppText(
              subtitle,

              style: textTheme.bodyMedium?.copyWith(
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

              const SizedBox(width: 14),

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
