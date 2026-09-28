import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/api_constants.dart';

class AppUpdateStatus {
  const AppUpdateStatus({
    required this.updateRequired,
    required this.playUpdateAvailable,
    required this.immediateUpdateAllowed,
  });

  final bool updateRequired;
  final bool playUpdateAvailable;
  final bool immediateUpdateAllowed;

  static const none = AppUpdateStatus(
    updateRequired: false,
    playUpdateAvailable: false,
    immediateUpdateAllowed: false,
  );
}

class AppUpdateService {
  const AppUpdateService();

  static const Duration _timeout = Duration(seconds: 5);
  static final Uri _storeUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.gorkem.ekspersiz',
  );

  Future<AppUpdateStatus> checkForUpdate() async {
    if (!Platform.isAndroid) {
      return AppUpdateStatus.none;
    }

    final backendRequiresUpdate = await _isBackendUpdateRequired();

    try {
      final info = await InAppUpdate.checkForUpdate().timeout(_timeout);
      final playUpdateAvailable =
          info.updateAvailability == UpdateAvailability.updateAvailable ||
          info.updateAvailability ==
              UpdateAvailability.developerTriggeredUpdateInProgress;

      return AppUpdateStatus(
        updateRequired: backendRequiresUpdate || playUpdateAvailable,
        playUpdateAvailable: playUpdateAvailable,
        immediateUpdateAllowed:
            playUpdateAvailable && info.immediateUpdateAllowed,
      );
    } catch (_) {
      // Google Play update checks only work for installs managed by Play.
      // Keep the backend policy as a fallback for sideloaded/test builds.
      return AppUpdateStatus(
        updateRequired: backendRequiresUpdate,
        playUpdateAvailable: false,
        immediateUpdateAllowed: false,
      );
    }
  }

  Future<bool> _isBackendUpdateRequired() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber);

      if (currentBuild == null) return false;

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
      if (body is! Map<String, dynamic>) return false;

      final minimumBuild = body['minimumAndroidBuild'];
      if (minimumBuild is! num) return false;

      return currentBuild < minimumBuild.toInt();
    } catch (_) {
      return false;
    }
  }

  Future<bool> performImmediateUpdate() async {
    try {
      final result = await InAppUpdate.performImmediateUpdate();
      return result == AppUpdateResult.success;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openStore() async {
    try {
      return await launchUrl(_storeUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
