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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.72, -0.78),
                  radius: 1.15,
                  colors: isDark
                      ? const [
                          Color(0xFF24123B),
                          Color(0xFF0B090E),
                          Color(0xFF08070B),
                        ]
                      : const [
                          Color(0xFFEFE2FF),
                          Color(0xFFF8F4FC),
                          Color(0xFFFFFFFF),
                        ],
                  stops: const [0, 0.52, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: -110,
            top: -115,
            child: _GlowOrb(
              size: 300,
              color: AppTheme.primaryColor.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            right: -105,
            top: 70,
            child: _GlowOrb(
              size: 270,
              color: AppTheme.secondaryColor.withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            left: -70,
            bottom: -150,
            child: _GlowOrb(
              size: 330,
              color: AppTheme.primaryDark.withValues(alpha: 0.11),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 28,
                ),
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
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusXLarge,
                            ),
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.14,
                              ),
                            ),
                            boxShadow: AppTheme.elevatedShadowFor(context),
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
        ],
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
        Text(
          'EksperSiz',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 6),
        Text(
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

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 100, spreadRadius: 18),
          ],
        ),
      ),
    );
  }
}
