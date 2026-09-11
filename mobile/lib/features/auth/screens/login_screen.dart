import 'package:flutter/material.dart';

import '../../../core/widgets/auth_shell.dart';
import '../../home/screens/main_shell.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
  });

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService =
  const AuthService();

  final _formKey =
  GlobalKey<FormState>();

  final _emailController =
  TextEditingController();

  final _passwordController =
  TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authResponse =
      await _authService.login(
        email:
        _emailController.text
            .trim()
            .toLowerCase(),
        password:
        _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              MainShell(
                fullName:
                authResponse.fullName,
                email:
                authResponse.email,
                role:
                authResponse.role,
                subscriptionPlan:
                authResponse
                    .subscriptionPlan,
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
            content:
            Text(message),
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

  String? _validateEmail(
      String? value,
      ) {
    final email =
        value?.trim() ?? '';

    if (email.isEmpty) {
      return 'E-posta adresinizi girin.';
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
    if (value == null ||
        value.isEmpty) {
      return 'Şifrenizi girin.';
    }

    return null;
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return AuthShell(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'Tekrar hoş geldiniz',
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
              'Hesabınıza giriş yaparak araç '
                  'analizlerinize devam edin.',
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
              TextInputAction.done,
              autofillHints: const [
                AutofillHints.password,
              ],
              onFieldSubmitted: (_) {
                if (!_isLoading) {
                  _login();
                }
              },
              decoration:
              InputDecoration(
                labelText:
                'Şifre',
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
              height: 24,
            ),

            FilledButton.icon(
              onPressed:
              _isLoading
                  ? null
                  : _login,
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
                    .login_rounded,
              ),
              label: Text(
                _isLoading
                    ? 'Giriş yapılıyor...'
                    : 'Giriş Yap',
              ),
            ),

            const SizedBox(
              height: 22,
            ),

            Row(
              children: [
                const Expanded(
                  child:
                  Divider(),
                ),

                Padding(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 12,
                  ),
                  child: Text(
                    'veya',
                    style:
                    Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                ),

                const Expanded(
                  child:
                  Divider(),
                ),
              ],
            ),

            const SizedBox(
              height: 22,
            ),

            OutlinedButton.icon(
              onPressed:
              _isLoading
                  ? null
                  : () {
                Navigator.of(
                  context,
                ).push(
                  MaterialPageRoute<
                      void>(
                    builder: (_) =>
                    const RegisterScreen(),
                  ),
                );
              },
              icon:
              const Icon(
                Icons
                    .person_add_alt_1_rounded,
              ),
              label:
              const Text(
                'Yeni Hesap Oluştur',
              ),
            ),
          ],
        ),
      ),
    );
  }
}