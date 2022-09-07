import assert from 'assert'
import base64url from 'base64-url'

import {
  assertIsNonce,
  assertIsPadlock,
  toDisallowed,
  toId,
  toVersion,
} from './validation'
import { App, AppFinder, AppFinderAsync, AppInput } from './app'
import * as Versions from './versions'

import type { Disallowed, Id, Nonce, Padlock, Version } from './types'

const ProofFromApp = Symbol('from_app')
const ProofFromString = Symbol('from_string')

type ProofSources = typeof ProofFromApp | typeof ProofFromString

type ProofInput = {
  id: Id | unknown
  nonce: Nonce | unknown
  padlock: Padlock | unknown
  version: Version | unknown
  source?: ProofSources
}

/**
 * The representation of the app used for AppIdentity proof generation and
 * verification.
 *
 * This will generally be constructed from an object or JSON object, such as
 * a static configuration entry or a database record.
 */
export class Proof {
  /** {@inheritDoc Id} */
  readonly id: Id
  /** {@inheritDoc Nonce} */
  readonly nonce: Nonce
  /** {@inheritDoc Padlock} */
  readonly padlock: Padlock
  /** {@inheritDoc Version} */
  readonly version: Version

  /** @internal */
  constructor(value: Record<string, unknown> | Proof) {
    if (value instanceof Proof) {
      this.id = value.id
      this.nonce = value.nonce
      this.padlock = value.padlock
      this.version = value.version
    } else {
      value = value as ProofInput

      if (value['source'] != ProofFromApp && value['source'] != ProofFromString) {
        throw new Error(
          'Proofs can only be created from Proof.fromApp or Proof.fromString'
        )
      }

      this.id = toId(value['id'])
      this.version = toVersion(value['version'])

      assertIsNonce(value['nonce'])
      assertIsPadlock(value['padlock'])

      this.nonce = value['nonce']
      this.padlock = value['padlock']
    }

    Object.freeze(this)
  }

  /** @internal */
  static fromApp(
    app: App,
    nonce: unknown | Nonce,
    options: {
      version?: unknown | Version
      disallowed?: unknown | Disallowed
    } = {}
  ): Proof {
    const proofVersion: Version = options.version
      ? toVersion(options.version)
      : app.version

    const disallowed: Disallowed = toDisallowed(options.disallowed)

    assertIsNonce(nonce)

    const proofNonce: Nonce = nonce

    return new Proof({
      source: ProofFromApp,
      id: app.id,
      version: proofVersion,
      nonce: proofNonce,
      padlock: generatePadlock(app, nonce, proofVersion, disallowed),
    })
  }

  /** @internal */
  static fromString(proof: string): Proof {
    return new Proof({
      source: ProofFromString,
      ...parseProofString(proof),
    })
  }

  /** @internal */
  public verify(
    app: App | AppFinder | AppInput,
    options: { disallowed?: unknown | Disallowed } = {}
  ): App | null {
    if (typeof app === 'function') {
      app = app(this)
    }

    if (!(app instanceof App)) {
      app = new App(app)
    }

    assert(this.id === app.id, 'proof and app do not match')
    assert(app.version <= this.version, 'proof and app version mismatch')

    Versions.validateNonce(app, this.nonce, this.version)
    assertIsPadlock(this.padlock)

    return comparePadlocks(
      generatePadlock(app, this.nonce, this.version, toDisallowed(options.disallowed)),
      this.padlock
    )
      ? app.verify()
      : null
  }

  /** @internal */
  public async verifyAsync(
    app: App | AppFinder | AppFinderAsync | AppInput,
    options: { disallowed?: unknown | Disallowed } = {}
  ): Promise<App | null> {
    if (typeof app === 'function') {
      app = await app(this)
    }

    return this.verify(app, options)
  }

  /** @internal */
  toString(): string {
    const parts =
      this.version === 1
        ? [this.id, this.nonce, this.padlock]
        : [this.version, this.id, this.nonce, this.padlock]

    return base64url.encode(parts.join(':'))
  }
}

const generatePadlock = (
  app: App,
  nonce: Nonce,
  version: Version,
  disallowed: Disallowed
): Padlock => {
  assert(
    app.version <= version,
    `app version ${app.version} is not compatible with proof version ${version}`
  )
  assert(
    Versions.isAllowed(version, disallowed),
    `version ${version} has been disallowed`
  )

  Versions.validateNonce(app, nonce, version)

  return Versions.makeDigest(app, nonce, version) as Padlock
}

const parseProofString = (proof: string): ProofInput => {
  const decoded = base64url.decode(proof)

  assert(decoded !== null && decoded !== undefined, 'cannot decode proof string')

  const parts = decoded.split(':')

  switch (parts.length) {
    case 4: {
      const [version, id, nonce, padlock] = parts
      return { id, nonce, padlock, version }
    }
    case 3: {
      const [id, nonce, padlock] = parts
      return { id, nonce, padlock, version: 1 }
    }
  }

  assert(false, 'proof must have 3 parts (version 1) or 4 parts (any version)')
}

const comparePadlocks = (left: Padlock, right: Padlock): boolean => {
  if (!left || !right || !left.length || !right.length) {
    return false
  }

  const l = left.toUpperCase()
  const r = right.toUpperCase()

  if (l.length !== r.length) {
    return false
  }

  let result = 0

  for (let i = 0; i < l.length; ++i) {
    result |= l.charCodeAt(i) ^ r.charCodeAt(i)
  }

  return result === 0
}
