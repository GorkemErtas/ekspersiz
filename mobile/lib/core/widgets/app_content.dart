import 'package:flutter/material.dart';

/// Constrains a scrollable without constraining its height or keyboard insets.
class AppContent extends StatelessWidget {
  const AppContent({super.key, required this.child, this.maxWidth = 760});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
