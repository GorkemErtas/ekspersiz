import 'package:flutter/material.dart';

import '../../../core/localization/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/onboarding_store.dart';
import '../models/onboarding_step.dart';
import '../widgets/guide_artwork.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required VoidCallback this.onFinished,
    this.store = const OnboardingStore(),
  }) : isReplay = false;

  const OnboardingScreen.replay({super.key})
    : isReplay = true,
      onFinished = null,
      store = const OnboardingStore();

  final VoidCallback? onFinished;
  final OnboardingStore store;
  final bool isReplay;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;
  bool _saving = false;
  bool _leaving = false;
  String? _saveError;

  bool get _isLast => _index == onboardingSteps.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (_saving || _leaving || !_pages.hasClients) return;
    if (AppMotion.reduceMotion(context)) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(
        index,
        duration: AppMotion.slow,
        curve: AppMotion.standardCurve,
      );
    }
  }

  Future<void> _finish() async {
    if (_saving || _leaving) return;
    if (widget.isReplay) {
      _leaving = true;
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.store.complete();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Tercihin kaydedilemedi. Lütfen yeniden dene.';
      });
      return;
    }
    if (!mounted) return;
    _leaving = true;
    widget.onFinished!();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      // At the root, system back exits without marking the guide complete.
      // In replay it returns to the profile; elsewhere it goes one page back.
      canPop: !_saving && _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _index > 0) _goTo(_index - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 12, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: AppTheme.brandGradient,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppText(
                            'EksperSiz',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton(
                          onPressed: _saving ? null : _finish,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(64, 48),
                          ),
                          child: AppText(widget.isReplay ? 'Kapat' : 'Atla'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: onboardingSteps.length,
                      allowImplicitScrolling: true,
                      physics: _saving
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      onPageChanged: (value) => setState(() => _index = value),
                      itemBuilder: (context, index) => _FeaturePage(
                        key: ValueKey('guide-page-$index'),
                        step: onboardingSteps[index],
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            liveRegion: true,
                            label:
                                'Adım ${_index + 1} / ${onboardingSteps.length}: ${onboardingSteps[_index].category}',
                            child: ExcludeSemantics(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: List.generate(
                                        onboardingSteps.length,
                                        (index) => Expanded(
                                          child: AnimatedContainer(
                                            duration: AppMotion.duration(
                                              context,
                                              AppMotion.medium,
                                            ),
                                            height: 4,
                                            margin: const EdgeInsets.only(
                                              right: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              color: index <= _index
                                                  ? scheme.primary
                                                  : scheme.outlineVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  AppText(
                                    '${_index + 1} / ${onboardingSteps.length}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_saveError != null) ...[
                            const SizedBox(height: 8),
                            Semantics(
                              liveRegion: true,
                              child: AppText(
                                _saveError!,
                                style: TextStyle(color: scheme.error),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              if (_index > 0) ...[
                                TextButton(
                                  onPressed: _saving
                                      ? null
                                      : () => _goTo(_index - 1),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(64, 50),
                                  ),
                                  child: const AppText('Geri'),
                                ),
                                const SizedBox(width: 14),
                              ],
                              Expanded(
                                child: PrimaryButton(
                                  label: _saveError != null
                                      ? 'Yeniden Dene'
                                      : _isLast
                                      ? (widget.isReplay ? 'Tamam' : 'Başla')
                                      : 'İleri',
                                  icon: _isLast
                                      ? Icons.check_rounded
                                      : Icons.arrow_forward_rounded,
                                  isLoading: _saving,
                                  onPressed: _isLast || _saveError != null
                                      ? _finish
                                      : () => _goTo(_index + 1),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturePage extends StatelessWidget {
  const _FeaturePage({super.key, required this.step});
  final OnboardingStep step;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final sideBySide = constraints.maxWidth >= 700;
      final scheme = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;
      final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText(
            step.category,
            style: textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: AppText(
              step.title,
              style: textTheme.headlineLarge?.copyWith(
                fontSize: constraints.maxWidth < 360 ? 27 : 32,
                height: 1.13,
                fontWeight: FontWeight.w800,
                letterSpacing: -.9,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppText(
            step.description,
            style: textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  step.feature == GuideFeature.reports
                      ? Icons.info_outline_rounded
                      : Icons.subdirectory_arrow_right_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppText(
                    step.hint,
                    style: textTheme.bodySmall?.copyWith(
                      height: 1.5,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      final artwork = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: GuideArtwork(feature: step.feature),
      );
      return SingleChildScrollView(
        key: PageStorageKey('guide-scroll-${step.feature.name}'),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 40).clamp(0, double.infinity),
          ),
          child: Center(
            child: sideBySide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: artwork),
                      const SizedBox(width: 36),
                      Expanded(child: copy),
                    ],
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: artwork),
                        const SizedBox(height: 26),
                        copy,
                      ],
                    ),
                  ),
          ),
        ),
      );
    },
  );
}
