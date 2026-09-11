import 'package:flutter/material.dart';

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

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
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
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Çıkış Yap'),
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
      await _authService.logout();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(),
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
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final textTheme =
        Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1100,
              ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            32,
          ),
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor:
                colorScheme.primaryContainer,
                child: Text(
                  _initials(),
                  style: textTheme
                      .headlineMedium
                      ?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            Text(
              widget.fullName,
              textAlign: TextAlign.center,
              style:
              textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              widget.email,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color:
                colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 30),

            _ProfileItem(
              icon: Icons.person_outline_rounded,
              title: 'Ad Soyad',
              value: widget.fullName,
            ),

            const SizedBox(height: 12),

            _ProfileItem(
              icon: Icons.mail_outline_rounded,
              title: 'E-posta',
              value: widget.email,
            ),

            const SizedBox(height: 12),

            _ProfileItem(
              icon:
              Icons.verified_user_outlined,
              title: 'Hesap Türü',
              value: _roleLabel,
            ),

            const SizedBox(height: 12),

            _ProfileItem(
              icon: Icons.workspace_premium_outlined,
              title: 'Abonelik Planı',
              value: _subscriptionPlanLabel,
            ),

            const SizedBox(height: 32),

            OutlinedButton.icon(
              onPressed:
              _isLoggingOut ? null : _logout,
              icon: _isLoggingOut
                  ? const SizedBox(
                width: 18,
                height: 18,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(
                Icons.logout_rounded,
              ),
              label: Text(
                _isLoggingOut
                    ? 'Çıkış yapılıyor...'
                    : 'Çıkış Yap',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                colorScheme.error,
                side: BorderSide(
                  color: colorScheme.error,
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
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
        colorScheme.surfaceContainerLow,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color:
              colorScheme.primaryContainer,
              borderRadius:
              BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
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