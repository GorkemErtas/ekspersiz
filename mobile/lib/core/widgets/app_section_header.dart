import 'package:mobile/core/localization/app_text.dart';
import 'package:flutter/material.dart';

import 'app_icon_box.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        AppIconBox(icon: icon, size: 42, iconSize: 21, borderRadius: 14),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Semantics(
                header: true,
                child: AppText(
                  title,

                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              if (subtitle != null) ...[
                const SizedBox(height: 3),

                AppText(
                  subtitle!,

                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,

                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    if (trailing == null) return heading;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 400 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 12), trailing!],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            const SizedBox(width: 12),
            trailing!,
          ],
        );
      },
    );
  }
}
