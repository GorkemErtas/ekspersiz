class AiAssistantEntitlement {
  const AiAssistantEntitlement({
    required this.status,
    required this.canAsk,
    required this.dailyLimit,
    required this.usedToday,
    required this.remainingToday,
    required this.outOfScopeAttempts,
  });

  final String status;
  final bool canAsk;
  final int dailyLimit;
  final int usedToday;
  final int remainingToday;
  final int outOfScopeAttempts;

  factory AiAssistantEntitlement.fromJson(Map<String, dynamic> json) =>
      AiAssistantEntitlement(
        status: json['status'] as String? ?? 'UNKNOWN',
        canAsk: json['canAsk'] as bool? ?? false,
        dailyLimit: json['dailyLimit'] as int? ?? 0,
        usedToday: json['usedToday'] as int? ?? 0,
        remainingToday: json['remainingToday'] as int? ?? 0,
        outOfScopeAttempts: json['outOfScopeAttempts'] as int? ?? 0,
      );
}

class AiAssistantReply {
  const AiAssistantReply({
    required this.intent,
    required this.answer,
    required this.quotaConsumed,
    required this.remainingToday,
    required this.toolsUsed,
  });

  final String intent;
  final String answer;
  final bool quotaConsumed;
  final int remainingToday;
  final List<String> toolsUsed;

  factory AiAssistantReply.fromJson(Map<String, dynamic> json) =>
      AiAssistantReply(
        intent: json['intent'] as String? ?? 'UNKNOWN',
        answer: json['answer'] as String? ?? '',
        quotaConsumed: json['quotaConsumed'] as bool? ?? false,
        remainingToday: json['remainingToday'] as int? ?? 0,
        toolsUsed: (json['toolsUsed'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );
}

class AiChatMessage {
  const AiChatMessage({required this.text, required this.isUser});
  final String text;
  final bool isUser;
}
