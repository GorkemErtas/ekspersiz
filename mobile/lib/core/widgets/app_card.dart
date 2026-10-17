import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_motion.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.showShadow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppTheme.radiusLarge);

    final decoration = BoxDecoration(
      color: backgroundColor ?? colorScheme.surface,
      borderRadius: radius,
      border: Border.all(color: borderColor ?? colorScheme.outlineVariant),
      boxShadow: showShadow ? AppTheme.softShadowFor(context) : null,
    );

    if (onTap == null) {
      return Container(
        width: double.infinity,
        padding: padding,
        decoration: decoration,
        child: child,
      );
    }

    return AppPressScale(
      onTap: onTap,
      borderRadius: radius,
      pressedScale: 0.985,
      child: Ink(
        width: double.infinity,
        padding: padding,
        decoration: decoration,
        child: child,
      ),
    );
  }
}
