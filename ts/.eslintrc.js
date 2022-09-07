module.exports = {
  root: true,
  env: { node: true },
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint'],
  extends: ['eslint:recommended', 'plugin:@typescript-eslint/recommended'],
  rules: {
    'no-console': process.env.NODE_ENV === 'production' ? 'error' : 'off',
    'no-debugger': process.env.NODE_ENV === 'production' ? 'error' : 'off',
    'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    '@typescript-eslint/no-explicit-any': 'off',
  },
  // overrides: [
  //   {
  //     files: ['tests/**/*.test.{j,t}s', 'tests/support/*.{j,t}s'],
  //     env: { jest: true },
  //     rules: {
  //       '@typescript-eslint/no-var-requires': 'off',
  //     },
  //   },
  // ],
}
