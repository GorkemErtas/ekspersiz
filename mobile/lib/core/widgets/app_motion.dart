import 'package:flutter/material.dart';

class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 120);

  static const Duration medium = Duration(milliseconds: 220);

  static const Duration slow = Duration(milliseconds: 420);

  static const Curve standardCurve = Curves.easeOutCubic;
}

class AppPressScale extends StatefulWidget {
  const AppPressScale({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.pressedScale = 0.985,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final double pressedScale;

  @override
  State<AppPressScale> createState() => _AppPressScaleState();
}

class _AppPressScaleState extends State<AppPressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null || _pressed == value) {
      return;
    }

    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onPointerUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onPointerCancel: widget.onTap == null ? null : (_) => _setPressed(false),

      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,

        duration: AppMotion.fast,

        curve: AppMotion.standardCurve,

        child: Material(
          color: Colors.transparent,

          borderRadius: widget.borderRadius,

          clipBehavior: Clip.antiAlias,

          child: InkWell(
            onTap: widget.onTap,

            borderRadius: widget.borderRadius,

            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class AppFadeSlideIn extends StatefulWidget {
  const AppFadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.035),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<AppFadeSlideIn> createState() => _AppFadeSlideInState();
}

class _AppFadeSlideInState extends State<AppFadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _opacity;

  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: AppMotion.slow);

    final curved = CurvedAnimation(
      parent: _controller,

      curve: AppMotion.standardCurve,
    );

    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);

    _slide = Tween<Offset>(
      begin: widget.offset,

      end: Offset.zero,
    ).animate(curved);

    Future<void>.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,

      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
