class AiAssistantEntitlement {
  const AiAssistantEntitlement({
    required this.status,
    required this.canAsk,
    required this.dailyLimit,
    required this.usedToday,
    required this.remainingToday,
    required this.outOfScopeAttempts,
    this.trialExpiresAt,
    this.lockedUntil,
  });

  final String status;
  final bool canAsk;
  final int dailyLimit;
  final int usedToday;
  final int remainingToday;
  final int outOfScopeAttempts;
  final DateTime? trialExpiresAt;
  final DateTime? lockedUntil;

  factory AiAssistantEntitlement.fromJson(Map<String, dynamic> json) =>
      AiAssistantEntitlement(
        status: json['status'] as String? ?? 'UNKNOWN',
        canAsk: json['canAsk'] as bool? ?? false,
        dailyLimit: json['dailyLimit'] as int? ?? 0,
        usedToday: json['usedToday'] as int? ?? 0,
        remainingToday: json['remainingToday'] as int? ?? 0,
        outOfScopeAttempts: json['outOfScopeAttemptsToday'] as int? ?? 0,
        trialExpiresAt: DateTime.tryParse(json['trialExpiresAt'] as String? ?? ''),
        lockedUntil: DateTime.tryParse(json['lockedUntil'] as String? ?? ''),
      );
}

class AiAssistantReply {
  const AiAssistantReply({
    required this.intent,
    required this.answer,
    required this.quotaConsumed,
    required this.remainingToday,
    required this.toolsUsed,
    required this.sources,
  });

  final String intent;
  final String answer;
  final bool quotaConsumed;
  final int remainingToday;
  final List<String> toolsUsed;
  final List<AiAssistantSource> sources;

  factory AiAssistantReply.fromJson(Map<String, dynamic> json) =>
      AiAssistantReply(
        intent: json['intent'] as String? ?? 'UNKNOWN',
        answer: json['answer'] as String? ?? '',
        quotaConsumed: json['quotaConsumed'] as bool? ?? false,
        remainingToday: json['remainingToday'] as int? ?? 0,
        toolsUsed: (json['toolsUsed'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        sources: (json['sources'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => AiAssistantSource.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
      );
}

class AiAssistantSource {
  const AiAssistantSource({required this.name, this.url});
  final String name;
  final String? url;

  factory AiAssistantSource.fromJson(Map<String, dynamic> json) =>
      AiAssistantSource(name: json['name'] as String? ?? 'Kaynak', url: json['url'] as String?);
}

class AiChatMessage {
  const AiChatMessage({required this.text, required this.isUser, this.sources = const []});
  final String text;
  final bool isUser;
  final List<AiAssistantSource> sources;
}
