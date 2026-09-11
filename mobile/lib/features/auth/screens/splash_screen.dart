import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_theme.dart';

import '../../home/screens/main_shell.dart';
import '../services/auth_service.dart';

import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
  });

  @override
  State<SplashScreen> createState() =>
      _SplashScreenState();
}

class _SplashScreenState
    extends State<SplashScreen> {
  final AuthService _authService =
  const AuthService();

  @override
  void initState() {
    super.initState();

    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final hasToken =
    await TokenStorage.hasAccessToken();

    if (!mounted) {
      return;
    }

    if (!hasToken) {
      _goToLogin();
      return;
    }

    try {
      final user =
      await _authService
          .getCurrentUser();

      if (!mounted) {
        return;
      }

      Navigator.of(context)
          .pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              MainShell(
                fullName:
                user.fullName,
                email:
                user.email,
                role:
                user.role,
                subscriptionPlan:
                user.subscriptionPlan,
              ),
        ),
      );
    } on ApiException catch (exception) {
      if (exception.statusCode == 401 ||
          exception.statusCode == 403) {
        await TokenStorage
            .deleteAccessToken();

        if (!mounted) {
          return;
        }

        _goToLogin();
        return;
      }

      if (!mounted) {
        return;
      }

      _showSessionRestoreError(
        exception.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSessionRestoreError(
        'Oturum bilgileri kontrol edilemedi.',
      );
    }
  }

  void _goToLogin() {
    if (!mounted) {
      return;
    }

    Navigator.of(context)
        .pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
        const LoginScreen(),
      ),
    );
  }

  void _showSessionRestoreError(
      String message,
      ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (
          dialogContext,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Bağlantı Hatası',
          ),
          content:
          Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();

                _restoreSession();
              },
              child:
              const Text(
                'Tekrar Dene',
              ),
            ),

            TextButton(
              onPressed: () async {
                Navigator.of(
                  dialogContext,
                ).pop();

                await TokenStorage
                    .deleteAccessToken();

                if (!mounted) {
                  return;
                }

                _goToLogin();
              },
              child:
              const Text(
                'Giriş Yap',
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
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
                    Alignment
                        .topLeft,
                    end:
                    Alignment
                        .bottomRight,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    26,
                  ),
                  boxShadow:
                  AppTheme
                      .primaryShadow,
                ),
                child:
                const Icon(
                  Icons
                      .car_crash_rounded,
                  color:
                  Colors.white,
                  size: 40,
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              Text(
                'Vehicle Inspector',
                style:
                Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                'AI destekli araç hasar analizi',
                textAlign:
                TextAlign.center,
                style:
                Theme.of(context)
                    .textTheme
                    .bodyMedium,
              ),

              const SizedBox(
                height: 32,
              ),

              const SizedBox(
                width: 26,
                height: 26,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}