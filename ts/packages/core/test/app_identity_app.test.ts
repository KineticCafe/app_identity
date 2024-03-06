import { describe, expect, test } from 'vitest'

import { App } from '../src/app.js'
import './support/index.js'

const input = (record: Record<string, unknown> = {}) => ({
  id: 1,
  secret: 'secret',
  version: 1,
  ...record,
})
const loader =
  (record: Record<string, unknown> = {}) =>
  () =>
    input(record)
const asyncLoader =
  (record: Record<string, unknown> = {}) =>
  async () =>
    input(record)

describe('new App', () => {
  describe('id', () => {
    test('must not be nil', () => {
      expect(() => new App(input({ id: null }))).toThrowError('id must not be nil')
      expect(() => new App(input({ id: undefined }))).toThrowError('id must not be nil')
    })

    test('must not be an empty string', () => {
      expect(() => new App(input({ id: '' }))).toThrowError(
        'id must not be an empty string',
      )
    })

    test('must not contain colons', () => {
      expect(() => new App(input({ id: '1:1' }))).toThrowError(
        'id must not contain colon characters',
      )
    })

    test('converts the id to string', () => {
      expect(new App(input()).id).toEqual('1')
    })
  })

  describe('secret', () => {
    test('must not be nil', () => {
      expect(() => new App(input({ secret: null }))).toThrowError(
        'secret must not be nil',
      )
      expect(() => new App(input({ secret: undefined }))).toThrowError(
        'secret must not be nil',
      )
    })

    test('must be a string', () => {
      expect(() => new App(input({ secret: 3 }))).toThrowError(
        'secret must be a binary string value',
      )
    })

    test('may be a wrapper function', () => {
      const secret = new App(input({ secret: () => 'secret' })).secret
      expect(typeof secret).toEqual('function')
      expect(secret.length).toBe(0)
      expect(secret()).toEqual(input().secret)
    })

    test('must accept no parameters if a wrapper function', () => {
      expect(() => new App(input({ secret: (val: string) => val }))).toThrowError(
        'must not have parameters',
      )
    })

    test('converts the secret to a wrapper function', () => {
      const secret = new App(input()).secret
      expect(typeof secret).toEqual('function')
      expect(secret.length).toBe(0)
      expect(secret()).toEqual(input().secret)
    })
  })

  describe('version', () => {
    test('must not be nil', () => {
      expect(() => new App(input({ version: null }))).toThrowError(
        'version must not be nil',
      )
      expect(() => new App(input({ version: undefined }))).toThrowError(
        'version must not be nil',
      )
    })

    test('must convert to a positive integer', () => {
      expect(() => new App(input({ version: {} }))).toThrowError(
        'version cannot be converted to an integer',
      )
      expect(() => new App(input({ version: '' }))).toThrowError(
        'version cannot be converted to an integer',
      )
      expect(() => new App(input({ version: 'a' }))).toThrowError(
        'version cannot be converted to an integer',
      )
      expect(() => new App(input({ version: '-1' }))).toThrowError(
        'version cannot be converted to an integer',
      )
      expect(() => new App(input({ version: NaN }))).toThrowError(
        'version cannot be converted to an integer',
      )
      expect(new App(input({ version: '1' })).version).toBe(1)
    })

    test('must be a positive integer', () => {
      expect(() => new App(input({ version: 0 }))).toThrowError(
        'version must be a positive integer',
      )
      expect(() => new App(input({ version: -5 }))).toThrowError(
        'version must be a positive integer',
      )
      expect(() => new App(input({ version: 3.5 }))).toThrowError(
        'version must be a positive integer',
      )
    })

    test('must be a supported version', () => {
      expect(() => new App(input({ version: 5 }))).toThrowError('unsupported version 5')
    })
  })

  describe('config', () => {
    test('must be nil or a map', () => {
      expect(() => new App(input({ config: 3 }))).toThrowError(
        'config must be nil or a map',
      )
    })

    test('fuzz must be a positive integer or nil', () => {
      expect(() => new App(input({ config: { fuzz: 99.9 } }))).toThrowError(
        'config.fuzz must be a positive integer or nil',
      )
      expect(() => new App(input({ config: { fuzz: -1 } }))).toThrowError(
        'config.fuzz must be a positive integer or nil',
      )
    })
  })

  test('works with a loader', () => {
    expect(new App(loader()).id).toBe('1')
  })
})

describe('App.createAsync', async () => {
  test('works with app input', async () => {
    expect((await App.createAsync(input())).id).toBe('1')
  })

  test('works with a loader', async () => {
    expect((await App.createAsync(loader())).id).toBe('1')
  })

  test('works with an async loader', async () => {
    expect((await App.createAsync(asyncLoader())).id).toBe('1')
  })
})

describe('App#verify', () => {
  test('returns a new instance when not verified', () => {
    const app = new App(input())
    expect(app.verify()).not.toBe(app)
  })

  test('returns the same instance when verified', () => {
    const app = new App(input()).verify()
    expect(app.verify()).toBe(app)
  })

  test('apps are not verified by default', () => {
    expect(new App(input()).verified).not.toBe(true)
  })

  test('sets verified on the new app', () => {
    expect(new App(input()).verify().verified).toBe(true)
  })

  test('is pre-verified when reconstructed', () => {
    expect(new App(new App(input())).verify().verified).toBe(true)
  })
})

describe('App#unverify', () => {
  test('returns a new instance when verified', () => {
    const app = new App(input()).verify()
    expect(app.unverify()).not.toBe(app)
  })

  test('returns the same instance when unverified', () => {
    const app = new App(input())
    expect(app.unverify()).toBe(app)
  })

  test('unsets verified on the new app', () => {
    expect(new App(input()).verify().unverify().verified).toBe(false)
  })
})

describe('App#generateNonce', () => {
  test('can generate a nonce for its own version', () => {
    expect(new App(input()).generateNonce()).toMatch(/^[^:]+$/)
    expect(new App(input({ version: 4 })).generateNonce()).toMatch(
      /^\d{8}T\d{6}(?:\.\d+)?Z$/,
    )
  })

  test('can generate a nonce for a greater version than the app version', () => {
    expect(new App(input()).generateNonce(4)).toMatch(/^\d{8}T\d{6}(?:\.\d+)?Z$/)
  })

  test('refuses to generate a nonce for a version less than the app version', () => {
    expect(() => new App(input({ version: 4 })).generateNonce(1)).toThrowError(
      'app version 4 is not compatible with requested version 1',
    )
  })
})

describe('App#toString', () => {
  test('never serializes the secret', () => {
    expect(new App(input()).toString()).not.toMatch('secret:')
  })

  test('serializes the verified status', () => {
    expect(new App(input()).toString()).toMatch('verified: false')
    expect(new App(input()).verify().toString()).toMatch('verified: true')
  })

  test('serializes config as JSON', () => {
    expect(new App(input()).toString()).toMatch('config: null')
    expect(new App(input({ config: {} })).toString()).toMatch('config: {}')
    expect(
      new App({ id: 1, secret: 'secret', version: 1, config: { fuzz: 10 } }).toString(),
    ).toMatch('config: {"fuzz":10}')
  })

  test('serializes as a readable value', () => {
    expect(new App(input()).toString()).toBe(
      '[object App (id: 1, version: 1, config: null, verified: false)]',
    )
  })
})

describe('App#toAppInput', () => {
  test('converts to a plain object with secret exposed', () => {
    expect(new App(input()).toAppInput()).toStrictEqual({
      id: '1',
      secret: 'secret',
      config: null,
      version: 1,
    })
  })

  test('does not carry the verified state', () => {
    expect(new App(input()).verify().toAppInput()).toStrictEqual({
      id: '1',
      secret: 'secret',
      config: null,
      version: 1,
    })
  })

  test('properly includes the config', () => {
    expect(
      new App({ id: 1, secret: 'secret', version: 1, config: {} }).toAppInput(),
    ).toStrictEqual({
      id: '1',
      secret: 'secret',
      config: {},
      version: 1,
    })

    expect(
      new App({ id: 1, secret: 'secret', version: 1, config: { fuzz: 10 } }).toAppInput(),
    ).toStrictEqual({
      id: '1',
      secret: 'secret',
      config: { fuzz: 10 },
      version: 1,
    })
  })
})
