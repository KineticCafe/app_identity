import { getRuntimeAdapter } from './adapter.js'
import type { App } from './app.js'
import type { Result } from './result.js'
import { Err, Ok, throwErrs, unwrapOks } from './result.js'
import type { Config, Disallowed, Fuzz, Nonce, Padlock, Version } from './types.js'
import { checkNonce, checkVersion } from './validation.js'

export abstract class VersionBase {
  constructor() {
    Object.freeze(this)
  }

  abstract version(): Version

  abstract generateNonce(): Nonce

  validateNonce(value: unknown, _config: Config | null): Result<Nonce> {
    return checkNonce(value)
  }

  makeDigest(raw: string): string {
    return getRuntimeAdapter().sha256(raw)
  }
}

const TIMESTAMP_NONCE_FORMAT =
  /^(\d{4})(0\d|1[0-2])([0-2]\d|3[01])T([01]\d|2[0-4])([0-5]\d)([0-5]\d)(\.\d+)?Z$/

const DEFAULT_CONFIG_FUZZ: Fuzz = 600 as Fuzz

abstract class TimestampNonce extends VersionBase {
  generateNonce(): Nonce {
    return checkNonce(new Date().toISOString().replace(/[-:]/g, '')).unwrap()
  }

  override validateNonce(nonce: unknown, config: Config | null): Result<Nonce> {
    return this.parseAndValidate(super.validateNonce(nonce, config), config)
  }

  private parseAndValidate(nonce: Result<Nonce>, config: Config | null): Result<Nonce> {
    if (nonce.isErr()) {
      return nonce
    }

    const match = nonce.unwrap().match(TIMESTAMP_NONCE_FORMAT)

    if (!match) {
      return Err('nonce does not look like a timestamp')
    }

    const date = [match[1], match[2], match[3]].join('-')
    const time = [match[4], match[5], match[6]].join(':')
    const timestamp = new Date(`${date}T${time}${match[7]}Z`).getTime()

    if (Number.isNaN(timestamp)) {
      return Err('nonce does not look like a timestamp')
    }

    const diff = (Date.now() - timestamp) / 1e3
    const fuzz = config?.fuzz ?? DEFAULT_CONFIG_FUZZ

    return Math.floor(Math.abs(diff)) <= fuzz ? nonce : Err('nonce is invalid')
  }
}

class V1 extends VersionBase {
  generateNonce(): Nonce {
    return checkNonce(getRuntimeAdapter().randomNonceString()).unwrap()
  }

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

  override makeDigest(raw: string): string {
    return getRuntimeAdapter().sha384(raw)
  }
}

class V4 extends TimestampNonce {
  version(): Version {
    return 4 as Version
  }

  override makeDigest(raw: string): string {
    return getRuntimeAdapter().sha512(raw)
  }
}

const VERSIONS: Map<Version, typeof V1 | typeof V2 | typeof V3 | typeof V4> =
  Object.freeze(
    new Map([
      [1 as Version, V1],
      [2 as Version, V2],
      [3 as Version, V3],
      [4 as Version, V4],
    ]),
  )

/// A list of all supported versions.
export const versions = (): typeof VERSIONS => VERSIONS

const DEFINED_VERSIONS = Object.freeze([
  1 as Version,
  2 as Version,
  3 as Version,
  4 as Version,
])
export const definedVersions = (): readonly Version[] => DEFINED_VERSIONS

export const isDefinedVersion = (version: Version): Result<Version> =>
  DEFINED_VERSIONS.includes(version) && VERSIONS.has(version)
    ? Ok(version)
    : Err(`unsupported version ${version}`)

export const proofVersion = (version: Version): Result<VersionBase> =>
  isDefinedVersion(version).match({
    ok: (v): Result<VersionBase> => {
      const klass = VERSIONS.get(v)
      return klass != null ? Ok(new klass()) : Err(`unsupported version ${version}`)
    },
    err: (e) => Err(e),
  })

export const validateNonce = (app: App, nonce: Nonce, version: Version): Result<Nonce> =>
  proofVersion(version).andThen((ver) => ver.validateNonce(nonce, app.config))

export const makeDigest = (app: App, nonce: Nonce, version: Version): Result<Padlock> =>
  proofVersion(version).andThen((ver) =>
    Ok(ver.makeDigest([app.id, nonce, app.secret()].join(':')) as Padlock),
  )

const DISALLOWED_VERSIONS: Disallowed = new Set<Version>() as Disallowed

/** @internal */
export const versionIsAllowed = (
  appVersion: Version,
  proofVersion: Version,
  providedDisallowed: Disallowed,
): Result<Version> => {
  if (appVersion > proofVersion) {
    return Err(
      `app version ${appVersion} is not compatible with proof version ${proofVersion}`,
    )
  }

  if (
    DEFINED_VERSIONS.includes(proofVersion) &&
    VERSIONS.has(proofVersion) &&
    !providedDisallowed.has(proofVersion) &&
    !DISALLOWED_VERSIONS.has(proofVersion)
  ) {
    return Ok(proofVersion)
  }

  return Err(`Proof version ${proofVersion} is not allowed`)
}

/**
 * Remove the `versions` from the global disallowed versions list.
 */
export const allowVersion = (...versions: Array<number | string | Version>): void => {
  for (const version of checkVersions(versions)) {
    DISALLOWED_VERSIONS.delete(version)
  }
}

/**
 * Add the `version` to the global disallowed versions list.
 */
export const disallowVersion = (...versions: Array<number | string | Version>): void => {
  for (const version of checkVersions(versions)) {
    DISALLOWED_VERSIONS.add(version)
  }
}

const checkVersions = (versions: Array<number | string | Version>): Version[] => {
  const checkedVersions = versions.map((v) => checkVersion(v))

  throwErrs(checkedVersions, 'Version error')

  return unwrapOks(checkedVersions)
}
