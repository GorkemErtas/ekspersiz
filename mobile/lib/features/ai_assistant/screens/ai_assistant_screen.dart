import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../models/ai_assistant_models.dart';
import '../services/ai_assistant_service.dart';
import '../../vehicle/models/vehicle.dart';
import '../../vehicle/services/vehicle_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key, this.initialVehicle});

  final Vehicle? initialVehicle;

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _service = AiAssistantService();
  final _speech = stt.SpeechToText();
  bool _listening = false;
  String _speechPrefix = '';
  final _vehicleService = const VehicleService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<AiChatMessage> _messages = [];

  AiAssistantEntitlement? _entitlement;
  List<Vehicle> _vehicles = const [];
  Vehicle? _selectedVehicle;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _retryQuestion;

  @override
  void initState() {
    super.initState();
    _selectedVehicle = widget.initialVehicle;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadEntitlement(), _loadVehicles()]);
  }

  Future<void> _loadVehicles() async {
    try {
      final vehicles = await _vehicleService.getVehicles();
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        if (_selectedVehicle == null && vehicles.isNotEmpty) {
          _selectedVehicle = vehicles.firstWhere(
            (vehicle) => vehicle.primaryVehicle,
            orElse: () => vehicles.first,
          );
        }
      });
    } catch (_) {
      // Vehicle context is optional for general automotive questions.
    }
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

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (_sending || !(_entitlement?.canAsk ?? false)) return;
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _listening = false);
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            _error = 'Ses tanıma tamamlanamadı. Tekrar deneyin.';
          });
        },
      );
      if (!mounted) return;
      if (!available) {
        setState(() => _error = 'Konuşma tanıma kullanılamıyor. Mikrofon iznini ve cihaz ayarlarını kontrol edin.');
        return;
      }
      _speechPrefix = _controller.text.trimRight();
      setState(() {
        _listening = true;
        _error = null;
      });
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: 'tr_TR',
          partialResults: true,
        ),
        onResult: (result) {
          if (!mounted) return;
          final prefix = _speechPrefix.isEmpty ? '' : '$_speechPrefix ';
          _controller.value = TextEditingValue(
            text: '$prefix${result.recognizedWords}',
            selection: TextSelection.collapsed(offset: ('$prefix${result.recognizedWords}').length),
          );
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _listening = false;
          _error = 'Mikrofon başlatılamadı. Lütfen tekrar deneyin.';
        });
      }
    }
  }

  Future<void> _send() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
    }
    final question = _controller.text.trim();
    if (question.isEmpty || _sending || !(_entitlement?.canAsk ?? false)) return;

    final history = List<AiChatMessage>.from(_messages);
    setState(() {
      _messages.add(AiChatMessage(text: question, isUser: true));
      _controller.clear();
      _sending = true;
      _error = null;
      _retryQuestion = null;
    });
    _scrollToBottom();

    try {
      final reply = await _service.ask(
        question,
        vehicleId: _selectedVehicle?.id,
        history: history,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(AiChatMessage(text: reply.answer, isUser: false, sources: reply.sources));
        final current = _entitlement;
        if (current != null) {
          _entitlement = AiAssistantEntitlement(
            status: current.status,
            canAsk: current.canAsk && reply.remainingToday > 0,
            dailyLimit: current.dailyLimit,
            usedToday: reply.quotaConsumed
                ? current.usedToday + 1
                : current.usedToday,
            remainingToday: reply.remainingToday,
            outOfScopeAttempts: current.outOfScopeAttempts,
            trialExpiresAt: current.trialExpiresAt,
            lockedUntil: current.lockedUntil,
          );
        }
        _sending = false;
      });
      _scrollToBottom();
      // The server is the source of truth for the active plan and shared quota.
      // Refresh after every answer, including quota-consuming answers.
      await _refreshEntitlementSilently();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _retryQuestion = question;
        _sending = false;
      });
    }
  }

  Future<void> _refreshEntitlementSilently() async {
    try {
      final entitlement = await _service.entitlement();
      if (!mounted) return;
      setState(() => _entitlement = entitlement);
    } catch (_) {
      // The answer is already available; a status refresh failure is non-fatal.
    }
  }

  Future<void> _retryLastQuestion() async {
    final question = _retryQuestion;
    if (question == null || _sending || !(_entitlement?.canAsk ?? false)) return;
    if (_messages.isNotEmpty &&
        _messages.last.isUser &&
        _messages.last.text == question) {
      setState(() => _messages.removeLast());
    }
    _controller.text = question;
    await _send();
  }

  String _accessMessage(AiAssistantEntitlement entitlement) {
    return switch (entitlement.status) {
      'INACTIVE' => 'AI Asistanı kullanmak için ücretsiz denemeyi başlatın.',
      'LOCKED' => 'Çok sayıda kapsam dışı istek nedeniyle AI Asistan geçici olarak kilitlendi.',
      'EXPIRED' => 'AI Asistan deneme süreniz sona erdi.',
      _ when entitlement.remainingToday <= 0 =>
        'Bugünkü ${entitlement.dailyLimit} soru hakkınızı kullandınız. Yeni günlük haklarınız yarın yenilenir.',
      _ => 'Aracınız, bakım, muayene, güvenlik veya EksperSiz hakkında bir şey sorun.',
    };
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
    _speech.cancel();
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
                  if (_vehicles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: DropdownButtonFormField<int>(
                        initialValue: _selectedVehicle?.id,
                        decoration: const InputDecoration(
                          labelText: 'Araç bağlamı',
                          prefixIcon: Icon(Icons.directions_car_outlined),
                        ),
                        items: _vehicles
                            .map(
                              (vehicle) => DropdownMenuItem<int>(
                                value: vehicle.id,
                                child: Text(
                                  '${vehicle.displayName} • ${vehicle.modelYear}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _sending
                            ? null
                            : (id) {
                                setState(() {
                                  _selectedVehicle = _vehicles.firstWhere(
                                    (vehicle) => vehicle.id == id,
                                  );
                                });
                              },
                      ),
                    ),
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: scheme.error),
                            ),
                          ),
                          if (_retryQuestion != null)
                            TextButton.icon(
                              onPressed: _retryLastQuestion,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Tekrar dene'),
                            ),
                        ],
                      ),
                    ),
                  if (_entitlement != null && _entitlement!.status == 'INACTIVE')
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                        onPressed: _startTrial,
                        child: const Text('7 günlük ücretsiz denemeyi başlat'),
                      ),
                    ),
                  Expanded(
                    child: _messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Text(
                                _entitlement == null
                                    ? 'AI Asistan hazırlanıyor.'
                                    : _accessMessage(_entitlement!),
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
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        message.text,
                                        style: TextStyle(
                                          color: message.isUser
                                              ? scheme.onPrimary
                                              : scheme.onSurface,
                                        ),
                                      ),
                                      if (!message.isUser && message.sources.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: message.sources
                                              .map(
                                                (source) => Chip(
                                                  avatar: const Icon(
                                                    Icons.verified_outlined,
                                                    size: 16,
                                                  ),
                                                  label: Text(
                                                    source.name,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                              )
                                              .toList(growable: false),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (_sending)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, 4, 24, 6),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    ),
                  if (_listening)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Dinleniyor… Durdurmak için mikrofona dokunun.'),
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
                        IconButton(
                          tooltip: _listening ? 'Dinlemeyi durdur' : 'Sesle yaz',
                          onPressed: _sending || !(_entitlement?.canAsk ?? false)
                              ? null
                              : _toggleListening,
                          icon: Icon(_listening ? Icons.mic_rounded : Icons.mic_none_rounded),
                          color: _listening ? scheme.error : scheme.primary,
                        ),
                        const SizedBox(width: 4),
                        IconButton.filled(
                          onPressed: _sending || !(_entitlement?.canAsk ?? false)
                              ? null
                              : _send,
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
