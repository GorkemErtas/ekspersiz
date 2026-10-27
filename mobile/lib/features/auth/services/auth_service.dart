import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/workspace/workspace_session.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../models/auth_response.dart';
import '../models/user_profile.dart';
import '../../billing/services/welcome_credit_service.dart';

class AuthService {
  const AuthService({this.apiClient = const ApiClient()});

  final ApiClient apiClient;
  static int _profileRequest = 0;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await apiClient.post(
        '/auth/login',
        includeAuth: false,
        clearTokenOnUnauthorized: false,
        body: {'email': email.trim().toLowerCase(), 'password': password},
      );

      if (response is! Map) {
        throw const FormatException('Sunucudan geçersiz giriş yanıtı alındı.');
      }

      final authResponse = AuthResponse.fromJson(
        Map<String, dynamic>.from(response),
      );

      if (authResponse.accessToken.trim().isEmpty) {
        throw const FormatException(
          'Sunucudan geçerli bir erişim anahtarı alınamadı.',
        );
      }

      WorkspaceSession.clear();
      await TokenStorage.saveAccessToken(authResponse.accessToken);
      await WorkspaceSession.initialize(
        userId: authResponse.userId,
        businessId: authResponse.businessAccount?.id,
        companyName: authResponse.businessAccount?.companyName,
        role: authResponse.businessAccount?.role,
        subscriptionPlan: authResponse.subscriptionPlan,
        businessAvailable:
            authResponse.businessAccount?.workspaceAvailable == true,
        businessAccessStatus:
            authResponse.businessAccount?.workspaceAccessStatus ?? 'UNKNOWN',
        businessSandbox: authResponse.businessAccount?.sandbox ?? false,
      );
      try {
        await WelcomeCreditService.claim().timeout(const Duration(seconds: 15));
      } catch (_) {
        /* Login and paid access remain available. */
      }

      return authResponse;
    } on ApiException catch (exception) {
      if (exception.statusCode == 401) {
        throw ApiException(
          statusCode: 401,
          message: 'E-posta veya şifre hatalı.',
        );
      }

      rethrow;
    }
  }

  Future<AuthResponse> loginWithGoogle() async {
    const googleServerClientId = String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
    );

    if (googleServerClientId.isEmpty) {
      throw const FormatException('Google Sign-In yapılandırması bulunamadı.');
    }

    final googleSignIn = GoogleSignIn.instance;

    await googleSignIn.initialize(serverClientId: googleServerClientId);

    final GoogleSignInAccount account = await googleSignIn.authenticate();

    final GoogleSignInAuthentication authentication = account.authentication;

    final String? idToken = authentication.idToken;

    if (idToken == null || idToken.trim().isEmpty) {
      throw const FormatException('Google kimlik doğrulama tokenı alınamadı.');
    }

    final response = await apiClient.post(
      '/auth/google',
      includeAuth: false,
      clearTokenOnUnauthorized: false,
      body: {'idToken': idToken},
    );

    if (response is! Map) {
      throw const FormatException(
        'Sunucudan geçersiz Google giriş yanıtı alındı.',
      );
    }

    final authResponse = AuthResponse.fromJson(
      Map<String, dynamic>.from(response),
    );

    if (authResponse.accessToken.trim().isEmpty) {
      throw const FormatException(
        'Sunucudan geçerli bir erişim anahtarı alınamadı.',
      );
    }

    WorkspaceSession.clear();
    await TokenStorage.saveAccessToken(authResponse.accessToken);
    await WorkspaceSession.initialize(
      userId: authResponse.userId,
      businessId: authResponse.businessAccount?.id,
      companyName: authResponse.businessAccount?.companyName,
      role: authResponse.businessAccount?.role,
      subscriptionPlan: authResponse.subscriptionPlan,
      businessAvailable:
          authResponse.businessAccount?.workspaceAvailable == true,
      businessAccessStatus:
          authResponse.businessAccount?.workspaceAccessStatus ?? 'UNKNOWN',
      businessSandbox: authResponse.businessAccount?.sandbox ?? false,
    );
    try {
      await WelcomeCreditService.claim().timeout(const Duration(seconds: 15));
    } catch (_) {
      /* Retry from the purchase center. */
    }

    return authResponse;
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await apiClient.post(
      '/auth/register',
      includeAuth: false,
      clearTokenOnUnauthorized: false,
      body: {
        'fullName': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    await apiClient.post(
      '/auth/verify-email',
      includeAuth: false,
      clearTokenOnUnauthorized: false,
      body: {'email': email.trim().toLowerCase(), 'code': code.trim()},
    );
  }

  Future<void> resendVerificationCode({required String email}) async {
    await apiClient.post(
      '/auth/resend-verification',
      includeAuth: false,
      clearTokenOnUnauthorized: false,
      body: {'email': email.trim().toLowerCase()},
    );
  }

  Future<void> forgotPassword({required String email}) async {
    await apiClient.post(
      '/auth/forgot-password',
      includeAuth: false,
      clearTokenOnUnauthorized: false,
      body: {'email': email.trim().toLowerCase()},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    await apiClient.post(
      '/auth/reset-password',
      includeAuth: false,
      clearTokenOnUnauthorized: false,
      body: {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
        'newPassword': newPassword,
        'confirmNewPassword': confirmNewPassword,
      },
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    await apiClient.post(
      '/auth/change-password',
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmNewPassword': confirmNewPassword,
      },
    );
  }

  Future<UserProfile> getCurrentUser() async {
    final request = ++_profileRequest;
    final workspace = WorkspaceSession.capture();
    final scope = SessionManager.imageScope.value;
    final response = await apiClient.get('/auth/me');

    if (response is! Map) {
      throw const FormatException('Kullanıcı bilgileri alınamadı.');
    }

    final user = UserProfile.fromJson(Map<String, dynamic>.from(response));
    WorkspaceSession.check(workspace);
    if (request != _profileRequest) {
      throw const ApiException(
        statusCode: 409,
        message: 'Daha güncel profil bilgisi alındı.',
      );
    }
    if (identical(scope, SessionManager.imageScope.value)) {
      SessionManager.updateImageUserScope(
        user.id,
        user.businessAccount?.id,
        user.businessAccount?.role,
      );
    }
    await WorkspaceSession.initialize(
      userId: user.id,
      businessId: user.businessAccount?.id,
      companyName: user.businessAccount?.companyName,
      role: user.businessAccount?.role,
      subscriptionPlan: user.subscriptionPlan,
      businessAvailable: user.businessAccount?.workspaceAvailable == true,
      businessAccessStatus:
          user.businessAccount?.workspaceAccessStatus ?? 'UNKNOWN',
      businessSandbox: user.businessAccount?.sandbox ?? false,
    );
    return user;
  }

  Future<void> deleteAccount() async {
    await apiClient.delete('/auth/account');
    await TokenStorage.deleteAccessToken();
  }

  Future<void> logout() async {
    await TokenStorage.deleteAccessToken();
  }
}
