import assert from 'assert'
import base64url from 'base64-url'
import { createHash, randomBytes } from 'crypto'

import { App } from './app'
import { assertIsNonce, toConfig, toDisallowed, toVersion } from './validation'

import type { Config, Disallowed, Nonce, Version } from './types'

class Base {
  constructor() {
    Object.freeze(this)
  }

  version(): Version {
    throw new Error('Base Version')
  }

  generateNonce(): Nonce {
    throw new Error('Base Version')
  }

  // eslint-disable-next-line no-unused-vars,@typescript-eslint/no-unused-vars
  validateNonce(nonce: unknown, config: Config | null): Nonce {
    assertIsNonce(nonce)
    toConfig(config)

    return nonce as Nonce
  }

  makeDigest(raw: string): string {
    const hash = createHash('sha256')
    hash.update(raw, 'utf-8')
    return hash.digest('hex').toUpperCase()
  }
}

class RandomNonce extends Base {
  generateNonce(): Nonce {
    return base64url.encode(randomBytes(32).toString()) as Nonce
  }
}

const TIMESTAMP_NONCE_FORMAT =
  /^(\d{4})(0\d|1[0-2])([0-2]\d|3[01])T([01]\d|2[0-4])([0-5]\d)([0-5]\d)(\.\d+)?Z$/

const DEFAULT_CONFIG = toConfig({ fuzz: 600 })

class TimestampNonce extends Base {
  generateNonce(): Nonce {
    return new Date().toISOString().replace(/[-:]/g, '') as Nonce
  }

  validateNonce(nonce: unknown, config: Config | null): Nonce {
    return this.parseAndValidate(super.validateNonce(nonce, config), config)
  }

  private parseAndValidate(nonce: Nonce, config: Config | null): Nonce {
    const match = nonce.match(TIMESTAMP_NONCE_FORMAT)
    assert(match, 'nonce does not look like a timestamp')

    const date = [match[1], match[2], match[3]].join('-')
    const time = [match[4], match[5], match[6]].join(':')
    const timestamp = new Date(`${date}T${time}${match[7]}Z`).getTime()

    assert(!isNaN(timestamp), 'nonce does not look like a timestamp')

    const diff = (new Date().getTime() - timestamp) / 1e3
    const fuzz = (config || DEFAULT_CONFIG)?.fuzz || 600

    assert(Math.floor(Math.abs(diff)) <= fuzz, 'nonce is invalid')

    return nonce
  }
}

class V1 extends RandomNonce {
  version(): Version {
    return 1 as Version
  }
}

class V2 extends TimestampNonce {
  version(): Version {
    return 2 as Version
  }
}

class V3 extends TimestampNonce {
  version(): Version {
    return 3 as Version
  }

  makeDigest(raw: string): string {
    const hash = createHash('sha384')
    hash.update(raw, 'utf-8')
    return hash.digest('hex').toUpperCase()
  }
}

class V4 extends TimestampNonce {
  version(): Version {
    return 4 as Version
  }

  makeDigest(raw: string): string {
    const hash = createHash('sha512')
    hash.update(raw, 'utf-8')
    return hash.digest('hex').toUpperCase()
  }
}

const VERSIONS: Map<Version, Base> = Object.freeze(
  new Map([
    [1 as Version, new V1()],
    [2 as Version, new V2()],
    [3 as Version, new V3()],
    [4 as Version, new V4()],
  ])
)
export const versions = (): Map<Version, Base> => Object.freeze(VERSIONS)

const ALLOWED_VERSIONS: Array<Version> = [...VERSIONS.keys()]

Object.freeze(ALLOWED_VERSIONS)

export const allowedVersions = (): Array<Version> => ALLOWED_VERSIONS

function assertValidVersion(version: Version): asserts version {
  assert(
    ALLOWED_VERSIONS.includes(version) && VERSIONS.has(version),
    `unsupported version ${version}`
  )
}

const proofVersion = (version: Version): Base => {
  assertValidVersion(version)
  const proofVersion = VERSIONS.get(version)
  assert(proofVersion instanceof Base, `unsupported version ${version}`)
  return proofVersion
}

export const generateNonce = (app: App, version?: Version): Nonce => {
  if (version) {
    assert(
      app.version <= version,
      `app version ${app.version} is not compatible with requested version ${version}`
    )

    return proofVersion(version).generateNonce()
  }

  return proofVersion(app.version).generateNonce()
}

export const validateNonce = (app: App, nonce: Nonce, version: Version): Nonce =>
  proofVersion(version).validateNonce(nonce, app.config)

export const makeDigest = (app: App, nonce: Nonce, version: Version): string =>
  proofVersion(version).makeDigest([app.id, nonce, app.secret()].join(':'))

const DISALLOWED_VERSIONS: Disallowed = new Set() as Disallowed

export const isAllowed = (
  version: unknown | Version,
  provided?: unknown | Disallowed
): boolean => {
  const checkVersion = toVersion(version)
  const disallowed = toDisallowed(provided)

  return (
    ALLOWED_VERSIONS.includes(checkVersion) &&
    VERSIONS.has(checkVersion) &&
    !disallowed.has(checkVersion) &&
    !DISALLOWED_VERSIONS.has(checkVersion)
  )
}

/**
 * Remove the `versions` from the global disallowed versions list.
 */
export const allowVersion = (...versions: Array<number | string | Version>): void => {
  versions.forEach((version) => DISALLOWED_VERSIONS.delete(toVersion(version)))
}

/**
 * Add the `version` to the global disallowed versions list.
 */
export const disallowVersion = (...versions: Array<number | string | Version>): void => {
  versions.forEach((version) => DISALLOWED_VERSIONS.add(toVersion(version)))
}
