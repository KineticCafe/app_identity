import assert from 'assert'

import {
  Config,
  Disallowed,
  Fuzz,
  Id,
  Nonce,
  Padlock,
  Secret,
  Version,
  WrappedSecret,
} from './types'

export const toId = (value: unknown): Id => {
  assertNotNull(value, 'id')

  const id: string = toString(value)

  assertSafeString(id, 'id')

  return id as Id
}

export const toSecret = (value: unknown): Secret => {
  const testValue = typeof value === 'function' ? value() : value

  assertNotNull(testValue, 'secret')
  assert(typeof testValue === 'string', 'secret must be a binary string value')
  assertSafeString(testValue, 'secret')

  return value as Secret
}

export const toWrappedSecret = (value: Secret | WrappedSecret): WrappedSecret => {
  if (typeof value === 'function') {
    return value
  }

  return () => value
}

export const toVersion = (value: unknown): Version => {
  assertNotNull(value, 'version')
  assert(
    typeof value === 'string' || typeof value === 'number',
    'version cannot be converted to an integer'
  )

  let version: number

  if (typeof value === 'string') {
    assert(
      value !== '' && !/\D/.test(value as string),
      'version cannot be converted to an integer'
    )
    version = Number.parseInt(value, 10)
  } else {
    version = value as number
  }

  assert(!isNaN(version), 'version cannot be converted to an integer')
  assert(version % 1 === 0 && version > 0, 'version must be a positive integer')

  return version as Version
}

export const toConfig = (value: unknown): Config | null => {
  if (value === null || value === undefined) {
    return null
  }

  assert(typeof value === 'object', 'config must be nil or a map')

  const object: Record<string, unknown> = value as Record<string, unknown>
  const fuzz: unknown = object['fuzz']

  if (fuzz === null || fuzz === undefined) {
    return {} as Config
  }

  assert(
    typeof fuzz === 'number' &&
      !isNaN(fuzz as number) &&
      (fuzz as number) % 1 === 0 &&
      (fuzz as number) > 0,
    'config.fuzz must be a positive integer or nil'
  )

  return { fuzz: fuzz as Fuzz } as Config
}

export const toDisallowed = (list: unknown): Disallowed => {
  if (list === null || list === undefined) {
    return new Set() as Disallowed
  }

  if (list instanceof Set) {
    return list as Disallowed
  }

  assert(Array.isArray(list), 'disallowed must be an array of versions')

  return new Set(list.map(toVersion)) as Disallowed
}

export function assertIsPadlock(value: unknown): asserts value is Padlock {
  assertNotNull(value, 'padlock')
  assert(typeof value === 'string', 'padlock must be a string')
  assertSafeString(value as string, 'padlock')
}

export function assertIsNonce(value: unknown): asserts value is Nonce {
  assertNotNull(value, 'nonce')
  assert(typeof value === 'string', 'nonce must be a string')
  assertSafeString(value as string, 'nonce')
}

function assertNotNull<T>(value: T, type: string): asserts value is NonNullable<T> {
  assert(value !== null && value !== undefined, `${type} must not be nil`)
}

function assertSafeString(value: string, type: string): asserts value is string {
  assert(value !== '', `${type} must not be an empty string`)
  assert(!value.includes(':'), `${type} must not contain colon characters`)
}

const toString = (value: unknown): string => {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return typeof value === 'string' ? value : (value as any).toString()
}
