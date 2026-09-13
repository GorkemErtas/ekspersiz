import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon_box.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import '../../home/screens/main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = const AuthService();

  @override
  void initState() {
    super.initState();

    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final hasToken = await TokenStorage.hasAccessToken();

    if (!mounted) {
      return;
    }

    if (!hasToken) {
      _goToLogin();
      return;
    }

    try {
      final user = await _authService.getCurrentUser();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MainShell(
            fullName: user.fullName,
            email: user.email,
            role: user.role,
            subscriptionPlan: user.subscriptionPlan,
          ),
        ),
      );
    } on ApiException catch (exception) {
      if (exception.statusCode == 401 || exception.statusCode == 403) {
        await TokenStorage.deleteAccessToken();

        if (!mounted) {
          return;
        }

        _goToLogin();
        return;
      }

      if (!mounted) {
        return;
      }

      _showSessionRestoreError(exception.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSessionRestoreError('Oturum bilgileri kontrol edilemedi.');
    }
  }

  void _goToLogin() {
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  void _showSessionRestoreError(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Bağlantı Hatası'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();

                _restoreSession();
              },
              child: const Text('Tekrar Dene'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                await TokenStorage.deleteAccessToken();

                if (!mounted) {
                  return;
                }

                _goToLogin();
              },
              child: const Text('Giriş Yap'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIconBox(
                    icon: Icons.car_crash_rounded,
                    size: 88,
                    iconSize: 42,
                    borderRadius: 28,
                    iconColor: Colors.white,
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    showShadow: true,
                  ),

                  const SizedBox(height: 26),

                  Text(
                    'Vehicle Inspector',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'AI destekli araç hasar analizi',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: colorScheme.primary,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Oturum kontrol ediliyor...',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
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
