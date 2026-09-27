import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/api_constants.dart';

class AppUpdateService {
  const AppUpdateService();

  static const Duration _timeout = Duration(seconds: 5);
  static final Uri _storeUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.gorkem.ekspersiz',
  );

  Future<bool> isUpdateRequired() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber);

      if (currentBuild == null) {
        return false;
      }

      final response = await http
          .get(
            Uri.parse('${ApiConstants.baseUrl}/app/version'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final body = jsonDecode(utf8.decode(response.bodyBytes));

      if (body is! Map<String, dynamic>) {
        return false;
      }

      final minimumBuild = body['minimumAndroidBuild'];

      if (minimumBuild is! num) {
        return false;
      }

      return currentBuild < minimumBuild.toInt();
    } catch (_) {
      // Version checks must fail open so a temporary network/backend problem
      // never locks users out of the application.
      return false;
    }
  }

  Future<void> openStore() async {
    await launchUrl(_storeUri, mode: LaunchMode.externalApplication);
  }
}
