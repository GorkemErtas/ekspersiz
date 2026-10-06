import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../models/ai_assistant_models.dart';
import '../services/ai_assistant_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _service = AiAssistantService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<AiChatMessage> _messages = [];

  AiAssistantEntitlement? _entitlement;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntitlement();
  }

  Future<void> _loadEntitlement() async {
    try {
      final entitlement = await _service.entitlement();
      if (!mounted) return;
      setState(() {
        _entitlement = entitlement;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _startTrial() async {
    setState(() => _loading = true);
    try {
      final entitlement = await _service.startTrial();
      if (!mounted) return;
      setState(() {
        _entitlement = entitlement;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _sending || !(_entitlement?.canAsk ?? false)) return;

    setState(() {
      _messages.add(AiChatMessage(text: question, isUser: true));
      _controller.clear();
      _sending = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final reply = await _service.ask(question);
      if (!mounted) return;
      setState(() {
        _messages.add(AiChatMessage(text: reply.answer, isUser: false));
        final current = _entitlement;
        if (current != null) {
          _entitlement = AiAssistantEntitlement(
            status: current.status,
            canAsk: reply.remainingToday > 0,
            dailyLimit: current.dailyLimit,
            usedToday: current.dailyLimit - reply.remainingToday,
            remainingToday: reply.remainingToday,
            outOfScopeAttempts: current.outOfScopeAttempts,
          );
        }
        _sending = false;
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _sending = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI Asistan')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_entitlement != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      ),
                      child: Text(
                        'Bugün kalan soru hakkı: ${_entitlement!.remainingToday}/${_entitlement!.dailyLimit}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_error!, style: TextStyle(color: scheme.error)),
                    ),
                  if (_entitlement != null && !_entitlement!.canAsk && _entitlement!.status != 'ACTIVE')
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                        onPressed: _startTrial,
                        child: const Text('30 günlük ücretsiz denemeyi başlat'),
                      ),
                    ),
                  Expanded(
                    child: _messages.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: Text(
                                'Aracınız, bakım, muayene, güvenlik veya EksperSiz hakkında bir şey sorun.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              return Align(
                                alignment: message.isUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 620),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: message.isUser
                                        ? scheme.primary
                                        : scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Text(
                                    message.text,
                                    style: TextStyle(
                                      color: message.isUser
                                          ? scheme.onPrimary
                                          : scheme.onSurface,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (_sending)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: LinearProgressIndicator(),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            enabled: !_sending && (_entitlement?.canAsk ?? false),
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 2000,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: const InputDecoration(
                              hintText: 'Aracınız hakkında sorun...',
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sending ? null : _send,
                          icon: const Icon(Icons.arrow_upward_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
