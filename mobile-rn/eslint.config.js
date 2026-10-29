const { defineConfig } = require('eslint/config');
const expo = require('eslint-config-expo/flat');
module.exports = defineConfig([
  expo,
  { ignores: ['coverage/*', 'visual-artifacts/*'] },
  {
    files: ['jest.setup.js'],
    languageOptions: { globals: { jest: 'readonly' } },
  },
]);
