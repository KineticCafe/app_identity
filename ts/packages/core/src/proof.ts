import { getRuntimeAdapter } from './adapter.js'
import type { AppFinder, AppFinderAsync, AppInput } from './app.js'
import { App } from './app.js'
import { AppIdentityError } from './app_identity_error.js'
import type { Result } from './result.js'
import { Err, Ok, throwErrs } from './result.js'
import type { Disallowed, Id, Nonce, Padlock, Version } from './types.js'
import {
  checkDisallowed,
  checkId,
  checkNonce,
  checkPadlock,
  checkVersion,
} from './validation.js'
import * as Versions from './versions.js'

const ProofFromApp = Symbol('from_app')
const ProofFromString = Symbol('from_string')

type ProofSources = typeof ProofFromApp | typeof ProofFromString

interface ProofInput {
  id: Id | unknown
  nonce: Nonce | unknown
  padlock: Padlock | unknown
  version: Version | unknown
}

interface ConstructorProofInput extends ProofInput {
  source: ProofSources
}

const checkProofString = (input: string): Result<ProofInput> => {
  const decoded = getRuntimeAdapter().decodeBase64Url(input)

  if (decoded == null) {
    return Err('cannot decode proof string')
  }

  const parts = decoded.split(':')

  switch (parts.length) {
    case 4: {
      const [version, id, nonce, padlock] = parts
      return Ok({ id, nonce, padlock, version })
    }
    case 3: {
      const [id, nonce, padlock] = parts
      return Ok({ id, nonce, padlock, version: 1 })
    }
    default: {
      return Err('proof must have 3 parts (version 1) or 4 parts (any version)')
    }
  }
}

/**
 * A representation of an app identity proof, constructed from an App (for
 * server side code generation) or
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
  static fromApp(
    app: App,
    nonce: unknown | Nonce,
    options: {
      version?: unknown | Version
      disallowed?: unknown | Disallowed
    } = {},
  ): Proof {
    const disallowed = checkDisallowed(options.disallowed)
    const proofVersion = checkVersion(options.version).unwrapOr(app.version)
    const proofNonce = checkNonce(nonce)

    throwErrs([disallowed, proofNonce], 'Proof cannot be constructed from App')

    return new Proof({
      source: ProofFromApp,
      id: app.id,
      version: proofVersion,
      nonce: proofNonce.unwrap(),
      padlock: generatePadlock(
        app,
        proofNonce.unwrap(),
        proofVersion,
        disallowed.unwrap(),
      ),
    })
  }

  /** @internal */
  static fromString(proof: string): Proof {
    const input = checkProofString(proof).expect(
      'Proof cannot be constructed from String',
    )

    return new Proof({ source: ProofFromString, ...input })
  }

  /** @internal */
  private constructor(input: ConstructorProofInput | Proof) {
    if (input instanceof Proof) {
      this.id = input.id
      this.nonce = input.nonce
      this.padlock = input.padlock
      this.version = input.version
    } else {
      if (input.source !== ProofFromApp && input.source !== ProofFromString) {
        throw new AppIdentityError(
          'Proofs can only be created using Proof.fromApp or Proof.fromString',
        )
      }

      const { id, nonce, padlock, version } = {
        id: checkId(input.id),
        nonce: checkNonce(input.nonce),
        padlock: checkPadlock(input.padlock),
        version: checkVersion(input.version),
      }

      throwErrs([id, version, nonce, padlock], 'Proof cannot be constructed')

      this.id = id.unwrap()
      this.version = version.unwrap()
      this.nonce = nonce.unwrap()
      this.padlock = padlock.unwrap()
    }

    Object.freeze(this)
  }

  /** @internal */
  public verify(
    input: App | AppFinder | AppInput,
    options: { disallowed?: unknown | Disallowed } = {},
  ): App | null {
    let app = input

    if (typeof app === 'function') {
      app = app(this)
    }

    if (!(app instanceof App)) {
      app = new App(app)
    }

    if (this.id !== app.id) {
      throw new AppIdentityError('proof and app do not match')
    }

    if (app.version > this.version) {
      throw new AppIdentityError('proof and app version mismatch')
    }

    const disallowed = checkDisallowed(options.disallowed)

    throwErrs(
      [
        Versions.validateNonce(app, this.nonce, this.version),
        checkPadlock(this.padlock),
        disallowed,
      ],
      'Cannot verify proof',
    )

    return comparePadlocks(
      generatePadlock(app, this.nonce, this.version, disallowed.unwrap()),
      this.padlock,
    )
      ? app.verify()
      : null
  }

  /** @internal */
  public async verifyAsync(
    input: App | AppFinder | AppFinderAsync | AppInput,
    options: { disallowed?: unknown | Disallowed } = {},
  ): Promise<App | null> {
    let app = input

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

    return getRuntimeAdapter().encodeBase64Url(parts.join(':')) || ''
  }
}

const generatePadlock = (
  app: App,
  nonce: Nonce,
  version: Version,
  disallowed: Disallowed,
): Padlock => {
  return Versions.versionIsAllowed(app.version, version, disallowed)
    .andThen((_) => Versions.validateNonce(app, nonce, version))
    .andThen((_) => Versions.makeDigest(app, nonce, version))
    .expect('Cannot generate padlock', AppIdentityError)
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
