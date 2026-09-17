import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

import 'ad_config.dart';

class AdService {
  AdService._();

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    final testDeviceIds = AdConfig.testDeviceIds;
    if (testDeviceIds.isNotEmpty) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: testDeviceIds),
      );
      debugPrint(
        'AdMob test device configuration applied: count=${testDeviceIds.length}',
      );
    }
  }

  static Future<bool> showRewarded({
    required String userId,
    required String customData,
  }) async {
    final adUnitId = AdConfig.rewardedAdUnitId;
    if (adUnitId.isEmpty) {
      debugPrint('Rewarded ad unavailable: ad unit id is empty.');
      return false;
    }
    debugPrint('Rewarded ad load requested: tokenId=${_shortId(customData)}');
    final loaded = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('Rewarded ad loaded: tokenId=${_shortId(customData)}');
          loaded.complete(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint(
            'Rewarded ad load failed: tokenId=${_shortId(customData)} '
            'code=${error.code}',
          );
          loaded.complete(null);
        },
      ),
    );
    final ad = await loaded.future;
    if (ad == null) return false;
    await ad.setServerSideOptions(
      ServerSideVerificationOptions(userId: userId, customData: customData),
    );

    final finished = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        debugPrint(
          'Rewarded ad dismissed: tokenId=${_shortId(customData)} earned=$earned',
        );
        if (!finished.isCompleted) finished.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        debugPrint('Rewarded ad show failed: tokenId=${_shortId(customData)}');
        if (!finished.isCompleted) finished.complete(false);
      },
    );
    ad.show(
      onUserEarnedReward: (_, reward) {
        earned = true;
        debugPrint(
          'Reward client callback received: tokenId=${_shortId(customData)} '
          'type=${reward.type}',
        );
      },
    );
    return finished.future;
  }

  static String _shortId(String value) =>
      value.substring(0, value.length < 8 ? value.length : 8);
}
