import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
    final colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color:
                Theme.of(context)
                    .scaffoldBackgroundColor,
              ),
            ),
          ),

          // Sol üst dekor
          Positioned(
            left: -110,
            top: -100,
            child: _BackgroundCircle(
              size: 260,
              color:
              AppTheme.primaryColor
                  .withValues(
                alpha: 0.08,
              ),
            ),
          ),

          // Sağ üst dekor
          Positioned(
            right: -80,
            top: 80,
            child: _BackgroundCircle(
              size: 220,
              color:
              AppTheme.secondaryColor
                  .withValues(
                alpha: 0.07,
              ),
            ),
          ),

          // Alt dekor
          Positioned(
            left: -40,
            bottom: -110,
            child: _BackgroundCircle(
              size: 240,
              color:
              AppTheme.primaryColor
                  .withValues(
                alpha: 0.045,
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                  ),
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      if (showBrand) ...[
                        const _BrandHeader(),
                        const SizedBox(
                          height: 28,
                        ),
                      ],

                      Container(
                        width: double.infinity,
                        padding:
                        const EdgeInsets.all(
                          24,
                        ),
                        decoration:
                        BoxDecoration(
                          color:
                          colorScheme.surface,

                          borderRadius:
                          BorderRadius.circular(
                            AppTheme
                                .radiusXLarge,
                          ),

                          border:
                          Border.all(
                            color:
                            colorScheme
                                .outlineVariant,
                          ),

                          boxShadow:
                          AppTheme
                              .elevatedShadow,
                        ),
                        child: child,
                      ),
                    ],
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

class _BrandHeader
    extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme =
        Theme.of(context).textTheme;

    final colorScheme =
        Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            gradient:
            const LinearGradient(
              colors: [
                AppTheme.primaryColor,
                AppTheme.secondaryColor,
              ],
              begin:
              Alignment.topLeft,
              end:
              Alignment.bottomRight,
            ),
            borderRadius:
            BorderRadius.circular(
              22,
            ),
            boxShadow:
            AppTheme.primaryShadow,
          ),
          child: const Icon(
            Icons.car_crash_rounded,
            size: 34,
            color: Colors.white,
          ),
        ),

        const SizedBox(
          height: 16,
        ),

        Text(
          'Vehicle Inspector',
          style:
          textTheme.headlineSmall
              ?.copyWith(
            fontWeight:
            FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),

        const SizedBox(
          height: 6,
        ),

        Text(
          'AI destekli araç hasar analizi',
          textAlign:
          TextAlign.center,
          style:
          textTheme.bodyMedium
              ?.copyWith(
            color:
            colorScheme
                .onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _BackgroundCircle
    extends StatelessWidget {
  const _BackgroundCircle({
    required this.size,
    required this.color,
  });

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
        ),
      ),
    );
  }
}