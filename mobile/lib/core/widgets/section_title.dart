import 'package:mobile/core/localization/app_text.dart';
import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionPressed,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final heading = Semantics(
      header: true,
      child: AppText(title, style: Theme.of(context).textTheme.titleLarge),
    );
    final action = actionLabel == null
        ? null
        : TextButton(onPressed: onActionPressed, child: AppText(actionLabel!));
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, ?action],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            if (action != null) ...[const SizedBox(width: 12), action],
          ],
        );
      },
    );
  }
}
