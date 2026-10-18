import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One viewport-anchored studio surface behind the Navigator and its overlays.
///
/// Scaffolds are transparent; cards, sheets and navigation keep their existing
/// opaque surfaces. Keeping this outside routes also avoids stacking the artwork
/// in nested scaffolds or moving it when a form opens the keyboard.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _StudioSurfacePainter(
                    base: theme.canvasColor,
                    violet: theme.colorScheme.primary,
                    pearl: theme.colorScheme.secondary,
                    // Luminance follows AnimatedTheme, including intermediate
                    // frames, so switching modes never snaps the lighting.
                    lightness: theme.canvasColor.computeLuminance(),
                  ),
                  isComplex: true,
                  willChange: false,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _StudioSurfacePainter extends CustomPainter {
  const _StudioSurfacePainter({
    required this.base,
    required this.violet,
    required this.pearl,
    required this.lightness,
  });

  final Color base;
  final Color violet;
  final Color pearl;
  final double lightness;

  double _strength(double dark, double light) =>
      dark + (light - dark) * lightness;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    // Limit the artwork's scale on tablets/landscape instead of stretching a
    // portrait texture. All paths stay at the periphery of the reading area.
    final span = math.min(size.width, 600.0);
    final depth = math.min(size.height, 1000.0);
    canvas.drawColor(base, BlendMode.src);

    void light(Offset center, double radius, Color tint, double opacity) {
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            colors: [
              tint.withValues(alpha: opacity),
              tint.withValues(alpha: opacity * .38),
              tint.withValues(alpha: 0),
            ],
            stops: const [0, .42, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // Broad reflected light, rather than distinct blobs or an animated glow.
    light(
      Offset(size.width - span * .08, depth * .08),
      span * 1.12,
      violet,
      _strength(.17, .065),
    );
    light(
      Offset(-span * .22, size.height - depth * .12),
      span * 1.25,
      pearl,
      _strength(.085, .04),
    );

    // A pair of swept panel edges recalls automotive surface modelling. The
    // shader feathers both ends; the central content has no repeating pattern.
    final upperPanel = Path()
      ..moveTo(size.width - span * .62, -depth * .08)
      ..cubicTo(
        size.width - span * .58,
        depth * .19,
        size.width - span * .04,
        depth * .22,
        size.width + span * .13,
        depth * .64,
      );
    final lowerPanel = Path()
      ..moveTo(-span * .17, size.height - depth * .64)
      ..cubicTo(
        span * .05,
        size.height - depth * .31,
        span * .34,
        size.height - depth * .27,
        span * .46,
        size.height + depth * .08,
      );
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          pearl.withValues(alpha: 0),
          pearl.withValues(alpha: _strength(.12, .095)),
          violet.withValues(alpha: 0),
        ],
        stops: const [0, .48, 1],
      ).createShader(bounds);
    canvas.drawPath(upperPanel, edge);
    canvas.drawPath(lowerPanel, edge);
  }

  @override
  bool shouldRepaint(_StudioSurfacePainter oldDelegate) =>
      base != oldDelegate.base ||
      violet != oldDelegate.violet ||
      pearl != oldDelegate.pearl ||
      lightness != oldDelegate.lightness;
}
