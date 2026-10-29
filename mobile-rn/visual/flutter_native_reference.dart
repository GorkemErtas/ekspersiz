// Offline native reference entrypoint. No Firebase/session bootstrap, API calls,
// or fake backend implementation. It renders the real Flutter auth screens.
// Run from mobile/: flutter run --no-pub -t ../mobile-rn/visual/flutter_native_reference.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/widgets/app_background.dart';
import 'package:mobile/features/auth/screens/login_screen.dart';
import 'package:mobile/features/auth/screens/register_screen.dart';
import 'package:mobile/features/auth/screens/forgot_password_screen.dart';
import 'package:mobile/features/auth/screens/email_verification_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  const screen = String.fromEnvironment(
    'REFERENCE_SCREEN',
    defaultValue: 'login',
  );
  const light = String.fromEnvironment('REFERENCE_THEME') == 'light';
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EksperSiz Flutter Reference',
      theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => AppBackground(child: child!),
      home: switch (screen) {
        'register' => const RegisterScreen(),
        'forgot-password' => const ForgotPasswordScreen(),
        'verify-email' => const EmailVerificationScreen(
          email: 'deniz@example.com',
        ),
        _ => const LoginScreen(),
      },
    ),
  );
}
