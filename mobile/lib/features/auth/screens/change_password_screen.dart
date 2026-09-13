import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';

import '../services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final AuthService _authService = const AuthService();

  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        confirmNewPassword: _confirmNewPasswordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (exception) {
      if (!mounted) {
        return;
      }

      final message = exception.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validateCurrentPassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Mevcut şifrenizi girin.';
    }

    return null;
  }

  String? _validateNewPassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Yeni şifrenizi girin.';
    }

    if (password.length < 8 || password.length > 72) {
      return 'Şifre 8 ile 72 karakter arasında olmalıdır.';
    }

    if (password == _currentPasswordController.text) {
      return 'Yeni şifre mevcut şifreden farklı olmalıdır.';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Yeni şifrenizi tekrar girin.';
    }

    if (password != _newPasswordController.text) {
      return 'Yeni şifreler eşleşmiyor.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Şifre Değiştir')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: AppTheme.pagePadding,
              children: [
                AppCard(
                  showShadow: false,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hesap güvenliği',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Şifrenizi değiştirmek için önce mevcut '
                          'şifrenizi doğrulayın.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _currentPasswordController,
                          obscureText: _obscureCurrentPassword,
                          enabled: !_isLoading,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Mevcut Şifre',
                            hintText: 'Mevcut şifrenizi girin',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _obscureCurrentPassword
                                  ? 'Şifreyi göster'
                                  : 'Şifreyi gizle',
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _obscureCurrentPassword =
                                            !_obscureCurrentPassword;
                                      });
                                    },
                              icon: Icon(
                                _obscureCurrentPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: _validateCurrentPassword,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: _obscureNewPassword,
                          enabled: !_isLoading,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: 'Yeni Şifre',
                            hintText: 'En az 8 karakter',
                            prefixIcon: const Icon(Icons.password_rounded),
                            suffixIcon: IconButton(
                              tooltip: _obscureNewPassword
                                  ? 'Şifreyi göster'
                                  : 'Şifreyi gizle',
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
                          validator: _validateNewPassword,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmNewPasswordController,
                          obscureText: _obscureConfirmPassword,
                          enabled: !_isLoading,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!_isLoading) {
                              _changePassword();
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Yeni Şifre Tekrar',
                            hintText: 'Yeni şifrenizi tekrar girin',
                            prefixIcon: const Icon(Icons.lock_reset_rounded),
                            suffixIcon: IconButton(
                              tooltip: _obscureConfirmPassword
                                  ? 'Şifreyi göster'
                                  : 'Şifreyi gizle',
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
                          validator: _validateConfirmPassword,
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 19,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Yeni şifreniz 8 ile 72 karakter '
                                  'arasında olmalı ve mevcut '
                                  'şifrenizden farklı olmalıdır.',
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
                          label: 'Şifreyi Güncelle',
                          icon: Icons.security_update_good_rounded,
                          isLoading: _isLoading,
                          onPressed: _isLoading ? null : _changePassword,
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
    );
  }
}
