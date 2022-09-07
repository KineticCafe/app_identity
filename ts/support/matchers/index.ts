import { expect } from 'vitest'

import { App } from '../../src/app'

interface AppIdentityMatchers<R = unknown> {
  // eslint-disable-next-line no-unused-vars
  toBeVerified(expected: App): R
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Vi {
    // eslint-disable-next-line @typescript-eslint/no-empty-interface
    interface Assertion extends AppIdentityMatchers {}
    // eslint-disable-next-line @typescript-eslint/no-empty-interface
    interface AsymmetricMatchersContaining extends AppIdentityMatchers {}
  }
}

expect.extend({
  toBeVerified(actual: null | App, expected: App) {
    const { equals, isNot } = this

    return {
      pass:
        actual !== null &&
        equals(
          {
            ...actual,
            secret: actual.secret(),
          },
          {
            ...expected,
            secret: expected.secret(),
            verified: true,
          }
        ),
      message: () => `${expect} is${isNot ? ' not' : ''} ${expected}`,
      expected,
      actual,
    }
  },
})
