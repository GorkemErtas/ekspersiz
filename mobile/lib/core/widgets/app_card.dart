import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_motion.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding =
    const EdgeInsets.all(20),
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.showShadow = true,
  });

  final Widget child;

  final EdgeInsetsGeometry padding;

  final VoidCallback? onTap;

  final Color? backgroundColor;
  final Color? borderColor;

  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context)
            .colorScheme;

    final radius =
    BorderRadius.circular(
      AppTheme.radiusLarge,
    );

    final card =
    Ink(
      width:
      double.infinity,

      padding:
      padding,

      decoration:
      BoxDecoration(
        color:
        backgroundColor ??
            colorScheme.surface,

        borderRadius:
        radius,

        border:
        Border.all(
          color:
          borderColor ??
              colorScheme
                  .outlineVariant,
        ),

        boxShadow:
        showShadow
            ? AppTheme.softShadow
            : null,
      ),

      child:
      child,
    );

    if (onTap == null) {
      return card;
    }

    return AppPressScale(
      onTap:
      onTap,

      borderRadius:
      radius,

      child:
      card,
    );
  }
}
