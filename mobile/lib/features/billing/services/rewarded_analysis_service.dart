import 'dart:async';

import '../../../core/ads/ad_service.dart';
import '../../../core/network/api_client.dart';
import '../models/analysis_quota.dart';

class RewardedAnalysisService {
  const RewardedAnalysisService({this.apiClient = const ApiClient()});

  final ApiClient apiClient;

  Future<AnalysisQuota> getQuota() async {
    final response = await apiClient.get('/rewards/analysis');
    return AnalysisQuota.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<bool> watchRewardedAd() async {
    final response = await apiClient.post(
      '/rewards/analysis/session',
      body: const {},
    );
    final data = Map<String, dynamic>.from(response as Map);
    final earned = await AdService.showRewarded(
      userId: data['userId'] as String,
      customData: data['customData'] as String,
    );
    if (!earned) return false;

    for (var attempt = 0; attempt < 20; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final quota = await getQuota();
      if (quota.rewardedClaimed && quota.remaining > 0) return true;
    }
    return false;
  }
}
