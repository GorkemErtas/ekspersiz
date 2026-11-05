import {
  fireEvent,
  render,
  screen,
  waitFor,
} from '@testing-library/react-native';
import AssistantScreen from './AssistantScreen';

const mockPush = jest.fn();
const mockAsk = jest.fn();
let mockCanAsk = true;
jest.mock('expo-router', () => ({
  useLocalSearchParams: () => ({}),
  useRouter: () => ({ push: mockPush }),
}));
jest.mock('expo-speech-recognition', () => ({
  useSpeechRecognitionEvent: jest.fn(),
  ExpoSpeechRecognitionModule: { abort: jest.fn(), stop: jest.fn() },
}));
jest.mock('../../core/runtime', () => ({ api: {}, session: {} }));
jest.mock('../../core/queries', () => ({
  invalidate: jest.fn(),
  useResource: (key: string) => ({
    data:
      key === 'assistant/entitlement'
        ? { canAsk: mockCanAsk, remainingToday: 3 }
        : [],
    isPending: false,
  }),
}));
jest.mock('./AssistantService', () => ({
  AssistantService: jest.fn().mockImplementation(() => ({ ask: mockAsk })),
}));
jest.mock('./MessageBubble', () => {
  const { Text } =
    jest.requireActual<typeof import('react-native')>('react-native');
  return {
    MessageBubble: ({ message }: { message: { content: string } }) => (
      <Text>{message.content}</Text>
    ),
  };
});

beforeEach(() => {
  jest.clearAllMocks();
  mockCanAsk = true;
  mockAsk.mockResolvedValue({ answer: 'Bakım yanıtı', sources: [] });
});

test('composer disables empty submissions and keeps sending and credit refresh behavior', async () => {
  await render(<AssistantScreen />);
  expect(screen.getByRole('button', { name: 'Gönder' })).toBeDisabled();
  await fireEvent.changeText(screen.getByLabelText('Sorunuz'), '  ');
  expect(screen.getByRole('button', { name: 'Gönder' })).toBeDisabled();
  await fireEvent.changeText(
    screen.getByLabelText('Sorunuz'),
    'Bakım ne zaman?',
  );
  await fireEvent.press(screen.getByRole('button', { name: 'Gönder' }));
  await waitFor(() => expect(screen.getByText('Bakım yanıtı')).toBeTruthy());
  expect(mockAsk).toHaveBeenCalledWith(
    'Bakım ne zaman?',
    undefined,
    [],
    expect.any(AbortSignal),
  );
  expect(screen.getByLabelText('Sorunuz').props.value).toBe('');
  expect(screen.getByRole('button', { name: 'Gönder' })).toBeDisabled();
});

test('unavailable credits still lead to billing without sending an AI request', async () => {
  mockCanAsk = false;
  await render(<AssistantScreen />);
  await fireEvent.changeText(screen.getByLabelText('Sorunuz'), 'Bir sorum var');
  await fireEvent.press(screen.getByRole('button', { name: 'Gönder' }));
  expect(mockPush).toHaveBeenCalledWith('/billing');
  expect(mockAsk).not.toHaveBeenCalled();
});
