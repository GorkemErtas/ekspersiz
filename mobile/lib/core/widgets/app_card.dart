import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
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
        Theme.of(context).colorScheme;

    final decoration =
    BoxDecoration(
      color:
      backgroundColor ??
          colorScheme.surface,

      borderRadius:
      BorderRadius.circular(
        AppTheme.radiusLarge,
      ),

      border:
      Border.all(
        color:
        borderColor ??
            colorScheme.outlineVariant,
      ),

      boxShadow:
      showShadow
          ? AppTheme.softShadow
          : null,
    );

    final content =
    Container(
      width:
      double.infinity,

      padding:
      padding,

      decoration:
      decoration,

      child:
      child,
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color:
      Colors.transparent,

      borderRadius:
      BorderRadius.circular(
        AppTheme.radiusLarge,
      ),

      clipBehavior:
      Clip.antiAlias,

      child:
      InkWell(
        onTap:
        onTap,

        borderRadius:
        BorderRadius.circular(
          AppTheme.radiusLarge,
        ),

        child:
        content,
      ),
    );
  }
}