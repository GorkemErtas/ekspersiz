import type { Api } from '../../core/api';
import type { Session } from '../../core/session';
import type { AssistantReply, ChatMessage } from '../../core/models';
import { object } from '../../core/services';

export function historyContent(text: string) {
  if (text.length <= 2000) return text;
  const gap = '\n[… önceki mesajın orta bölümü çıkarıldı …]\n';
  let head = 2000 - gap.length - 400,
    tail = text.length - 400;
  if ((text.charCodeAt(head - 1) & 0xfc00) === 0xd800) head--;
  if ((text.charCodeAt(tail) & 0xfc00) === 0xdc00) tail++;
  return text.slice(0, head) + gap + text.slice(tail);
}
export class AssistantService {
  private pending: { payload: string; id: string; generation: number } | null =
    null;
  private busy = false;
  constructor(
    private api: Api,
    private session: Session,
    private uuid: () => string,
  ) {}
  async ask(
    question: string,
    vehicleId: number | undefined,
    history: ChatMessage[],
    signal?: AbortSignal,
  ) {
    question = question.trim();
    if (!question || question.length > 2000)
      throw new Error('Sorunuz 1–2000 karakter arasında olmalıdır.');
    if (this.busy) throw new Error('Yanıt bekleniyor.');
    const generation = this.session.getSnapshot().generation;
    const requestHistory = history.slice(-6).map((message) => ({
      role: message.role,
      content: historyContent(message.content),
    }));
    const payload = JSON.stringify([
      question,
      vehicleId ?? null,
      requestHistory,
    ]);
    if (
      this.pending?.payload !== payload ||
      this.pending.generation !== generation
    )
      this.pending = { payload, id: this.uuid(), generation };
    this.busy = true;
    try {
      const reply = object<AssistantReply>(
        await this.api.request('/ai-assistant/chat', {
          method: 'POST',
          body: {
            question,
            requestId: this.pending.id,
            ...(vehicleId ? { vehicleId } : {}),
            history: requestHistory,
          },
          timeout: 75_000,
          signal,
        }),
      );
      this.session.check(generation);
      if (
        typeof reply.answer !== 'string' ||
        !Number.isFinite(reply.remainingToday)
      )
        throw new Error('Asistan yanıtı geçersiz.');
      this.pending = null;
      return reply;
    } finally {
      this.busy = false;
    }
  }
}
