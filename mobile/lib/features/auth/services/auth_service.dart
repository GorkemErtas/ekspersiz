import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../models/auth_response.dart';
import '../models/user_profile.dart';

class AuthService {
  const AuthService({this.apiClient = const ApiClient()});

  final ApiClient apiClient;

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

      await TokenStorage.saveAccessToken(authResponse.accessToken);

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

  Future<UserProfile> getCurrentUser() async {
    final response = await apiClient.get('/auth/me');

    if (response is! Map) {
      throw const FormatException('Kullanıcı bilgileri alınamadı.');
    }

    return UserProfile.fromJson(Map<String, dynamic>.from(response));
  }

  Future<void> logout() async {
    await TokenStorage.deleteAccessToken();
  }
}
