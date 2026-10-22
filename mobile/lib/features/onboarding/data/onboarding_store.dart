import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Installation state, deliberately separate from credentials and account data.
/// The mobile directory is excluded from backup and removed on uninstall.
class OnboardingStore {
  const OnboardingStore({this.directoryProvider = _installationDirectory});

  final Future<Directory> Function() directoryProvider;

  static const _channel = MethodChannel('ekspersiz/installation');
  // Keep this name and value stable across app and guide content updates.
  static const _fileName = 'onboarding_completed';
  static const _completed = 'completed';

  static Future<Directory> _installationDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final path = await _channel.invokeMethod<String>('directory');
      if (path == null || path.isEmpty) {
        throw const FileSystemException('Installation directory unavailable');
      }
      return Directory(path);
    }
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/installation');
  }

  Future<bool> hasCompleted() async {
    try {
      final directory = await directoryProvider();
      final file = File('${directory.path}/$_fileName');
      return await file.exists() && await file.readAsString() == _completed;
    } catch (_) {
      // An unavailable or damaged marker must not strand the splash screen.
      debugPrint('Onboarding preference could not be read.');
      return false;
    }
  }

  Future<void> complete() async {
    final directory = await directoryProvider();
    await directory.create(recursive: true);
    final file = File('${directory.path}/$_fileName');
    final pending = File('${file.path}.pending');
    await pending.writeAsString(_completed, flush: true);
    // An interrupted write is not completion. Rename within the same directory.
    await pending.rename(file.path);
  }
}
