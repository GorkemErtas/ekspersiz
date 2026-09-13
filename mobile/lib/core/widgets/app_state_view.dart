import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_motion.dart';

class AppStateView extends StatelessWidget {
  const AppStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onActionPressed,
    this.actionIcon,
    this.isLoading = false,
    this.isError = false,
    this.bottomPadding = 32,
  });

  const AppStateView.loading({
    super.key,
    this.title = 'Yükleniyor',
    this.message = 'Lütfen bekleyin...',
    this.bottomPadding = 32,
  }) : icon = Icons.hourglass_top_rounded,
       actionLabel = null,
       onActionPressed = null,
       actionIcon = null,
       isLoading = true,
       isError = false;

  const AppStateView.empty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onActionPressed,
    this.actionIcon,
    this.bottomPadding = 32,
  }) : isLoading = false,
       isError = false;

  const AppStateView.error({
    super.key,
    this.icon = Icons.error_outline_rounded,
    this.title = 'Bir sorun oluştu',
    required this.message,
    this.actionLabel = 'Tekrar Dene',
    this.onActionPressed,
    this.actionIcon = Icons.refresh_rounded,
    this.bottomPadding = 32,
  }) : isLoading = false,
       isError = true;

  final IconData icon;

  final String title;
  final String message;

  final String? actionLabel;
  final IconData? actionIcon;

  final VoidCallback? onActionPressed;

  final bool isLoading;
  final bool isError;

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    final foregroundColor = isError ? colorScheme.error : colorScheme.primary;

    final backgroundColor = isError
        ? colorScheme.errorContainer
        : colorScheme.primaryContainer;

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: EdgeInsets.fromLTRB(32, 32, 32, bottomPadding),

        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),

          child: AppFadeSlideIn(
            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.94, end: 1),

                  duration: const Duration(milliseconds: 360),

                  curve: Curves.easeOutBack,

                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },

                  child: Container(
                    width: 92,

                    height: 92,

                    decoration: BoxDecoration(
                      color: backgroundColor,

                      borderRadius: BorderRadius.circular(28),

                      boxShadow: isError ? null : AppTheme.softShadow,
                    ),

                    child: isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(28),

                            child: CircularProgressIndicator(
                              strokeWidth: 3,

                              color: foregroundColor,
                            ),
                          )
                        : Icon(icon, size: 44, color: foregroundColor),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  title,

                  textAlign: TextAlign.center,

                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 9),

                Text(
                  message,

                  textAlign: TextAlign.center,

                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,

                    height: 1.5,
                  ),
                ),

                if (actionLabel != null && onActionPressed != null) ...[
                  const SizedBox(height: 24),

                  FilledButton.tonalIcon(
                    onPressed: onActionPressed,
                    icon: Icon(actionIcon ?? Icons.arrow_forward_rounded),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
