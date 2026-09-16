import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

class AdService {
  AdService._();

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  static Future<bool> showRewarded({
    required String userId,
    required String customData,
  }) async {
    final adUnitId = AdConfig.rewardedAdUnitId;
    if (adUnitId.isEmpty) return false;
    final loaded = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => loaded.complete(ad),
        onAdFailedToLoad: (_) => loaded.complete(null),
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
        if (!finished.isCompleted) finished.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!finished.isCompleted) finished.complete(false);
      },
    );
    ad.show(onUserEarnedReward: (_, _) => earned = true);
    return finished.future;
  }
}
