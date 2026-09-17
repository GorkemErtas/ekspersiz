import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/billing/services/rewarded_analysis_service.dart';

void main() {
  test('polls until SSV-backed quota is available', () async {
    final api = _FakeApiClient([
      _quota(claimed: false, remaining: 0),
      _quota(claimed: true, remaining: 1),
    ]);
    var adCalls = 0;
    var verificationStarted = false;
    var delays = 0;
    final service = RewardedAnalysisService(
      apiClient: api,
      maxPollAttempts: 3,
      pollInterval: Duration.zero,
      adPresenter: ({required userId, required customData}) async {
        adCalls++;
        expect(userId, 'server-user-id');
        expect(customData, 'server-session-token');
        return true;
      },
      delay: (_) async => delays++,
    );

    final result = await service.watchRewardedAd(
      onVerificationStarted: () => verificationStarted = true,
    );

    expect(result, RewardedAnalysisResult.verified);
    expect(verificationStarted, isTrue);
    expect(adCalls, 1);
    expect(api.sessionCalls, 1);
    expect(api.quotaCalls, 2);
    expect(delays, 1);
  });

  test(
    'does not poll or grant when client reward callback is absent',
    () async {
      final api = _FakeApiClient([]);
      final service = RewardedAnalysisService(
        apiClient: api,
        adPresenter: ({required userId, required customData}) async => false,
      );

      final result = await service.watchRewardedAd();

      expect(result, RewardedAnalysisResult.cancelled);
      expect(api.quotaCalls, 0);
    },
  );
}

Map<String, dynamic> _quota({required bool claimed, required int remaining}) =>
    {
      'plan': 'FREE',
      'used': 1,
      'baseLimit': 1,
      'rewardedClaimed': claimed,
      'rewardedEligible': !claimed,
      'totalLimit': claimed ? 2 : 1,
      'remaining': remaining,
    };

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.quotas);

  final List<Map<String, dynamic>> quotas;
  int sessionCalls = 0;
  int quotaCalls = 0;

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
    bool includeAuth = true,
    bool clearTokenOnUnauthorized = true,
  }) async {
    sessionCalls++;
    return {'userId': 'server-user-id', 'customData': 'server-session-token'};
  }

  @override
  Future<dynamic> get(String path) async {
    final response = quotas[quotaCalls];
    quotaCalls++;
    return response;
  }
}
