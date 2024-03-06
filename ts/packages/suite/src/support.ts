import { createHash, randomBytes, randomUUID } from 'crypto'
import { add as adjustDate } from 'date-fns'

import { App, getRuntimeAdapter } from '@kineticcafe/app-identity-node'

import type { AppIdentityVersionInfo, AppInput } from '@kineticcafe/app-identity-node'
import type * as Runner from './runner/types.js'
import type * as Schema from './schema.js'

export const EMPTY_NONCE = Symbol('empty-nonce')

const HasSpecVersion = /\bspec \d\b/

export const versionString = (
  info: AppIdentityVersionInfo | Schema.Suite | Runner.Suite,
): string => {
  if ('description' in info) {
    return info.description
  }

  if ('core' in info) {
    return `${info.core.name} ${info.core.version} (${
      info.core.version === info.version ? info.name : `${info.name} ${info.version}`
    }, spec ${info.spec_version})`
  }

  if (HasSpecVersion.test(info.version)) {
    return `${info.name} ${info.version}`
  }

  return `${info.name} ${info.version} (spec ${info.spec_version})`
}

export const app = (version: number, fuzz?: number): App => {
  switch (version) {
    case 1:
      return new App(v1Input(fuzz))
    case 2:
      return new App(v2Input(fuzz))
    case 3:
      return new App(v3Input(fuzz))
    case 4:
      return new App(v4Input(fuzz))
  }

  throw new Error(`Unsupported version ${version}`)
}

export const v1Input = (fuzz?: number): AppInput => {
  const output: AppInput = {
    version: 1,
    id: randomUUID(),
    secret: randomBytes(32).toString('hex'),
  }

  if (typeof fuzz === 'number') {
    output.config = { fuzz }
  }

  return output
}

export const v2Input = (fuzz?: number): AppInput => ({ ...v1Input(fuzz), version: 2 })
export const v3Input = (fuzz?: number): AppInput => ({ ...v1Input(fuzz), version: 3 })
export const v4Input = (fuzz?: number): AppInput => ({ ...v1Input(fuzz), version: 4 })

export const decodeBase64Url = (value: string) => {
  const result = getRuntimeAdapter().decodeBase64Url(value)

  if (result == null) {
    throw new Error(`Test error: invalid proof ${JSON.stringify(value)}`)
  }

  return result
}

export const encodeBase64Url = (value: string) => {
  const result = getRuntimeAdapter().encodeBase64Url(value)

  if (result == null) {
    throw new Error(`Test error: cannot base64 encode ${JSON.stringify(value)}`)
  }

  return result
}

export const decodeToParts = (proof: string): string[] =>
  decodeBase64Url(proof).split(':')

const versionAlgorithm = (version: number): 'sha256' | 'sha384' | 'sha512' => {
  switch (version) {
    case 1:
    case 2: {
      return 'sha256'
    }
    case 3: {
      return 'sha384'
    }
    case 4: {
      return 'sha512'
    }
  }

  throw new Error(`Unsupported version ${version}`)
}

/** @internal */
export interface BuildPadlockOptions {
  version?: number
  id?: number | string
  nonce?: string | symbol
  secret?: string | (() => string)
  case?: 'lower' | 'random' | 'upper'
}

/** @internal */
export const buildPadlock = (
  app: AppInput | App,
  options: BuildPadlockOptions = {},
): string => {
  const version = options.version ?? app.version
  const id = options.id ?? app.id
  const nonce = options.nonce === EMPTY_NONCE ? '' : options.nonce ?? 'nonce'
  const secretValue = options.secret ?? app.secret
  const secret = typeof secretValue === 'function' ? secretValue() : secretValue

  let padlockCase: 'lower' | 'random' | 'upper' | null | undefined

  switch (options.case) {
    case 'upper': {
      padlockCase = 'upper'
      break
    }
    case 'lower': {
      padlockCase = 'lower'
      break
    }
    case undefined:
    case null:
    case 'random': {
      padlockCase = randomPadlockCase()
      break
    }
    default: {
      throw 'Invalid padlock case value provided'
    }
  }

  const raw = [id, nonce, secret].join(':')

  const hash = createHash(versionAlgorithm(version as number))
  hash.update(raw, 'utf-8')

  return padlockCase === 'lower'
    ? hash.digest('hex').toLowerCase()
    : hash.digest('hex').toUpperCase()
}

const randomPadlockCase = () =>
  Math.floor(Math.random() * 10 + 1) < 5 ? 'upper' : 'lower'

/** @internal */
export interface BuildProofOptions {
  id?: string
  nonce?: string | symbol | null
  secret?: string
  version?: number
}

/** @internal */
export const buildProof = (
  app: AppInput | App,
  padlock: string,
  options: BuildProofOptions = {},
): string => {
  const id = options.id ?? app.id
  const nonce = options.nonce === EMPTY_NONCE ? '' : options.nonce ?? 'nonce'
  const version = options.version ?? (app.version || 1)
  const proof =
    version === 1
      ? [id, nonce, padlock].join(':')
      : [version, id, nonce, padlock].join(':')

  return encodeBase64Url(proof)
}

type adjustmentScale = 'minutes' | 'seconds' | 'hours'

export const timestampNonce = (
  diff: number | undefined = undefined,
  scale: adjustmentScale = 'minutes',
): string => adjustTimestamp(new Date(), diff, scale).toISOString().replace(/[-:]/g, '')

const adjustTimestamp = (
  date: Date,
  diff: number | undefined,
  scale: adjustmentScale,
): Date => {
  if (!diff) {
    return date
  }

  return adjustDate(date, { [scale]: diff })
}
