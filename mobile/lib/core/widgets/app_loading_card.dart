import 'package:flutter/material.dart';

import '../localization/app_text.dart';
import 'app_card.dart';

/// A static skeleton avoids a continuous shimmer repaint on slower devices.
class AppLoadingCard extends StatelessWidget {
  const AppLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget line(double width) => FractionallySizedBox(
      widthFactor: width,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
    return Semantics(
      label: 'İçerik yükleniyor'.tr,
      liveRegion: true,
      child: ExcludeSemantics(
        child: AppCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [line(.65), const SizedBox(height: 12), line(.9)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
