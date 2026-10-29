// Native reference entrypoint. Auth references remain offline. REFERENCE_FIXTURES
// explicitly enables the isolated localhost visual fixture transport, never production.
// Run from mobile/: flutter run --no-pub -t ../mobile-rn/visual/flutter_native_reference.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/widgets/app_background.dart';
import 'package:mobile/features/auth/screens/login_screen.dart';
import 'package:mobile/features/auth/screens/register_screen.dart';
import 'package:mobile/features/auth/screens/forgot_password_screen.dart';
import 'package:mobile/features/auth/screens/email_verification_screen.dart';
import 'package:mobile/core/storage/token_storage.dart';
import 'package:mobile/core/constants/api_constants.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/home/screens/main_shell.dart';
import 'package:mobile/features/vehicle/screens/vehicle_list_screen.dart';
import 'package:mobile/features/inspection/screens/inspection_history_screen.dart';
import 'package:mobile/features/inspection/screens/inspection_result_screen.dart';
import 'package:mobile/features/inspection/models/damage_inspection.dart';
import 'package:mobile/features/profile/screens/profile_screen.dart';
import 'package:mobile/features/onboarding/screens/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  const screen = String.fromEnvironment(
    'REFERENCE_SCREEN',
    defaultValue: 'login',
  );
  const light = String.fromEnvironment('REFERENCE_THEME') == 'light';
  const fixture=bool.fromEnvironment('REFERENCE_FIXTURES');
  DamageInspection? inspection;
  if(fixture){
    final base=Uri.parse(ApiConstants.baseUrl);
    if(base.host!='127.0.0.1'||base.port!=18080)throw StateError('Visual references require the isolated localhost fixture server.');
    await TokenStorage.saveAccessToken('visual-only-token');
    await const AuthService().getCurrentUser();
    final response=await http.get(Uri.parse('${ApiConstants.baseUrl}/inspections/1'),headers:{'Authorization':'Bearer visual-only-token','X-Workspace':'PERSONAL'});
    inspection=DamageInspection.fromJson(jsonDecode(response.body) as Map<String,dynamic>);
  }
  Widget reference(String route)=>switch(route.replaceFirst('/','')){
    'main'=>const MainShell(userId:7,fullName:'Deniz Yılmaz',email:'deniz@example.com',subscriptionPlan:'FREE'),
    'vehicles'=>const VehicleListScreen(),
    'history'=>const InspectionHistoryScreen(),
    'profile'=>const ProfileScreen(fullName:'Deniz Yılmaz',email:'deniz@example.com',subscriptionPlan:'FREE'),
    'result'=>InspectionResultScreen(inspection:inspection!),
    'guide'=>const OnboardingScreen.replay(),
    _=>const LoginScreen(),
  };
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EksperSiz Flutter Reference',
      theme:fixture?AppTheme.lightTheme:light ? AppTheme.lightTheme : AppTheme.darkTheme,
      darkTheme:fixture?AppTheme.darkTheme:null,
      themeMode:fixture?ThemeMode.system:ThemeMode.light,
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => AppBackground(child: child!),
      initialRoute:fixture?ui.PlatformDispatcher.instance.defaultRouteName:null,
      onGenerateInitialRoutes:fixture?(name)=>[MaterialPageRoute<void>(settings:RouteSettings(name:name),builder:(_)=>reference(name))]:null,
      onGenerateRoute:fixture?(settings)=>MaterialPageRoute<void>(settings:settings,builder:(_)=>reference(settings.name??'main')):null,
      home:fixture?null:switch (screen) {
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
