// Unit tests exercise interaction, not timing. Native animation is a device gate.
jest.mock('react-native-reanimated', () => {
  const native = require('react-native');
  const animation = {
    duration: () => animation,
    easing: () => animation,
    reduceMotion: () => animation,
  };
  return {
    __esModule: true,
    default: { View: native.View },
    FadeIn: animation,
    Easing: native.Easing,
    ReduceMotion: { System: 'system' },
  };
});
jest.mock('expo-secure-store', () => ({
  getItemAsync: jest.fn(async () => null),
  setItemAsync: jest.fn(async () => undefined),
  deleteItemAsync: jest.fn(async () => undefined),
}));
jest.mock(
  'react-native-safe-area-context',
  () => require('react-native-safe-area-context/jest/mock').default,
);
