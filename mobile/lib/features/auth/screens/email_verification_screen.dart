import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon_box.dart';
import '../../../core/widgets/auth_shell.dart';
import '../../../core/widgets/primary_button.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key, required this.email});

  final String email;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final AuthService _authService = const AuthService();

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyEmail() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      await _authService.verifyEmail(
        email: widget.email,
        code: _codeController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'E-posta adresiniz doğrulandı. Şimdi giriş yapabilirsiniz.',
            ),
          ),
        );
    } catch (exception) {
      if (!mounted) {
        return;
      }

      final message = exception.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    if (_isResending || _isVerifying) {
      return;
    }

    setState(() {
      _isResending = true;
    });

    try {
      await _authService.resendVerificationCode(email: widget.email);

      if (!mounted) {
        return;
      }

      _codeController.clear();

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Yeni doğrulama kodu e-posta adresinize gönderildi.'),
          ),
        );
    } catch (exception) {
      if (!mounted) {
        return;
      }

      final message = exception.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  String? _validateCode(String? value) {
    final code = value?.trim() ?? '';

    if (code.isEmpty) {
      return 'Doğrulama kodunu girin.';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      return 'Doğrulama kodu 6 haneli olmalıdır.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isBusy = _isVerifying || _isResending;

    return AuthShell(
      maxWidth: 520,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppIconBox(
                  icon: Icons.mark_email_read_outlined,
                  size: 54,
                  iconSize: 27,
                  borderRadius: 18,
                  iconColor: Colors.white,
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  showShadow: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'E-postanı doğrula',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Vehicle Inspector hesabını aktifleştir',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              'Doğrulama kodunu gir',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.email} adresine gönderdiğimiz 6 haneli kodu girin.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _codeController,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.center,
              maxLength: 6,
              enabled: !isBusy,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onFieldSubmitted: (_) {
                if (!isBusy) {
                  _verifyEmail();
                }
              },
              decoration: const InputDecoration(
                labelText: 'Doğrulama Kodu',
                hintText: '123456',
                prefixIcon: Icon(Icons.password_rounded),
                counterText: '',
              ),
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
              validator: _validateCode,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 19,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Doğrulama kodu 5 dakika boyunca geçerlidir.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'E-postayı Doğrula',
              icon: Icons.verified_rounded,
              isLoading: _isVerifying,
              onPressed: isBusy ? null : _verifyEmail,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : _resendCode,
                icon: _isResending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(
                  _isResending ? 'Kod gönderiliyor...' : 'Kodu Tekrar Gönder',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: isBusy
                    ? null
                    : () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute<void>(
                            builder: (_) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Giriş ekranına dön'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
