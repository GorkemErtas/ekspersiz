import 'package:flutter/material.dart';
import 'package:mobile/core/localization/app_text.dart';

import 'app_motion.dart';

/// A growing, keyboard-accessible CTA that keeps its label while submitting.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: isLoading,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: isLoading ? null : onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading || icon != null) ...[
                AnimatedSwitcher(
                  duration: AppMotion.duration(context, AppMotion.fast),
                  child: isLoading
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onSurfaceVariant,
                            semanticsLabel: 'İşlem devam ediyor'.tr,
                          ),
                        )
                      : Icon(icon, key: const ValueKey('icon'), size: 20),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(child: AppText(label, textAlign: TextAlign.center)),
            ],
          ),
        ),
      ),
    );
  }
}
