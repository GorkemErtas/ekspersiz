import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/ads/ad_service.dart';
import '../../../core/network/api_client.dart';
import '../models/analysis_quota.dart';

enum RewardedAnalysisResult { verified, cancelled, verificationTimedOut }

typedef RewardedAdPresenter =
    Future<bool> Function({required String userId, required String customData});

class RewardedAnalysisService {
  const RewardedAnalysisService({
    this.apiClient = const ApiClient(),
    this.adPresenter,
    this.pollInterval = const Duration(seconds: 1),
    this.maxPollAttempts = 30,
    this.delay,
  });

  final ApiClient apiClient;
  final RewardedAdPresenter? adPresenter;
  final Duration pollInterval;
  final int maxPollAttempts;
  final Future<void> Function(Duration duration)? delay;

  Future<AnalysisQuota> getQuota() async {
    final response = await apiClient.get('/rewards/analysis');
    return AnalysisQuota.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<RewardedAnalysisResult> watchRewardedAd({
    void Function()? onVerificationStarted,
  }) async {
    final response = await apiClient.post(
      '/rewards/analysis/session',
      body: const {},
    );
    final data = Map<String, dynamic>.from(response as Map);
    final customData = data['customData'] as String;
    final userId = data['userId'] as String;
    final tokenId = _shortId(customData);
    debugPrint('Reward session created: tokenId=$tokenId');
    final earned = await (adPresenter ?? AdService.showRewarded)(
      userId: userId,
      customData: customData,
    );
    debugPrint(
      'Reward client callback completed: tokenId=$tokenId earned=$earned',
    );
    if (!earned) return RewardedAnalysisResult.cancelled;

    onVerificationStarted?.call();
    for (var attempt = 1; attempt <= maxPollAttempts; attempt++) {
      try {
        final quota = await getQuota();
        debugPrint(
          'Reward state refresh: tokenId=$tokenId attempt=$attempt '
          'claimed=${quota.rewardedClaimed} remaining=${quota.remaining}',
        );
        if (quota.rewardedClaimed && quota.remaining > 0) {
          return RewardedAnalysisResult.verified;
        }
      } catch (exception) {
        debugPrint(
          'Reward state refresh failed: tokenId=$tokenId '
          'attempt=$attempt error=${exception.runtimeType}',
        );
      }
      if (attempt < maxPollAttempts) {
        await (delay ?? Future<void>.delayed)(pollInterval);
      }
    }
    return RewardedAnalysisResult.verificationTimedOut;
  }

  static String _shortId(String value) =>
      value.substring(0, value.length < 8 ? value.length : 8);
}
