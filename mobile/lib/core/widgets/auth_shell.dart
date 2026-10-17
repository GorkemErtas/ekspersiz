import 'package:mobile/core/localization/app_text.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_motion.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.child,
    this.maxWidth = 460,
    this.showBrand = true,
  });

  final Widget child;
  final double maxWidth;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: AppFadeSlideIn(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showBrand) ...[
                      const _BrandHeader(),
                      const SizedBox(height: 28),
                    ],
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(
                        MediaQuery.sizeOf(context).width < 360 ? 18 : 24,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusXLarge,
                        ),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppTheme.primaryShadowFor(context),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/ekspersiz_logo.png',
            fit: BoxFit.cover,
            cacheWidth: 256,
            cacheHeight: 256,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('LOGO ASSET ERROR: $error');

              return const Center(
                child: Icon(
                  Icons.directions_car_filled_rounded,
                  size: 48,
                  color: Color(0xFF8B5CF6),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        AppText(
          'EksperSiz',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 6),
        AppText(
          'AI destekli araç hasar analizi',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
