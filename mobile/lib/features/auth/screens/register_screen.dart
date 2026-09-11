import 'package:flutter/material.dart';

import '../../../core/widgets/auth_shell.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
  });

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController =
  TextEditingController();

  final _emailController =
  TextEditingController();

  final _passwordController =
  TextEditingController();

  final _passwordConfirmController =
  TextEditingController();

  final AuthService _authService =
  const AuthService();

  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();

    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.register(
        fullName: _fullNameController.text.trim(),
        email:
        _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Hesabınız oluşturuldu. Şimdi giriş yapabilirsiniz.',
            ),
          ),
        );
    } catch (exception) {
      if (!mounted) {
        return;
      }

      final message = exception
          .toString()
          .replaceFirst(
        'Exception: ',
        '',
      );

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validateFullName(
      String? value,
      ) {
    final fullName =
        value?.trim() ?? '';

    if (fullName.isEmpty) {
      return 'Ad soyad boş bırakılamaz.';
    }

    if (fullName.length < 2) {
      return 'Ad soyad en az 2 karakter olmalıdır.';
    }

    if (fullName.length > 100) {
      return 'Ad soyad en fazla 100 karakter olabilir.';
    }

    return null;
  }

  String? _validateEmail(
      String? value,
      ) {
    final email =
        value?.trim() ?? '';

    if (email.isEmpty) {
      return 'E-posta adresinizi girin.';
    }

    if (email.length > 150) {
      return 'E-posta en fazla 150 karakter olabilir.';
    }

    final emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailRegex.hasMatch(email)) {
      return 'Geçerli bir e-posta adresi girin.';
    }

    return null;
  }

  String? _validatePassword(
      String? value,
      ) {
    final password =
        value ?? '';

    if (password.isEmpty) {
      return 'Şifre boş bırakılamaz.';
    }

    if (password.length < 8) {
      return 'Şifre en az 8 karakter olmalıdır.';
    }

    if (password.length > 72) {
      return 'Şifre en fazla 72 karakter olabilir.';
    }

    return null;
  }

  String? _validatePasswordConfirm(
      String? value,
      ) {
    if (value == null ||
        value.isEmpty) {
      return 'Şifrenizi tekrar girin.';
    }

    if (value !=
        _passwordController.text) {
      return 'Şifreler eşleşmiyor.';
    }

    return null;
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return AuthShell(
      maxWidth: 520,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'Hesabını oluştur',
              style:
              Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                fontWeight:
                FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              'Araçlarını kaydet ve AI destekli '
                  'hasar analizlerini tek yerden yönet.',
              style:
              Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),

            const SizedBox(
              height: 28,
            ),

            TextFormField(
              controller:
              _fullNameController,
              textInputAction:
              TextInputAction.next,
              textCapitalization:
              TextCapitalization.words,
              autofillHints: const [
                AutofillHints.name,
              ],
              decoration:
              const InputDecoration(
                labelText:
                'Ad Soyad',
                hintText:
                'Adınız Soyadınız',
                prefixIcon:
                Icon(
                  Icons
                      .person_outline_rounded,
                ),
              ),
              validator:
              _validateFullName,
            ),

            const SizedBox(
              height: 16,
            ),

            TextFormField(
              controller:
              _emailController,
              keyboardType:
              TextInputType.emailAddress,
              textInputAction:
              TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [
                AutofillHints.email,
              ],
              decoration:
              const InputDecoration(
                labelText:
                'E-posta',
                hintText:
                'ornek@email.com',
                prefixIcon:
                Icon(
                  Icons
                      .mail_outline_rounded,
                ),
              ),
              validator:
              _validateEmail,
            ),

            const SizedBox(
              height: 16,
            ),

            TextFormField(
              controller:
              _passwordController,
              obscureText:
              _obscurePassword,
              textInputAction:
              TextInputAction.next,
              autofillHints: const [
                AutofillHints.newPassword,
              ],
              decoration:
              InputDecoration(
                labelText:
                'Şifre',
                hintText:
                'En az 8 karakter',
                prefixIcon:
                const Icon(
                  Icons
                      .lock_outline_rounded,
                ),
                suffixIcon:
                IconButton(
                  tooltip:
                  _obscurePassword
                      ? 'Şifreyi göster'
                      : 'Şifreyi gizle',
                  onPressed: () {
                    setState(() {
                      _obscurePassword =
                      !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons
                        .visibility_outlined
                        : Icons
                        .visibility_off_outlined,
                  ),
                ),
              ),
              validator:
              _validatePassword,
            ),

            const SizedBox(
              height: 16,
            ),

            TextFormField(
              controller:
              _passwordConfirmController,
              obscureText:
              _obscurePasswordConfirm,
              textInputAction:
              TextInputAction.done,
              onFieldSubmitted: (_) {
                if (!_isLoading) {
                  _register();
                }
              },
              decoration:
              InputDecoration(
                labelText:
                'Şifre Tekrar',
                hintText:
                'Şifrenizi tekrar girin',
                prefixIcon:
                const Icon(
                  Icons
                      .lock_reset_rounded,
                ),
                suffixIcon:
                IconButton(
                  tooltip:
                  _obscurePasswordConfirm
                      ? 'Şifreyi göster'
                      : 'Şifreyi gizle',
                  onPressed: () {
                    setState(() {
                      _obscurePasswordConfirm =
                      !_obscurePasswordConfirm;
                    });
                  },
                  icon: Icon(
                    _obscurePasswordConfirm
                        ? Icons
                        .visibility_outlined
                        : Icons
                        .visibility_off_outlined,
                  ),
                ),
              ),
              validator:
              _validatePasswordConfirm,
            ),

            const SizedBox(
              height: 24,
            ),

            FilledButton.icon(
              onPressed:
              _isLoading
                  ? null
                  : _register,
              icon:
              _isLoading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                  Colors.white,
                ),
              )
                  : const Icon(
                Icons
                    .person_add_alt_1_rounded,
              ),
              label: Text(
                _isLoading
                    ? 'Hesap oluşturuluyor...'
                    : 'Hesap Oluştur',
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed:
                _isLoading
                    ? null
                    : () {
                  Navigator.of(
                    context,
                  ).pop();
                },
                child:
                const Text(
                  'Zaten hesabınız var mı? Giriş yapın',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}