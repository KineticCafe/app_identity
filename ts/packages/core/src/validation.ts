import { Err, Ok } from './result.js'

import type { Result } from './result.js'
import type {
  Config,
  Disallowed,
  Fuzz,
  Id,
  Nonce,
  Padlock,
  Version,
  WrappedSecret,
} from './types.js'

/// Converts the provided value to `Result<Id>`.
export const checkId = (value: unknown): Result<Id> => {
  if (value == null) {
    return Err(mustNotBeNil('id'))
  }

  return checkSafeString(String(value), 'id').map((val) => val as Id)
}

/// Converts the provided value to `Result<Secret>`.
export const checkSecret = (value: unknown): Result<WrappedSecret> => {
  if (typeof value === 'function') {
    return value.length === 0
      ? checkSecretContents(value())
      : Err('wrapped secret function must not have parameters')
  }

  return checkSecretContents(value)
}

const checkSecretContents = (value: unknown): Result<WrappedSecret> => {
  return value == null
    ? Err(mustNotBeNil('secret'))
    : typeof value !== 'string'
      ? Err('secret must be a binary string value')
      : checkString(value, 'secret')
          .andThen(checkNonEmptyString('secret'))
          .andThen(wrapSecret)

  // andThen(wrapSecret )
}

const wrapSecret = (value: string): Result<WrappedSecret> =>
  Ok((() => value) as WrappedSecret)

/// Converts the provided value to `Result<Version>`
export const checkVersion = (value: unknown): Result<Version> => {
  if (value == null) {
    return Err(mustNotBeNil('version'))
  }

  if (typeof value !== 'string' && typeof value !== 'number') {
    return Err(cannotConvertVersion)
  }

  let version: number

  if (typeof value === 'string') {
    if (value === '' || /\D/.test(value as string)) {
      return Err(cannotConvertVersion)
    }

    version = Number.parseInt(value, 10)
  } else {
    version = value as number
  }

  if (Number.isNaN(version)) {
    return Err(cannotConvertVersion)
  }

  return version % 1 === 0 && version > 0
    ? Ok(version as Version)
    : Err('version must be a positive integer')
}

/// Converts the provided value to `Result<Config>` or `Result<null>`.
export const checkConfig = (value: unknown): Result<Config | null> => {
  if (value == null) {
    return Ok(null)
  }

  if (typeof value !== 'object') {
    return Err('config must be nil or a map')
  }

  const object = value as { fuzz?: unknown }
  const fuzz = object.fuzz

  if (fuzz == null) {
    return Ok({} as Config)
  }

  return typeof fuzz === 'number' &&
    !Number.isNaN(fuzz as number) &&
    (fuzz as number) % 1 === 0 &&
    (fuzz as number) > 0
    ? Ok({ fuzz: fuzz as Fuzz } as Config)
    : Err('config.fuzz must be a positive integer or nil')
}

/// Converts the provided value to `Result<Disallowed>`.
export const checkDisallowed = (list: unknown): Result<Disallowed> => {
  if (list == null) {
    return Ok(new Set() as Disallowed)
  }

  if (list instanceof Set) {
    return Ok(list as Disallowed)
  }

  if (Array.isArray(list)) {
    const set: Set<Version> = new Set<Version>()

    for (const version of list) {
      const v = checkVersion(version)

      if (v.isOk()) {
        set.add(v.unwrap())
      } else {
        return Err(v.unwrapErr())
      }
    }

    return Ok(set as Disallowed)
  }

  return Err('disallowed must be an array of versions')
}

/// Converts the provided value to `Result<Padlock>`.
export const checkPadlock = (value: unknown): Result<Padlock> =>
  checkString(value, 'padlock')
    .andThen(checkNonEmptyString('padlock'))
    .andThen((val) =>
      /^[a-fA-F0-9]+$/.test(val) ? Ok(val) : Err('padlock must be a hex string'),
    )
    .map((val) => val as Padlock)

/// Converts the provided value to `Result<Nonce>`.
export const checkNonce = (value: unknown): Result<Nonce> =>
  checkSafeString(value, 'nonce').map((val) => val as Nonce)

const checkString = (value: unknown, type: string): Result<string> =>
  typeof value === 'string' ? Ok(value as string) : Err(`${type} must be a string`)

const checkSafeString = (value: unknown, type: string): Result<string> =>
  checkString(value, type).andThen(checkNonEmptyString(type)).andThen(checkNoColons(type))

const checkNonEmptyString =
  (type: string): ((val: string) => Result<string>) =>
  (val: string): Result<string> =>
    val !== '' ? Ok(val) : Err(`${type} must not be an empty string`)

const checkNoColons =
  (type: string): ((val: string) => Result<string>) =>
  (val: string): Result<string> =>
    val.includes(':') ? Err(`${type} must not contain colon characters`) : Ok(val)

const mustNotBeNil = (type: string): string => `${type} must not be nil`

const cannotConvertVersion = 'version cannot be converted to an integer'
