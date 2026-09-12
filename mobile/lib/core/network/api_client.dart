import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../constants/api_constants.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';
import '../auth/session_manager.dart';

class ApiClient {
  const ApiClient();

  static const Duration _requestTimeout = Duration(
    seconds: 30,
  );

  static const Duration _analysisTimeout = Duration(
    seconds: 90,
  );

  Future<dynamic> get(
      String path,
      ) async {
    try {
      final response = await http
          .get(
        _buildUri(path),
        headers: await _buildHeaders(),
      )
          .timeout(_requestTimeout);

      return await _handleResponse(response);
    } on TimeoutException {
      throw ApiException(
        statusCode: 408,
        message:
        'Sunucu yanıt vermedi. Lütfen tekrar deneyin.',
      );
    } on http.ClientException {
      throw ApiException(
        statusCode: 0,
        message:
        'Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.',
      );
    }
  }

  Future<dynamic> post(
      String path, {
        Map<String, dynamic>? body,
        Duration? timeout,
        bool includeAuth = true,
        bool clearTokenOnUnauthorized = true,
      }) async {
    try {
      final response = await http
          .post(
        _buildUri(path),
        headers: await _buildHeaders(
          includeAuth: includeAuth,
        ),
        body: body == null
            ? null
            : jsonEncode(body),
      )
          .timeout(
        timeout ?? _requestTimeout,
      );

      return await _handleResponse(
        response,
        clearTokenOnUnauthorized:
        clearTokenOnUnauthorized,
      );
    } on TimeoutException {
      throw ApiException(
        statusCode: 408,
        message:
        'Sunucu yanıt vermedi. Lütfen tekrar deneyin.',
      );
    } on http.ClientException {
      throw ApiException(
        statusCode: 0,
        message:
        'Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.',
      );
    }
  }

  Future<dynamic> postMultipart(
      String path, {
        required List<int> fileBytes,
        required String filename,
        String fileFieldName = 'image',
        String contentType = 'image/jpeg',
      }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        _buildUri(path),
      );

      final token =
      await TokenStorage.getAccessToken();

      request.headers.addAll({
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      });

      final mediaType = _parseMediaType(
        contentType,
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          fileFieldName,
          fileBytes,
          filename: filename,
          contentType: mediaType,
        ),
      );

      final streamedResponse = await request
          .send()
          .timeout(_analysisTimeout);

      final response = await http.Response
          .fromStream(streamedResponse)
          .timeout(_requestTimeout);

      return await _handleResponse(response);
    } on TimeoutException {
      throw ApiException(
        statusCode: 408,
        message:
        'İşlem zaman aşımına uğradı. Lütfen tekrar deneyin.',
      );
    } on http.ClientException {
      throw ApiException(
        statusCode: 0,
        message:
        'Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.',
      );
    }
  }

  Future<dynamic> put(
      String path, {
        required Map<String, dynamic> body,
      }) async {
    try {
      final response = await http
          .put(
        _buildUri(path),
        headers: await _buildHeaders(),
        body: jsonEncode(body),
      )
          .timeout(_requestTimeout);

      return await _handleResponse(response);
    } on TimeoutException {
      throw ApiException(
        statusCode: 408,
        message:
        'Sunucu yanıt vermedi. Lütfen tekrar deneyin.',
      );
    } on http.ClientException {
      throw ApiException(
        statusCode: 0,
        message:
        'Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.',
      );
    }
  }

  Future<void> delete(
      String path,
      ) async {
    try {
      final response = await http
          .delete(
        _buildUri(path),
        headers: await _buildHeaders(),
      )
          .timeout(_requestTimeout);

      await _handleResponse(response);
    } on TimeoutException {
      throw ApiException(
        statusCode: 408,
        message:
        'Sunucu yanıt vermedi. Lütfen tekrar deneyin.',
      );
    } on http.ClientException {
      throw ApiException(
        statusCode: 0,
        message:
        'Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.',
      );
    }
  }

  Uri _buildUri(
      String path,
      ) {
    final normalizedPath = path.startsWith('/')
        ? path
        : '/$path';

    return Uri.parse(
      '${ApiConstants.baseUrl}$normalizedPath',
    );
  }

  Future<Map<String, String>> _buildHeaders({
    bool includeAuth = true,
  }) async {
    String? token;

    if (includeAuth) {
      token = await TokenStorage.getAccessToken();
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (includeAuth &&
          token != null &&
          token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  MediaType _parseMediaType(
      String contentType,
      ) {
    final parts = contentType.split('/');

    if (parts.length != 2 ||
        parts.first.isEmpty ||
        parts.last.isEmpty) {
      return MediaType(
        'application',
        'octet-stream',
      );
    }

    return MediaType(
      parts.first,
      parts.last,
    );
  }

  Future<dynamic> _handleResponse(
      http.Response response, {
        bool clearTokenOnUnauthorized = true,
      }) async {
    final hasBody =
        response.bodyBytes.isNotEmpty;

    dynamic decodedBody;

    if (hasBody) {
      try {
        decodedBody = jsonDecode(
          utf8.decode(
            response.bodyBytes,
          ),
        );
      } catch (_) {
        decodedBody = null;
      }
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return decodedBody;
    }

    if (response.statusCode == 401 &&
        clearTokenOnUnauthorized) {
      await TokenStorage.deleteAccessToken();

      SessionManager.notifyUnauthorized();
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: _extractErrorMessage(
        response.statusCode,
        decodedBody,
      ),
    );
  }

  String _extractErrorMessage(
      int statusCode,
      dynamic body,
      ) {
    if (body is Map<String, dynamic>) {
      final message =
          body['message'] ??
              body['detail'] ??
              body['error'];

      if (message is String &&
          message.trim().isNotEmpty) {
        return message;
      }
    }

    return switch (statusCode) {
      400 => 'Gönderilen bilgiler geçersiz.',
      401 => 'Oturumunuz sona erdi. Lütfen tekrar giriş yapın.',
      403 => 'Bu işlem için yetkiniz bulunmuyor.',
      404 => 'İstenen kayıt bulunamadı.',
      408 => 'İstek zaman aşımına uğradı.',
      409 => 'Bu kayıt zaten mevcut.',
      413 => 'Seçilen dosya çok büyük.',
      415 => 'Bu dosya türü desteklenmiyor.',
      500 => 'Sunucuda beklenmeyen bir hata oluştu.',
      502 => 'AI analiz servisine şu anda ulaşılamıyor.',
      503 => 'Servis geçici olarak kullanılamıyor.',
      _ => 'Sunucu işlemi tamamlayamadı.',
    };
  }
}