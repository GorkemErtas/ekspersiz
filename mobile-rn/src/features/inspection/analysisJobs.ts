import { inspections } from '../../core/services';
import { session, queryClient, protectedKey } from '../../core/runtime';
import { invalidate } from '../../core/queries';
import { registerProtectedCleanup } from '../../core/protectedResources';
import type { Inspection } from '../../core/models';
interface Snapshot {
  phase: 'running' | 'done' | 'error';
  result?: Inspection;
  error?: unknown;
}
export class AnalysisJob {
  snapshot: Snapshot = { phase: 'running' };
  private listeners = new Set<() => void>();
  private controller = new AbortController();
  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };
  getSnapshot = () => this.snapshot;
  constructor(id: number, region: '' | 'FRONT' | 'REAR', generation: number) {
    const accept = (result: Inspection) => {
      session.check(generation);
      if (this.snapshot.phase !== 'running') return;
      queryClient.setQueryData(protectedKey(`inspection/${id}`), result);
      void invalidate('inspections', 'credits', 'analysis-quota', 'vehicles/');
      this.publish({ phase: 'done', result });
    };
    const check = () => {
      session.check(generation);
      if (this.snapshot.phase !== 'running')
        throw new Error('Analiz sonucu zaten alındı.');
      if (this.controller.signal.aborted)
        throw new Error(
          'İstek durduruldu. Analiz durumunu geçmişten kontrol edin.',
        );
    };
    let reading = false;
    const poll = setInterval(() => {
      if (reading || this.snapshot.phase !== 'running') return;
      reading = true;
      void (async () => {
        check();
        const current = await inspections.get(id, this.controller.signal);
        check();
        if (
          current.status === 'COMPLETED' &&
          current.reportStatus !== 'PROCESSING' &&
          (current.report || current.reportStatus === 'FAILED')
        )
          accept(current);
      })()
        .catch(() => undefined)
        .finally(() => {
          reading = false;
        });
    }, 2000);
    void (async () => {
      check();
      const initial = await inspections.get(id, this.controller.signal);
      check();
      if (['COMPLETED', 'PROCESSING'].includes(initial.status)) {
        accept(initial);
        return;
      }
      try {
        let result = await inspections.analyze(
          id,
          region,
          this.controller.signal,
        );
        check();
        if (
          result.status === 'COMPLETED' &&
          !result.report &&
          !['FAILED', 'PROCESSING'].includes(result.reportStatus ?? '')
        ) {
          result = await inspections.report(id);
          check();
        }
        accept(result);
      } catch (error) {
        check();
        try {
          const recovered = await inspections.get(id, this.controller.signal);
          check();
          if (['COMPLETED', 'PROCESSING'].includes(recovered.status)) {
            accept(recovered);
            return;
          }
        } catch {
          /* A failed status read never starts another paid request. */
        }
        throw error;
      }
    })()
      .catch((error) => {
        if (this.snapshot.phase === 'running')
          this.publish({ phase: 'error', error });
      })
      .finally(() => clearInterval(poll));
  }
  private publish(snapshot: Snapshot) {
    this.snapshot = snapshot;
    this.listeners.forEach((listener) => listener());
  }
  cancel() {
    this.controller.abort();
  }
}
const jobs = new Map<string, AnalysisJob>();
const key = (id: number) => `${session.getSnapshot().generation}/${id}`;
export const getAnalysis = (id: number) => jobs.get(key(id));
/** Called only from an explicit upload/analysis action, never from mounting a screen. */
export function startAnalysis(id: number, region: '' | 'FRONT' | 'REAR') {
  const existing = getAnalysis(id);
  if (existing?.snapshot.phase === 'running') return existing;
  const job = new AnalysisJob(id, region, session.getSnapshot().generation);
  jobs.set(key(id), job);
  return job;
}
registerProtectedCleanup(() => {
  for (const job of jobs.values()) job.cancel();
  jobs.clear();
});
