import fixtures from '../../../visual/fixtures.json';
import type { Inspection } from '../../core/models';
const completed = fixtures.inspection as Inspection,
  pending = {
    ...completed,
    status: 'PENDING',
    report: null,
    reportStatus: 'PENDING',
  },
  mockState = { generation: 1 };
const mockGet = jest.fn(),
  mockAnalyze = jest.fn(),
  mockReport = jest.fn(),
  mockCache = jest.fn(),
  mockInvalidate = jest.fn();
jest.mock('../../core/services', () => ({
  inspections: {
    get: (...args: unknown[]) => mockGet(...args),
    analyze: (...args: unknown[]) => mockAnalyze(...args),
    report: (...args: unknown[]) => mockReport(...args),
  },
}));
jest.mock('../../core/runtime', () => ({
  session: {
    getSnapshot: () => mockState,
    check: (generation: number) => {
      if (generation !== mockState.generation) throw new Error('stale');
    },
  },
  queryClient: { setQueryData: (...args: unknown[]) => mockCache(...args) },
  protectedKey: (resource: string) => [mockState.generation, resource],
}));
jest.mock('../../core/queries', () => ({
  invalidate: (...args: unknown[]) => mockInvalidate(...args),
}));
jest.mock('../../core/protectedResources', () => ({
  registerProtectedCleanup: jest.fn(),
}));
let jobs: typeof import('./analysisJobs');
const flush = async () => {
  for (let tick = 0; tick < 25; tick++) await Promise.resolve();
};
beforeEach(() => {
  jest.useFakeTimers();
  jest.resetModules();
  mockState.generation = 1;
  mockGet.mockReset().mockResolvedValue(pending);
  mockAnalyze.mockReset().mockResolvedValue(completed);
  mockReport.mockReset().mockResolvedValue(completed);
  mockCache.mockClear();
  mockInvalidate.mockClear();
  jest.isolateModules(() => {
    jobs =
      jest.requireActual<typeof import('./analysisJobs')>('./analysisJobs');
  });
});
afterEach(() => {
  jest.clearAllTimers();
  jest.useRealTimers();
});
test('opening a completed inspection does not invoke another paid analysis', async () => {
  mockGet.mockResolvedValue(completed);
  const job = jobs.startAnalysis(1, '');
  await flush();
  expect(job.snapshot.phase).toBe('done');
  expect(mockAnalyze).not.toHaveBeenCalled();
});
test('repeated explicit starts share one in-flight paid request', async () => {
  mockAnalyze.mockImplementation(() => new Promise(() => undefined));
  const first = jobs.startAnalysis(1, 'FRONT'),
    second = jobs.startAnalysis(1, 'FRONT');
  await flush();
  expect(first).toBe(second);
  expect(mockAnalyze).toHaveBeenCalledTimes(1);
});
test('a lost response recovers a completed server result without repeating the paid POST', async () => {
  mockAnalyze.mockRejectedValue(new Error('timeout'));
  mockGet.mockResolvedValueOnce(pending).mockResolvedValue(completed);
  const job = jobs.startAnalysis(1, '');
  await flush();
  expect(job.snapshot.phase).toBe('done');
  expect(mockAnalyze).toHaveBeenCalledTimes(1);
});
test('a status poll that finishes before the initial GET prevents a stale initial result from starting another analysis', async () => {
  let initial!: (value: Inspection) => void;
  mockGet
    .mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          initial = resolve;
        }),
    )
    .mockResolvedValue(completed);
  const job = jobs.startAnalysis(1, '');
  await jest.advanceTimersByTimeAsync(2000);
  expect(job.snapshot.phase).toBe('done');
  initial(pending);
  await flush();
  expect(mockAnalyze).not.toHaveBeenCalled();
});
test('a late response after a workspace change is never published to the new query cache', async () => {
  let respond!: (value: Inspection) => void;
  mockAnalyze.mockImplementation(
    () =>
      new Promise((resolve) => {
        respond = resolve;
      }),
  );
  const job = jobs.startAnalysis(1, '');
  await flush();
  mockState.generation++;
  respond(completed);
  await flush();
  expect(mockCache).not.toHaveBeenCalled();
  expect(job.snapshot.phase).toBe('error');
});
test('an unsuccessful recovery stops polling and never retries the paid request automatically', async () => {
  mockAnalyze.mockRejectedValue(new Error('connection lost'));
  const job = jobs.startAnalysis(1, '');
  await flush();
  await jest.advanceTimersByTimeAsync(10000);
  expect(job.snapshot.phase).toBe('error');
  expect(mockAnalyze).toHaveBeenCalledTimes(1);
  expect(mockGet).toHaveBeenCalledTimes(2);
});
