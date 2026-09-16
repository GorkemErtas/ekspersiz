import 'package:flutter/material.dart';
import 'dart:async';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreSession();
    });
  }

  Future<void> _restoreSession() async {
    debugPrint('SPLASH: restore session started');

    final hasToken = await TokenStorage.hasAccessToken();

    debugPrint('SPLASH: hasToken = $hasToken');

    if (!mounted) {
      return;
    }

    if (!hasToken) {
      debugPrint('SPLASH: going to login');
      _goToLogin();
      return;
    }

    try {
      debugPrint('SPLASH: requesting current user');

      final user = await _authService.getCurrentUser().timeout(
        const Duration(seconds: 10),
      );

      debugPrint('SPLASH: current user loaded');

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MainShell(
            fullName: user.fullName,
            email: user.email,
            subscriptionPlan: user.subscriptionPlan,
            businessAccount: user.businessAccount,
          ),
        ),
      );
    } on TimeoutException {
      debugPrint('SPLASH: current user timeout');

      if (!mounted) {
        return;
      }

      _showSessionRestoreError(
        'Sunucuya ulaşılamadı. Lütfen bağlantınızı kontrol edin.',
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
    } catch (exception, stackTrace) {
      debugPrint('SPLASH ERROR: $exception');
      debugPrintStack(stackTrace: stackTrace);

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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/images/ekspersiz_logo.png',
                      width: 112,
                      height: 112,
                      fit: BoxFit.cover,
                      cacheWidth: 256,
                      cacheHeight: 256,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('LOGO ERROR: $error');

                        return Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            color: const Color(0xFF17121F),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: const Icon(
                            Icons.directions_car_filled_rounded,
                            size: 52,
                            color: Color(0xFF8B5CF6),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 26),

                  Text(
                    'EksperSiz',
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
