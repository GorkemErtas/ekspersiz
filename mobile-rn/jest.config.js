module.exports = {
  preset: 'jest-expo',
  testTimeout: 15000,
  testMatch: ['<rootDir>/src/**/*.test.[jt]s?(x)'],
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
  collectCoverageFrom: ['src/core/**/*.ts', 'src/features/auth/auth.ts'],
};
