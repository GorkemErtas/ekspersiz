import 'package:mobile/core/localization/app_text.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_motion.dart';

class PrimaryButton extends StatefulWidget {
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
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;
  bool get _enabled => !widget.isLoading && widget.onPressed != null;

  void _setPressed(bool value) {
    if (!_enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: AppMotion.fast,
        curve: AppMotion.standardCurve,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.standardCurve,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: _enabled ? AppTheme.brandGradient : null,
            color: _enabled ? null : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: _enabled
                  ? AppTheme.secondaryColor.withValues(alpha: 0.22)
                  : scheme.outlineVariant,
            ),
            boxShadow: _enabled && !_pressed
                ? AppTheme.primaryShadowFor(context)
                : const [],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _enabled ? widget.onPressed : null,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: AppMotion.medium,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.96,
                          end: 1,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: widget.isLoading
                        ? const SizedBox(
                            key: ValueKey('loading'),
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            key: const ValueKey('content'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(
                                  widget.icon,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                              ],
                              AppText(
                                widget.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
