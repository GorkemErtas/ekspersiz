import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/onboarding_step.dart';

/// Decorative, offline product illustrations. The adjacent page copy carries
/// the accessible meaning; miniature UI labels are not interactive controls.
class GuideArtwork extends StatelessWidget {
  const GuideArtwork({super.key, required this.feature});

  final GuideFeature feature;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: scheme.primary.withValues(alpha: .18)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primaryContainer,
                scheme.surface,
                scheme.secondaryContainer.withValues(alpha: .7),
              ],
            ),
          ),
          child: AspectRatio(
            aspectRatio: 1.2,
            child: FittedBox(
              child: MediaQuery.withNoTextScaling(
                child: SizedBox(
                  width: 360,
                  height: 300,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _OrbitPainter(scheme)),
                      ),
                      Positioned(
                        top: 22,
                        left: 24,
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 14,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'EKSPERSİZ',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...switch (feature) {
                        GuideFeature.welcome => _welcome(context),
                        GuideFeature.analysis => _analysis(context),
                        GuideFeature.reports => _reports(context),
                        GuideFeature.garage => _garage(context),
                        GuideFeature.assistant => _assistant(context),
                        GuideFeature.credits => _credits(context),
                      },
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _welcome(BuildContext context) => [
    Positioned(
      left: 30,
      right: 30,
      top: 66,
      height: 162,
      child: CustomPaint(painter: _CarPainter(Theme.of(context).colorScheme)),
    ),
    const Positioned(
      top: 59,
      right: 24,
      child: _MiniCard(icon: Icons.auto_awesome, title: 'AI ile keşfet'),
    ),
    const Positioned(
      left: 24,
      bottom: 24,
      child: _MiniCard(
        icon: Icons.directions_car_rounded,
        title: 'Aracın için tek yer',
        subtitle: 'Analiz · Bakım · Asistan',
      ),
    ),
    Positioned(
      right: 30,
      bottom: 33,
      child: _Seal(icon: Icons.arrow_forward_rounded),
    ),
  ];

  List<Widget> _analysis(BuildContext context) => [
    Positioned(
      left: 26,
      right: 26,
      top: 65,
      height: 157,
      child: CustomPaint(painter: _CarPainter(Theme.of(context).colorScheme)),
    ),
    Positioned(
      left: 42,
      top: 71,
      width: 276,
      height: 148,
      child: CustomPaint(painter: _ScanPainter(Theme.of(context).colorScheme)),
    ),
    Positioned(
      right: 57,
      top: 137,
      child: Container(
        width: 42,
        height: 30,
        decoration: BoxDecoration(
          color: AppTheme.warningSoftFor(context).withValues(alpha: .85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.warningColorFor(context),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.center_focus_strong_rounded,
          size: 18,
          color: AppTheme.warningColorFor(context),
        ),
      ),
    ),
    const Positioned(
      left: 24,
      bottom: 23,
      right: 24,
      child: _MiniCard(
        icon: Icons.add_a_photo_outlined,
        title: 'Genel görünüm ve yakın detay',
        subtitle: 'Çek veya galeriden seç',
      ),
    ),
  ];

  List<Widget> _reports(BuildContext context) => [
    Positioned(
      left: 55,
      right: 42,
      top: 58,
      bottom: 40,
      child: Transform.rotate(
        angle: .07,
        child: _Panel(child: const SizedBox.expand()),
      ),
    ),
    Positioned(
      left: 36,
      right: 52,
      top: 54,
      bottom: 48,
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text('AI hasar raporu', style: _label(context)),
              ],
            ),
            const SizedBox(height: 18),
            const _ReportLine(width: 156),
            const SizedBox(height: 9),
            const _ReportLine(width: 115),
            const SizedBox(height: 18),
            const _MiniRow(
              icon: Icons.manage_search_rounded,
              text: 'Hasar detayları',
            ),
            const SizedBox(height: 10),
            const _MiniRow(icon: Icons.history_rounded, text: 'Analiz geçmişi'),
          ],
        ),
      ),
    ),
    const Positioned(
      bottom: 24,
      right: 23,
      child: _MiniCard(
        icon: Icons.folder_open_rounded,
        title: 'Hepsi bir arada',
      ),
    ),
  ];

  List<Widget> _garage(BuildContext context) => [
    Positioned(
      top: 59,
      left: 26,
      right: 26,
      child: _Panel(
        child: Row(
          children: [
            _Seal(icon: Icons.directions_car_filled_rounded),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dijital garajım', style: _label(context)),
                const SizedBox(height: 5),
                Text('Kilometre ve bakım takibi', style: _small(context)),
              ],
            ),
          ],
        ),
      ),
    ),
    const Positioned(
      top: 151,
      left: 42,
      right: 26,
      child: _MiniCard(
        icon: Icons.build_outlined,
        title: 'Bakım kayıtların',
        subtitle: 'Aracının hikâyesi elinin altında',
      ),
    ),
    const Positioned(
      top: 223,
      left: 26,
      right: 42,
      child: _MiniCard(
        icon: Icons.notifications_active_outlined,
        title: 'Sıradaki tarihi hatırla',
      ),
    ),
  ];

  List<Widget> _assistant(BuildContext context) => [
    Positioned(
      top: 58,
      left: 26,
      right: 70,
      child: _Panel(
        child: Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bakımda nelere dikkat etmeliyim?',
                style: _label(context),
              ),
            ),
          ],
        ),
      ),
    ),
    Positioned(
      top: 139,
      left: 65,
      right: 26,
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _MiniRow(icon: Icons.auto_awesome, text: 'AI Asistan'),
            const SizedBox(height: 14),
            const _ReportLine(width: 171),
            const SizedBox(height: 8),
            const _ReportLine(width: 125),
          ],
        ),
      ),
    ),
    const Positioned(
      bottom: 20,
      left: 26,
      child: _MiniCard(
        icon: Icons.location_on_outlined,
        title: 'Yakındaki uygun servisler',
      ),
    ),
  ];

  List<Widget> _credits(BuildContext context) => [
    Positioned(
      top: 65,
      left: 26,
      width: 148,
      height: 121,
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.center_focus_strong_rounded,
              size: 28,
              color: Theme.of(context).colorScheme.primary,
            ),
            const Spacer(),
            Text('Analiz', style: _label(context)),
            const SizedBox(height: 3),
            Text('Ayrı kredi bakiyesi', style: _small(context)),
          ],
        ),
      ),
    ),
    Positioned(
      top: 78,
      right: 26,
      width: 148,
      height: 121,
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 28,
              color: Theme.of(context).colorScheme.primary,
            ),
            const Spacer(),
            Text('Asistan', style: _label(context)),
            const SizedBox(height: 3),
            Text('Ayrı kredi bakiyesi', style: _small(context)),
          ],
        ),
      ),
    ),
    const Positioned(
      left: 26,
      right: 26,
      bottom: 22,
      child: _MiniCard(
        icon: Icons.groups_outlined,
        title: 'Kurumsal ortak kullanım',
        subtitle: 'Şirketinle, yetkilerin dahilinde',
      ),
    ),
  ];

  static TextStyle _label(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onSurface,
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  static TextStyle _small(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    fontSize: 10,
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: .08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GuideArtwork._label(context)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: GuideArtwork._small(context)),
            ],
          ],
        ),
      ],
    ),
  );
}

class _MiniRow extends StatelessWidget {
  const _MiniRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 9),
      Text(text, style: GuideArtwork._small(context)),
    ],
  );
}

class _Seal extends StatelessWidget {
  const _Seal({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      gradient: AppTheme.brandGradient,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Icon(icon, color: Colors.white, size: 24),
  );
}

class _ReportLine extends StatelessWidget {
  const _ReportLine({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 6,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .2),
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter(this.scheme);
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = scheme.primary.withValues(alpha: .1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final radius in [88.0, 132.0, 176.0]) {
      canvas.drawCircle(
        Offset(size.width * .65, size.height * .42),
        radius,
        paint,
      );
    }
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(24 + i * 8, size.height - 11),
        1,
        paint..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter oldDelegate) => scheme != oldDelegate.scheme;
}

class _CarPainter extends CustomPainter {
  const _CarPainter(this.scheme);
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300, size.height / 162);
    canvas.drawOval(
      const Rect.fromLTWH(20, 131, 264, 15),
      Paint()..color = scheme.primary.withValues(alpha: .15),
    );
    final body = Path()
      ..moveTo(14, 106)
      ..quadraticBezierTo(14, 89, 36, 83)
      ..lineTo(70, 74)
      ..lineTo(103, 43)
      ..quadraticBezierTo(111, 36, 128, 36)
      ..lineTo(179, 36)
      ..quadraticBezierTo(192, 37, 203, 49)
      ..lineTo(227, 76)
      ..lineTo(270, 87)
      ..quadraticBezierTo(285, 90, 286, 107)
      ..lineTo(282, 122)
      ..lineTo(19, 122)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.primary, scheme.primaryContainer],
        ).createShader(const Rect.fromLTWH(14, 36, 272, 91)),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = scheme.primary.withValues(alpha: .8),
    );
    final glass = Paint()..color = scheme.surface;
    canvas.drawPath(
      Path()
        ..moveTo(89, 75)
        ..lineTo(113, 48)
        ..lineTo(145, 48)
        ..lineTo(145, 75)
        ..close(),
      glass,
    );
    canvas.drawPath(
      Path()
        ..moveTo(154, 48)
        ..lineTo(179, 48)
        ..quadraticBezierTo(185, 48, 191, 55)
        ..lineTo(209, 75)
        ..lineTo(154, 75)
        ..close(),
      glass,
    );
    final detail = Paint()
      ..color = scheme.onPrimaryContainer.withValues(alpha: .45)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(150, 82), const Offset(150, 115), detail);
    canvas.drawLine(
      const Offset(162, 86),
      const Offset(175, 86),
      detail..strokeWidth = 3,
    );
    canvas.drawLine(
      const Offset(34, 97),
      const Offset(52, 97),
      Paint()
        ..color = scheme.onPrimary
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    for (final x in [70.0, 233.0]) {
      canvas.drawCircle(Offset(x, 122), 23, Paint()..color = scheme.surface);
      canvas.drawCircle(
        Offset(x, 122),
        15,
        Paint()..color = scheme.onSurfaceVariant,
      );
      canvas.drawCircle(
        Offset(x, 122),
        10,
        Paint()..color = scheme.surfaceContainerHigh,
      );
      for (var n = 0; n < 5; n++) {
        final angle = n * math.pi * 2 / 5;
        canvas.drawLine(
          Offset(x, 122),
          Offset(x + math.cos(angle) * 11, 122 + math.sin(angle) * 11),
          Paint()
            ..color = scheme.onSurfaceVariant
            ..strokeWidth = 2,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CarPainter oldDelegate) => scheme != oldDelegate.scheme;
}

class _ScanPainter extends CustomPainter {
  const _ScanPainter(this.scheme);
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = scheme.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final point in [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      final dx = point.dx == 0 ? 1 : -1;
      final dy = point.dy == 0 ? 1 : -1;
      canvas.drawPath(
        Path()
          ..moveTo(point.dx, point.dy + dy * 18)
          ..lineTo(point.dx, point.dy)
          ..lineTo(point.dx + dx * 18, point.dy),
        paint,
      );
    }
    canvas.drawLine(
      Offset(size.width * .58, 8),
      Offset(size.width * .58, size.height - 8),
      Paint()
        ..color = scheme.primary.withValues(alpha: .4)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_ScanPainter oldDelegate) => scheme != oldDelegate.scheme;
}
