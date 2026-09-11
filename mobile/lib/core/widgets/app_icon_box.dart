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
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: gradient == null
            ? backgroundColor ??
            colorScheme.primaryContainer
            : null,
        gradient: gradient,
        borderRadius:
        BorderRadius.circular(
          borderRadius,
        ),
        boxShadow:
        showShadow
            ? AppTheme.primaryShadow
            : null,
      ),
      child: Icon(
        icon,
        size: iconSize,
        color:
        iconColor ??
            colorScheme.primary,
      ),
    );
  }
}