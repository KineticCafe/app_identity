import { expect } from 'vitest'

import { App } from '../../src/app.js'

interface AppIdentityMatchers<R = unknown> {
  toBeVerified: (expected: App | null) => R
}

declare module 'vitest' {
  // biome-ignore lint/suspicious/noExplicitAny: required vitest configuration
  interface Assertion<T = any> extends AppIdentityMatchers<T> {}
  interface AsymmetricMatchersContaining extends AppIdentityMatchers {}
}

const comparableApp = (app: App) => {
  const { source: _source, secret, ...rest } = app

  return { ...rest, secret: secret() }
}

expect.extend({
  toBeVerified(actual: null | App, expected: App) {
    const { equals, isNot } = this

    const actualComparable = actual == null ? null : comparableApp(actual)
    const expectedComparable = comparableApp(expected)

    return {
      pass:
        actual !== null &&
        equals(actualComparable, { ...expectedComparable, verified: true }),
      message: () => `${expect} is${isNot ? ' not' : ''} ${expected}`,
      expected,
      actual,
    }
  },
})
