import 'package:flutter/material.dart';

/// Uses available content width and text size, including inside a navigation rail.
class AppAdaptiveColumns extends StatelessWidget {
  const AppAdaptiveColumns({
    super.key,
    required this.first,
    required this.second,
  });

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      if (constraints.maxWidth >= 760 && textScale <= 1.3) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 24),
            Expanded(child: second),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [first, const SizedBox(height: 24), second],
      );
    },
  );
}
