import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon_box.dart';
import '../../../core/widgets/auth_shell.dart';
import '../../../core/widgets/primary_button.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _authService = const AuthService();

  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();

    if (!(_emailFormKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.forgotPassword(
        email: _emailController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _codeSent = true;
      });

      _showMessage(
        'Bu e-posta ile kayıtlı bir hesap varsa '
            'şifre sıfırlama kodu gönderildi.',
      );
    } catch (exception) {
      if (!mounted) {
        return;
      }

      _showMessage(
        exception.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();

    if (!(_resetFormKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_newPasswordController.text !=
        _confirmPasswordController.text) {
      _showMessage('Yeni şifreler eşleşmiyor.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.resetPassword(
        email: _emailController.text,
        code: _codeController.text,
        newPassword: _newPasswordController.text,
        confirmNewPassword: _confirmPasswordController.text,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Şifreniz başarıyla değiştirildi. Yeni şifrenizle giriş yapabilirsiniz.',
      );

      Navigator.of(context).pop();
    } catch (exception) {
      if (!mounted) {
        return;
      }

      _showMessage(
        exception.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: AppText(message),
        ),
      );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'E-posta adresinizi girin.';
    }

    final emailRegex =
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailRegex.hasMatch(email)) {
      return 'Geçerli bir e-posta adresi girin.';
    }

    return null;
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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Yeni şifrenizi girin.';
    }

    if (value.length < 8) {
      return 'Şifre en az 8 karakter olmalıdır.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AuthShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconBox(
                icon: Icons.lock_reset_rounded,
                size: 54,
                iconSize: 27,
                borderRadius: 18,
                iconColor: Colors.white,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.secondaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                showShadow: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AppText(
                  'Şifremi Unuttum',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AppText(
            _codeSent
                ? 'E-postanıza gönderilen kodu girerek yeni şifrenizi belirleyin.'
                : 'Hesabınıza ait e-posta adresini girin. Size bir şifre sıfırlama kodu göndereceğiz.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          if (!_codeSent)
            Form(
              key: _emailFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [
                      AutofillHints.email,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      hintText: 'ornek@email.com',
                      prefixIcon:
                      Icon(Icons.mail_outline_rounded),
                    ),
                    validator: _validateEmail,
                    onFieldSubmitted: (_) {
                      if (!_isLoading) {
                        _sendCode();
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Kod Gönder',
                    icon: Icons.send_rounded,
                    isLoading: _isLoading,
                    onPressed:
                    _isLoading ? null : _sendCode,
                  ),
                ],
              ),
            )
          else
            Form(
              key: _resetFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Doğrulama Kodu',
                      hintText: '6 haneli kod',
                      prefixIcon:
                      Icon(Icons.pin_outlined),
                      counterText: '',
                    ),
                    validator: _validateCode,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Yeni Şifre',
                      prefixIcon:
                      const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                          setState(() {
                            _obscureNewPassword =
                            !_obscureNewPassword;
                          });
                        },
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Yeni Şifre Tekrar',
                      prefixIcon:
                      const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                          setState(() {
                            _obscureConfirmPassword =
                            !_obscureConfirmPassword;
                          });
                        },
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final passwordError =
                      _validatePassword(value);

                      if (passwordError != null) {
                        return passwordError;
                      }

                      if (value !=
                          _newPasswordController.text) {
                        return 'Yeni şifreler eşleşmiyor.';
                      }

                      return null;
                    },
                    onFieldSubmitted: (_) {
                      if (!_isLoading) {
                        _resetPassword();
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Şifreyi Değiştir',
                    icon: Icons.lock_reset_rounded,
                    isLoading: _isLoading,
                    onPressed:
                    _isLoading ? null : _resetPassword,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                      setState(() {
                        _codeSent = false;
                        _codeController.clear();
                        _newPasswordController.clear();
                        _confirmPasswordController.clear();
                      });
                    },
                    child: const AppText(
                      'E-posta adresini değiştir',
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const AppText('Giriş ekranına dön'),
            ),
          ),
        ],
      ),
    );
  }
}