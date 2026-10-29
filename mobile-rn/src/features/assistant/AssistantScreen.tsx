import { useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  KeyboardAvoidingView,
  Platform,
  TextInput,
  View,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { randomUUID } from 'expo-crypto';

import {
  ExpoSpeechRecognitionModule,
  useSpeechRecognitionEvent,
} from 'expo-speech-recognition';
import { api, session } from '../../core/runtime';
import { assistantEntitlement, vehicles } from '../../core/services';
import { invalidate, useResource } from '../../core/queries';
import type { ChatMessage } from '../../core/models';
import { positiveId } from '../../core/models';
import { AppText, Button, IconButton } from '../../design/components';
import { Page, Select, StateView } from '../../design/layout';
import { useTheme } from '../../design/ThemeProvider';
import { fonts } from '../../design/tokens';
import { AssistantService } from './AssistantService';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { MessageBubble } from './MessageBubble';

export default function AssistantScreen() {
  const router = useRouter(),
    { vehicle } = useLocalSearchParams<{ vehicle?: string }>(),
    { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const entitlement = useResource(
      'assistant/entitlement',
      assistantEntitlement,
    ),
    garage = useResource('vehicles', vehicles.list);
  const [selection, setSelection] = useState<string | undefined>(vehicle),
    [messages, setMessages] = useState<ChatMessage[]>([]),
    [text, setText] = useState(''),
    [sending, setSending] = useState(false),
    [listening, setListening] = useState(false),
    [error, setError] = useState('');
  const conversation = useRef(new AssistantService(api, session, randomUUID)),
    controller = useRef<AbortController | null>(null),
    pending = useRef<{
      question: string;
      vehicleId?: number;
      history: ChatMessage[];
    } | null>(null),
    prefix = useRef(''),
    speechScope = useRef<number | null>(null),
    alive = useRef(true),
    locked = useRef(false),
    list = useRef<FlatList<ChatMessage>>(null);
  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
      speechScope.current = null;
      controller.current?.abort();
      ExpoSpeechRecognitionModule.abort();
    };
  }, []);
  useSpeechRecognitionEvent('result', (event) => {
    if (
      alive.current &&
      speechScope.current === session.getSnapshot().generation
    )
      setText(`${prefix.current}${event.results[0]?.transcript ?? ''}`);
  });
  useSpeechRecognitionEvent('end', () => {
    speechScope.current = null;
    if (alive.current) setListening(false);
  });
  useSpeechRecognitionEvent('error', () => {
    speechScope.current = null;
    if (alive.current) {
      setListening(false);
      setError(
        'Ses tanıma tamamlanamadı. Mikrofon iznini ve cihaz ayarlarını kontrol edin.',
      );
    }
  });
  const toggleSpeech = async () => {
    if (listening) {
      ExpoSpeechRecognitionModule.stop();
      return;
    }
    try {
      const generation = session.getSnapshot().generation;
      if (!ExpoSpeechRecognitionModule.isRecognitionAvailable())
        throw new Error('Konuşma tanıma bu cihazda kullanılamıyor.');
      const permission =
        await ExpoSpeechRecognitionModule.requestPermissionsAsync();
      if (!permission.granted)
        throw new Error('Mikrofon ve konuşma tanıma izinlerini kontrol edin.');
      session.check(generation);
      if (!alive.current) return;
      speechScope.current = generation;
      prefix.current = text.trimEnd() ? `${text.trimEnd()} ` : '';
      setListening(true);
      ExpoSpeechRecognitionModule.start({
        lang: 'tr-TR',
        interimResults: true,
        continuous: false,
      });
    } catch (reason) {
      setError(
        reason instanceof Error ? reason.message : 'Mikrofon başlatılamadı.',
      );
    }
  };
  const chosen =
    selection ??
    String(
      garage.data?.find((v) => v.primaryVehicle)?.id ??
        garage.data?.[0]?.id ??
        '',
    );
  const send = async () => {
    const question = text.trim();
    if (!question || locked.current) return;
    if (listening) ExpoSpeechRecognitionModule.stop();
    const selected = chosen ? positiveId(chosen) : undefined;
    const retry =
      pending.current?.question === question &&
      pending.current.vehicleId === selected;
    if (!entitlement.data?.canAsk && !retry) {
      router.push('/billing');
      return;
    }
    const history = retry ? pending.current!.history : messages;
    pending.current = { question, vehicleId: selected, history };
    if (!retry)
      setMessages((current) => [
        ...current,
        { role: 'user', content: question },
      ]);
    locked.current = true;
    setSending(true);
    setText('');
    setError('');
    controller.current = new AbortController();
    try {
      const reply = await conversation.current.ask(
        question,
        selected,
        history,
        controller.current.signal,
      );
      if (!alive.current) return;
      setMessages((current) => [
        ...current,
        { role: 'assistant', content: reply.answer, sources: reply.sources },
      ]);
      pending.current = null;
      void invalidate('assistant/entitlement', 'credits');
    } catch (reason) {
      if (alive.current) {
        setText(question);
        setError(
          controller.current.signal.aborted
            ? 'İstek durduruldu. Aynı soruyu tekrar göndererek sunucu sonucunu kontrol edebilirsiniz.'
            : reason instanceof Error
              ? reason.message
              : 'Asistan yanıt veremedi.',
        );
      }
    } finally {
      locked.current = false;
      if (alive.current) setSending(false);
    }
  };
  return (
    <Page title="AI Asistan" scroll={false}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        keyboardVerticalOffset={insets.top}
        style={{ flex: 1, maxWidth: 900, width: '100%', alignSelf: 'center' }}
      >
        <View style={{ paddingHorizontal: 16, gap: 8 }}>
          <Select
            title="Araç bağlamı"
            value={chosen}
            onChange={setSelection}
            disabled={sending}
            items={[
              { value: '', title: 'Araç seçmeden sor' },
              ...(garage.data ?? []).map((v) => ({
                value: String(v.id),
                title: `${v.plate} • ${v.brand} ${v.model}`,
              })),
            ]}
          />
          {entitlement.data && (
            <AppText>
              Kalan asistan kredisi: {entitlement.data.remainingToday}
            </AppText>
          )}
          {entitlement.data?.trialExpiresAt && (
            <AppText variant="bodySmall">
              Deneme bitişi:{' '}
              {new Date(entitlement.data.trialExpiresAt).toLocaleString(
                'tr-TR',
              )}
            </AppText>
          )}
          {entitlement.data?.lockedUntil && (
            <AppText variant="bodySmall">
              Asistan erişimi{' '}
              {new Date(entitlement.data.lockedUntil).toLocaleString('tr-TR')}{' '}
              tarihinde yeniden açılacak.
            </AppText>
          )}
          {entitlement.data && !entitlement.data.canAsk && (
            <Button
              label="Krediler ve Paketler"
              variant="outlined"
              onPress={() => router.push('/billing')}
            />
          )}
          {entitlement.error && (
            <StateView
              error={entitlement.error}
              retry={() => void entitlement.refetch()}
            />
          )}
        </View>
        <FlatList
          ref={list}
          data={messages}
          keyExtractor={(_, index) => String(index)}
          contentContainerStyle={{ padding: 15, gap: 10, flexGrow: 1 }}
          keyboardShouldPersistTaps="handled"
          onContentSizeChange={() =>
            list.current?.scrollToEnd({ animated: true })
          }
          ListEmptyComponent={
            <StateView
              loading={entitlement.isPending}
              empty="Araç ve bakım sorularınızı AI Asistan’a sorun."
            />
          }
          renderItem={({ item }) => <MessageBubble message={item} />}
        />
        {sending && (
          <ActivityIndicator
            color={colors.primary}
            accessibilityLabel="Asistan yanıtı hazırlanıyor"
          />
        )}
        {error && (
          <AppText
            accessibilityRole="alert"
            style={{ color: colors.error, paddingHorizontal: 16 }}
          >
            {error}
          </AppText>
        )}
        {listening && (
          <AppText style={{ paddingHorizontal: 16 }}>
            Dinleniyor… Durdurmak için mikrofona dokunun.
          </AppText>
        )}
        <View
          style={{
            flexDirection: 'row',
            alignItems: 'flex-end',
            gap: 8,
            padding: 12,
            paddingBottom: 24,
          }}
        >
          <IconButton
            label={listening ? 'Durdur' : 'Sesli yaz'}
            icon={listening ? 'stop' : 'mic'}
            disabled={sending || !entitlement.data?.canAsk}
            onPress={() => void toggleSpeech()}
          />
          <TextInput
            accessibilityLabel="Sorunuz"
            value={text}
            onChangeText={setText}
            multiline
            maxLength={2000}
            placeholder="Aracınızla ilgili sorunuzu yazın..."
            placeholderTextColor={colors.muted}
            style={{
              flex: 1,
              minHeight: 50,
              maxHeight: 150,
              padding: 12,
              borderRadius: 16,
              backgroundColor: colors.input,
              borderWidth: 1,
              borderColor: colors.border,
              color: colors.text,
              fontFamily: fonts.regular,
            }}
            editable={!sending}
          />
          <IconButton
            filled
            label={sending ? 'İptal' : 'Gönder'}
            icon={sending ? 'stop' : 'send'}
            onPress={() =>
              sending ? controller.current?.abort() : void send()
            }
          />
        </View>
      </KeyboardAvoidingView>
    </Page>
  );
}
