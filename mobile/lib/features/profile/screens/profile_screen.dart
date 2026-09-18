import 'package:mobile/core/localization/app_text.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_theme_controller.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon_box.dart';
import '../../../core/widgets/app_status_badge.dart';

import '../../auth/screens/change_password_screen.dart';
import '../../auth/models/business_account.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../business/screens/business_management_screen.dart';
import '../../billing/screens/subscription_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.fullName,
    required this.email,
    required this.subscriptionPlan,
    this.businessAccount,
    this.onBusinessAccountChanged,
    this.onSubscriptionPlanChanged,
  });

  final String fullName;
  final String email;
  final String subscriptionPlan;
  final BusinessAccount? businessAccount;
  final ValueChanged<BusinessAccount>? onBusinessAccountChanged;
  final ValueChanged<String>? onSubscriptionPlanChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = const AuthService();

  bool _isLoggingOut = false;

  String get _subscriptionPlanLabel {
    return switch (widget.subscriptionPlan) {
      'FREE' => 'Ücretsiz',
      'PLUS' => 'Plus',
      'PRO' => 'Pro',
      'BUSINESS' => 'Kurumsal',
      _ => widget.subscriptionPlan,
    };
  }

  Color _subscriptionColor(BuildContext context) {
    return switch (widget.subscriptionPlan) {
      'PLUS' => AppTheme.infoColorFor(context),
      'PRO' => AppTheme.warningColorFor(context),
      _ => AppTheme.neutralColorFor(context),
    };
  }

  Color _subscriptionBackgroundColor(BuildContext context) {
    return switch (widget.subscriptionPlan) {
      'PLUS' => AppTheme.infoSoftFor(context),
      'PRO' => AppTheme.warningSoftFor(context),
      _ => AppTheme.neutralSoftFor(context),
    };
  }

  Future<void> _openChangePassword() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ChangePasswordScreen()),
    );

    if (changed != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: AppText('Şifreniz başarıyla güncellendi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _openSubscription() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()),
    );

    if (!mounted) {
      return;
    }

    try {
      final profile = await _authService.getCurrentUser();

      if (mounted) {
        widget.onSubscriptionPlanChanged?.call(profile.subscriptionPlan);
      }
    } catch (_) {
      // The subscription screen already shows billing errors. The next session
      // refresh will reconcile the profile if this lightweight refresh fails.
    }
  }

  Future<void> _openBusinessManagement() async {
    final businessAccount = await Navigator.of(context).push<BusinessAccount>(
      MaterialPageRoute<BusinessAccount>(
        builder: (_) => BusinessManagementScreen(
          subscriptionPlan: widget.subscriptionPlan,
          businessAccount: widget.businessAccount,
        ),
      ),
    );

    if (businessAccount != null && mounted) {
      widget.onBusinessAccountChanged?.call(businessAccount);
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const AppText('Çıkış yapılsın mı?'),
          content: const AppText(
            'Hesabınızdan çıkış yapmak '
            'istediğinize emin misiniz?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const AppText('İptal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const AppText('Çıkış Yap'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await PushNotificationService.instance.unregisterCurrentDevice();
      await _authService.logout();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: AppText('Çıkış işlemi tamamlanamadı.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  String _initials() {
    final parts = widget.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'VI';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final canManageBusiness =
        widget.subscriptionPlan == 'BUSINESS' &&
        (widget.businessAccount == null || widget.businessAccount!.isOwner);
    final canAcceptBusinessInvitation =
        widget.subscriptionPlan != 'BUSINESS' && widget.businessAccount == null;

    return Scaffold(
      appBar: AppBar(title: const AppText('Profil')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppTheme.maxContentWidth,
            ),
            child: ListView(
              padding: AppTheme.pagePadding,
              children: [
                AppCard(
                  showShadow: false,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: AppTheme.brandGradient,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        alignment: Alignment.center,
                        child: AppText(
                          _initials(),
                          style: textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppText(
                        widget.fullName,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          AppStatusBadge(
                            label: _subscriptionPlanLabel,
                            color: _subscriptionColor(context),
                            backgroundColor: _subscriptionBackgroundColor(
                              context,
                            ),
                            icon: Icons.workspace_premium_outlined,
                          ),
                          if (widget.businessAccount != null)
                            AppStatusBadge(
                              label: widget.businessAccount!.roleLabel,
                              color: colorScheme.primary,
                              backgroundColor: colorScheme.primaryContainer,
                              icon: Icons.business_rounded,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AppCard(
                  showShadow: false,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ProfileItem(
                        icon: Icons.person_outline_rounded,
                        title: 'Ad Soyad',
                        value: widget.fullName,
                      ),
                      const Divider(height: 1, indent: 82),
                      _ProfileItem(
                        icon: Icons.mail_outline_rounded,
                        title: 'E-posta',
                        value: widget.email,
                      ),
                      const Divider(height: 1, indent: 82),
                      _ProfileItem(
                        icon: Icons.workspace_premium_outlined,
                        title: 'Abonelik Planı',
                        value: _subscriptionPlanLabel,
                      ),
                      if (widget.businessAccount != null) ...[
                        const Divider(height: 1, indent: 82),
                        _ProfileItem(
                          icon: Icons.business_rounded,
                          title: 'Şirket',
                          value: widget.businessAccount!.companyName,
                        ),
                        const Divider(height: 1, indent: 82),
                        _ProfileItem(
                          icon: Icons.admin_panel_settings_outlined,
                          title: 'Şirket Rolü',
                          value: widget.businessAccount!.roleLabel,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AppCard(
                  showShadow: false,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      const _ThemeModeProfileItem(),
                      const Divider(height: 1, indent: 82),
                      _ActionProfileItem(
                        icon: Icons.workspace_premium_outlined,
                        title: 'Abonelik ve Ödeme',
                        subtitle:
                            'Planları karşılaştırın, satın alımları geri yükleyin ve aboneliğinizi yönetin.',
                        onTap: _openSubscription,
                      ),
                      const Divider(height: 1, indent: 82),
                      if (canManageBusiness) ...[
                        _ActionProfileItem(
                          icon: Icons.business_center_outlined,
                          title: 'Şirket İşlemleri',
                          subtitle: widget.businessAccount == null
                              ? 'Şirket oluşturun veya bir şirket davetini kabul edin.'
                              : 'Çalışanları görüntüleyin, davet edin ve yönetin.',
                          onTap: _openBusinessManagement,
                        ),
                        const Divider(height: 1, indent: 82),
                      ],
                      if (canAcceptBusinessInvitation) ...[
                        _ActionProfileItem(
                          icon: Icons.mark_email_read_outlined,
                          title: 'Şirket Daveti',
                          subtitle:
                              'E-postanıza gönderilen şirket davetini kabul edin.',
                          onTap: _openBusinessManagement,
                        ),
                        const Divider(height: 1, indent: 82),
                      ],
                      _ActionProfileItem(
                        icon: Icons.lock_reset_rounded,
                        title: 'Şifre Değiştir',
                        subtitle:
                            'Hesap şifrenizi güvenli şekilde güncelleyin.',
                        onTap: _openChangePassword,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AppCard(
                  showShadow: false,
                  backgroundColor: colorScheme.surfaceContainerLow,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppIconBox(
                        icon: Icons.info_outline_rounded,
                        size: 42,
                        iconSize: 21,
                        borderRadius: 14,
                        backgroundColor: AppTheme.infoSoftFor(context),
                        iconColor: AppTheme.infoColorFor(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              'EksperSiz',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AppText(
                              'Araç hasarlarını yapay zekâ destekli '
                              'görüntü analizi ile inceleyin.',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoggingOut ? null : _logout,
                    icon: _isLoggingOut
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.error,
                            ),
                          )
                        : const Icon(Icons.logout_rounded),
                    label: AppText(
                      _isLoggingOut ? 'Çıkış yapılıyor...' : 'Çıkış Yap',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(
                        color: colorScheme.error.withValues(alpha: 0.55),
                      ),
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeModeProfileItem extends StatelessWidget {
  const _ThemeModeProfileItem();

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isDark = controller.isDarkMode;
        return InkWell(
          onTap: () => controller.setDarkMode(!isDark),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeInOutCubic,
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isDark
                        ? colorScheme.primaryContainer
                        : AppTheme.warningSoftFor(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, animation) => RotationTransition(
                      turns: Tween<double>(begin: 0.7, end: 1).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      key: ValueKey(isDark),
                      color: isDark
                          ? colorScheme.secondary
                          : AppTheme.warningColorFor(context),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Görünüm',
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: AppText(
                          isDark ? 'Koyu tema' : 'Açık tema',
                          key: ValueKey(isDark),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isDark,
                  onChanged: controller.setDarkMode,
                  thumbIcon: WidgetStateProperty.resolveWith(
                    (states) => Icon(
                      states.contains(WidgetState.selected)
                          ? Icons.nightlight_round
                          : Icons.wb_sunny_rounded,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileItem extends StatelessWidget {
  const _ProfileItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          AppIconBox(icon: icon, size: 46, iconSize: 22, borderRadius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                AppText(
                  value,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionProfileItem extends StatelessWidget {
  const _ActionProfileItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            AppIconBox(icon: icon, size: 46, iconSize: 22, borderRadius: 14),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    title,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AppText(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
