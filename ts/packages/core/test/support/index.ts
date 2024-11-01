import { createHash, randomUUID } from 'node:crypto'
import * as base64 from '@juanelas/base64'
import { add as adjustDate } from 'date-fns'

import {
  RuntimeAdapter,
  getRuntimeAdapter,
  setRuntimeAdapter,
} from '../../src/adapter.js'
import { App } from '../../src/app.js'

import type { AppInput } from '../../src/app.js'

class Adapter extends RuntimeAdapter {
  decodeBase64Url(value: string): null | string | undefined {
    try {
      return base64.decode(value, true)
    } catch (_) {
      return undefined
    }
  }

  encodeBase64Url(value: string): null | string | undefined {
    try {
      return base64.encode(value, true, true)
    } catch (_) {
      return undefined
    }
  }

  randomNonceString(): string {
    return randomUUID()
  }

  sha256(value: string): string {
    return this.makeHash(value, 'sha256')
  }

  sha384(value: string): string {
    return this.makeHash(value, 'sha384')
  }

  sha512(value: string): string {
    return this.makeHash(value, 'sha512')
  }

  private makeHash(value: string, algorithm: 'sha256' | 'sha384' | 'sha512'): string {
    const hash = createHash(algorithm)
    hash.update(value)
    return hash.digest('hex').toUpperCase()
  }
}

setRuntimeAdapter(Adapter)
const adapter = getRuntimeAdapter()

export const EMPTY_NONCE = Symbol('empty-nonce')

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
    id: adapter.randomNonceString(),
    secret: adapter.randomNonceString(),
  }

  if (typeof fuzz === 'number') {
    output.config = { fuzz }
  }

  return output
}

export const encodeBase64Url = (value: string) => {
  const result = adapter.encodeBase64Url(value)

  if (result == null) {
    throw new Error(`Test error: cannot base64 encode ${JSON.stringify(value)}`)
  }

  return result
}

export const decodeBase64Url = (value: string) => {
  const result = adapter.decodeBase64Url(value)

  if (result == null) {
    throw new Error(`Test error: invalid proof ${JSON.stringify(value)}`)
  }

  return result
}

export const v2Input = (fuzz?: number): AppInput => ({ ...v1Input(fuzz), version: 2 })
export const v3Input = (fuzz?: number): AppInput => ({ ...v1Input(fuzz), version: 3 })
export const v4Input = (fuzz?: number): AppInput => ({ ...v1Input(fuzz), version: 4 })

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

export const buildPadlock = (
  app: AppInput | App,
  options: {
    id?: unknown
    version?: unknown
    nonce?: unknown
    secret?: unknown
    case?: 'upper' | 'lower' | 'random' | undefined | null
  } = {},
): string => {
  const version = options.version ?? app.version
  const id = options.id ?? app.id
  const nonce = options.nonce === EMPTY_NONCE ? '' : (options.nonce ?? 'nonce')
  const secretValue = options.secret ?? app.secret
  const secret = typeof secretValue === 'function' ? secretValue() : secretValue

  let padlockCase: 'upper' | 'lower'

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

export const buildProof = (
  app: AppInput | App,
  padlock: string,
  options: { id?: unknown; nonce?: unknown; case?: unknown; version?: unknown } = {},
): string => {
  const id = options.id || app.id
  const nonce = options.nonce === EMPTY_NONCE ? '' : options.nonce || 'nonce'
  const version = options.version || app.version || 1
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

export { adapter as Adapter }
