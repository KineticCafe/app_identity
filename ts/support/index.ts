import base64url from 'base64-url'
import { createHash, randomBytes, randomUUID } from 'crypto'
import { add as adjustDate } from 'date-fns'

import { App } from '../src/app'
import type { AppInput } from '../src/app'

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
    id: randomUUID(),
    secret: randomBytes(32).toString('hex'),
  }

  if (typeof fuzz == 'number') {
    output.config = { fuzz }
  }

  return output
}

export const v2Input = (fuzz?: number): AppInput => ({ ...v1Input(fuzz), version: 2 })
export const v3Input = (fuzz?: number): AppInput => ({ ...v1Input(fuzz), version: 3 })
export const v4Input = (fuzz?: number): AppInput => ({ ...v1Input(fuzz), version: 4 })

export const decodeToParts = (proof: string): Array<string> =>
  base64url.decode(proof).split(':')

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
  options: Record<string, unknown> = {}
): string => {
  const version = options['version'] ?? app.version
  const id = options['id'] ?? app.id
  const nonce = options['nonce'] === EMPTY_NONCE ? '' : options['nonce'] ?? 'nonce'
  const secretValue = options['secret'] ?? app.secret
  const secret = typeof secretValue === 'function' ? secretValue() : secretValue

  const raw = [id, nonce, secret].join(':')

  const hash = createHash(versionAlgorithm(version as number))
  hash.update(raw, 'utf-8')
  return hash.digest('hex').toUpperCase()
}

export const buildProof = (
  app: AppInput | App,
  padlock: string,
  options: Record<string, unknown> = {}
): string => {
  const id = options['id'] || app.id
  const nonce = options['nonce'] === EMPTY_NONCE ? '' : options['nonce'] || 'nonce'
  const version = options['version'] || app.version || 1
  const proof =
    version == 1
      ? [id, nonce, padlock].join(':')
      : [version, id, nonce, padlock].join(':')

  return base64url.encode(proof)
}

type adjustmentScale = 'minutes' | 'seconds' | 'hours'

export const timestampNonce = (
  diff: number | undefined = undefined,
  scale: adjustmentScale = 'minutes'
): string => adjustTimestamp(new Date(), diff, scale).toISOString().replace(/[-:]/g, '')

const adjustTimestamp = (
  date: Date,
  diff: number | undefined,
  scale: adjustmentScale
): Date => {
  if (!diff) {
    return date
  }

  return adjustDate(date, { [scale]: diff })
}
