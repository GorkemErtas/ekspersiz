import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppIconBox extends StatelessWidget {
  const AppIconBox({
    super.key,
    required this.icon,
    this.size = 46,
    this.iconSize = 23,
    this.backgroundColor,
    this.iconColor,
    this.gradient,
    this.borderRadius = AppTheme.radiusMedium,
    this.showShadow = false,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? iconColor;
  final Gradient? gradient;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final usesGradient = gradient != null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: usesGradient
            ? null
            : backgroundColor ??
                  colorScheme.primaryContainer.withValues(alpha: 0.72),
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: usesGradient
              ? Colors.white.withValues(alpha: 0.10)
              : colorScheme.primary.withValues(alpha: 0.10),
        ),
        boxShadow: showShadow ? AppTheme.primaryShadowFor(context) : null,
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: iconColor ?? colorScheme.secondary,
      ),
    );
  }
}
