import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon_box.dart';
import '../../../core/widgets/app_status_badge.dart';

import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.fullName,
    required this.email,
    required this.role,
    required this.subscriptionPlan,
  });

  final String fullName;
  final String email;
  final String role;
  final String subscriptionPlan;

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  final AuthService _authService =
  const AuthService();

  bool _isLoggingOut = false;

  String get _roleLabel {
    return switch (widget.role) {
      'ADMIN' => 'Yönetici',
      'INSPECTOR' => 'Eksper',
      'USER' => 'Kullanıcı',
      _ => widget.role,
    };
  }

  String get _subscriptionPlanLabel {
    return switch (widget.subscriptionPlan) {
      'FREE' => 'Free',
      'PLUS' => 'Plus',
      'PRO' => 'Pro',
      _ => widget.subscriptionPlan,
    };
  }

  Color _subscriptionColor() {
    return switch (widget.subscriptionPlan) {
      'PLUS' => AppTheme.infoColor,
      'PRO' => AppTheme.warningColor,
      _ => AppTheme.severityUnknown,
    };
  }

  Color _subscriptionBackgroundColor() {
    return switch (widget.subscriptionPlan) {
      'PLUS' => AppTheme.infoSoft,
      'PRO' => AppTheme.warningSoft,
      _ => const Color(0xFFF1F5F9),
    };
  }

  Future<void> _logout() async {
    final shouldLogout =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Çıkış yapılsın mı?',
          ),
          content: const Text(
            'Hesabınızdan çıkış yapmak '
                'istediğinize emin misiniz?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'İptal',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'Çıkış Yap',
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true ||
        !mounted) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.logout();

      if (!mounted) {
        return;
      }

      Navigator.of(context)
          .pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) =>
          const LoginScreen(),
        ),
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
            content: Text(
              'Çıkış işlemi tamamlanamadı.',
            ),
            behavior:
            SnackBarBehavior.floating,
          ),
        );
    }
  }

  String _initials() {
    final parts = widget.fullName
        .trim()
        .split(
      RegExp(r'\s+'),
    )
        .where(
          (part) => part.isNotEmpty,
    )
        .toList();

    if (parts.isEmpty) {
      return 'VI';
    }

    if (parts.length == 1) {
      return parts.first
          .substring(0, 1)
          .toUpperCase();
    }

    return (
        parts.first.substring(0, 1) +
            parts.last.substring(0, 1)
    ).toUpperCase();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final textTheme =
        Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profil',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(
              maxWidth:
              AppTheme.maxContentWidth,
            ),
            child: ListView(
              padding:
              AppTheme.pagePadding,
              children: [
                AppCard(
                  showShadow: false,
                  padding:
                  const EdgeInsets.all(
                    24,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration:
                        BoxDecoration(
                          gradient:
                          const LinearGradient(
                            colors: [
                              AppTheme
                                  .primaryColor,
                              AppTheme
                                  .secondaryColor,
                            ],
                            begin:
                            Alignment.topLeft,
                            end:
                            Alignment.bottomRight,
                          ),
                          borderRadius:
                          BorderRadius.circular(
                            30,
                          ),
                        ),
                        alignment:
                        Alignment.center,
                        child: Text(
                          _initials(),
                          style:
                          textTheme
                              .headlineMedium
                              ?.copyWith(
                            color:
                            Colors.white,
                            fontWeight:
                            FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 18,
                      ),
                      Text(
                        widget.fullName,
                        textAlign:
                        TextAlign.center,
                        style:
                        textTheme
                            .headlineSmall
                            ?.copyWith(
                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),
                      const SizedBox(
                        height: 6,
                      ),
                      Text(
                        widget.email,
                        textAlign:
                        TextAlign.center,
                        style:
                        textTheme
                            .bodyLarge
                            ?.copyWith(
                          color:
                          colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment:
                        WrapAlignment.center,
                        children: [
                          AppStatusBadge(
                            label:
                            _roleLabel,
                            color:
                            colorScheme
                                .primary,
                            backgroundColor:
                            colorScheme
                                .primaryContainer,
                            icon:
                            Icons
                                .verified_user_outlined,
                          ),
                          AppStatusBadge(
                            label:
                            _subscriptionPlanLabel,
                            color:
                            _subscriptionColor(),
                            backgroundColor:
                            _subscriptionBackgroundColor(),
                            icon:
                            Icons
                                .workspace_premium_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                AppCard(
                  showShadow: false,
                  padding:
                  EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ProfileItem(
                        icon:
                        Icons
                            .person_outline_rounded,
                        title:
                        'Ad Soyad',
                        value:
                        widget.fullName,
                      ),
                      const Divider(
                        height: 1,
                        indent: 82,
                      ),
                      _ProfileItem(
                        icon:
                        Icons
                            .mail_outline_rounded,
                        title:
                        'E-posta',
                        value:
                        widget.email,
                      ),
                      const Divider(
                        height: 1,
                        indent: 82,
                      ),
                      _ProfileItem(
                        icon:
                        Icons
                            .verified_user_outlined,
                        title:
                        'Hesap Türü',
                        value:
                        _roleLabel,
                      ),
                      const Divider(
                        height: 1,
                        indent: 82,
                      ),
                      _ProfileItem(
                        icon:
                        Icons
                            .workspace_premium_outlined,
                        title:
                        'Abonelik Planı',
                        value:
                        _subscriptionPlanLabel,
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                AppCard(
                  showShadow: false,
                  backgroundColor:
                  colorScheme
                      .surfaceContainerLow,
                  child: Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const AppIconBox(
                        icon:
                        Icons
                            .info_outline_rounded,
                        size: 42,
                        iconSize: 21,
                        borderRadius: 14,
                        backgroundColor:
                        AppTheme.infoSoft,
                        iconColor:
                        AppTheme.infoColor,
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vehicle Inspector',
                              style:
                              textTheme
                                  .titleSmall
                                  ?.copyWith(
                                fontWeight:
                                FontWeight.w900,
                              ),
                            ),
                            const SizedBox(
                              height: 4,
                            ),
                            Text(
                              'Araç hasarlarını yapay zekâ destekli görüntü analizi ile inceleyin.',
                              style:
                              textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color:
                                colorScheme
                                    .onSurfaceVariant,
                                height:
                                1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 24,
                ),
                SizedBox(
                  width: double.infinity,
                  child:
                  OutlinedButton.icon(
                    onPressed:
                    _isLoggingOut
                        ? null
                        : _logout,
                    icon:
                    _isLoggingOut
                        ? SizedBox(
                      width: 18,
                      height: 18,
                      child:
                      CircularProgressIndicator(
                        strokeWidth:
                        2,
                        color:
                        colorScheme
                            .error,
                      ),
                    )
                        : const Icon(
                      Icons
                          .logout_rounded,
                    ),
                    label: Text(
                      _isLoggingOut
                          ? 'Çıkış yapılıyor...'
                          : 'Çıkış Yap',
                    ),
                    style:
                    OutlinedButton
                        .styleFrom(
                      foregroundColor:
                      colorScheme.error,
                      side:
                      BorderSide(
                        color:
                        colorScheme
                            .error
                            .withValues(
                          alpha: 0.55,
                        ),
                      ),
                      minimumSize:
                      const Size(
                        double.infinity,
                        52,
                      ),
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

class _ProfileItem
    extends StatelessWidget {
  const _ProfileItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(
      BuildContext context,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final textTheme =
        Theme.of(context).textTheme;

    return Padding(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),
      child: Row(
        children: [
          AppIconBox(
            icon: icon,
            size: 46,
            iconSize: 22,
            borderRadius: 14,
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                  textTheme.bodySmall
                      ?.copyWith(
                    color:
                    colorScheme
                        .onSurfaceVariant,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  value,
                  style:
                  textTheme.bodyLarge
                      ?.copyWith(
                    fontWeight:
                    FontWeight.w800,
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