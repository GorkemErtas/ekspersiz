import 'dart:io';

class AdConfig {
  AdConfig._();

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return const String.fromEnvironment(
        'ADMOB_BANNER_ANDROID_ID',
        defaultValue: 'ca-app-pub-3940256099942544/6300978111',
      );
    }
    if (Platform.isIOS) {
      return const String.fromEnvironment(
        'ADMOB_BANNER_IOS_ID',
        defaultValue: 'ca-app-pub-3940256099942544/2934735716',
      );
    }
    return '';
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return const String.fromEnvironment(
        'ADMOB_REWARDED_ANDROID_ID',
        defaultValue: 'ca-app-pub-3940256099942544/5224354917',
      );
    }
    if (Platform.isIOS) {
      return const String.fromEnvironment(
        'ADMOB_REWARDED_IOS_ID',
        defaultValue: 'ca-app-pub-3940256099942544/1712485313',
      );
    }
    return '';
  }
}
