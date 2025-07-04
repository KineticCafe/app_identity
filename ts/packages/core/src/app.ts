import { AppIdentityError } from './app_identity_error.js'
import type { Proof } from './proof.js'
import { throwErrs } from './result.js'
import type { Config, Id, Nonce, Version, WrappedSecret } from './types.js'
import { checkConfig, checkId, checkSecret, checkVersion } from './validation.js'
import { isDefinedVersion, proofVersion } from './versions.js'

declare const verified: unique symbol

/**
 * An object structure that can be converted into an App object.
 */
export interface AppInput {
  id: unknown
  secret: unknown
  version: unknown
  config?: unknown
  [key: string]: unknown
}

/**
 * A no parameter loader function that returns a map that can be converted into
 * an App object.
 */
export type AppLoader = () => AppInput | App
/**
 * A finder function accepting a Proof object parameter that returns an input
 * that can be converted into an App object.
 */
export type AppFinder = (proof: Proof) => AppInput | App
/**
 * A tagged boolean for internal use only. Use {@link App.verify | App.verify()}
 * or {@link App.unverify | App.unverify()}.
 */
export type AppVerified = boolean & { [verified]: never }

/**
 * A no parameter asynchronous loader function that returns a map that can be
 * converted into an App object.
 */
export type AppLoaderAsync = () => Promise<AppInput | App>
/**
 * An asynchronous finder function accepting a Proof object parameter that
 * returns an input that can be converted into an App object.
 */
export type AppFinderAsync = (_proof: Proof) => Promise<AppInput | App>

/**
 * The object type used by the App Identity proof generation and verification
 * algorithms. This should be constructed from a provided object or JSON object,
 * such as a static configuration file or a database record
 *
 * The input object is stored in the {@link source} attribute.
 *
 * App objects are immutable.
 */
export class App {
  /** {@inheritDoc Id} */
  readonly id: Id
  /**
   * An anonymous function closure around the App secret value.
   *
   * @see {@link Secret}
   */
  readonly secret: WrappedSecret
  /** {@inheritDoc Version} */
  readonly version: Version
  /** {@inheritDoc Config} */
  readonly config: Config | null
  /** {@inheritDoc AppInput} */
  readonly source: AppInput | null = null
  /**
   * Indicates whether the app was used in the successful verification of
   * a proof.
   */
  readonly verified: boolean

  /**
   * An asynchronous function to create an App object.
   *
   * @param input - The input used to create the app. An asynchronous loader
   * function may be provided.
   * @returns A new App object.
   *
   * @group Constructors
   */
  static async createAsync(
    input: App | AppInput | AppLoader | AppLoaderAsync,
  ): Promise<App> {
    return new App(typeof input === 'function' ? await input() : input)
  }

  /**
   * Creates a new App object.
   *
   * @param value - The input used to create the app.
   * @param verified - For internal use only. Use {@link verify} or {@link
   * unverify}.
   */
  constructor(value: App | AppInput | AppLoader, verified?: AppVerified) {
    const input = typeof value === 'function' ? value() : value

    const { config, id, secret, v } = {
      config: checkConfig(input.config),
      id: checkId(input.id),
      secret: checkSecret(input.secret),
      v: checkVersion(input.version),
    }

    const version = v.andThen(isDefinedVersion)

    throwErrs([id, secret, version, config], 'App cannot be constructed')

    this.id = id.unwrap()
    this.secret = secret.unwrap()
    this.version = version.unwrap()
    this.config = config.unwrap()

    this.source =
      'source' in input && input.source == null
        ? (input as AppInput)
        : (input.source as AppInput)

    this.verified = !!verified
  }

  /**
   * If the App instance is not {@link verified}, it returns a copy of the App
   * which has {@link verified} set to `true`, otherwise it returns the current
   * instance.
   */
  verify(): App {
    if (this.verified) {
      return this
    }

    return new App(this, true as AppVerified)
  }

  /**
   * If the App instance is {@link verified}, it returns a copy of the App
   * which has {@link verified} set to `false`. otherwise it returns the current
   * instance.
   */
  unverify(): App {
    if (this.verified) {
      return new App(this, false as AppVerified)
    }

    return this
  }

  /**
   * Generate a nonce suitable for this app.
   *
   * @param version - An override value for the instance {@link version}.
   */
  generateNonce(version?: number | Version): Nonce {
    if (version != null) {
      if (this.version > version) {
        throw new AppIdentityError(
          `app version ${this.version} is not compatible with requested version ${version}`,
        )
      }
    }

    const ver = checkVersion(version).unwrapOr(this.version)
    const generator = proofVersion(ver).expect(
      'cannot generate nonce for app',
      AppIdentityError,
    )

    return generator.generateNonce()
  }

  /**
   * @returns A string representation of the App suitable for debugging output.
   */
  toString(): string {
    return `[object App (id: ${this.id}, version: ${
      this.version
    }, config: ${JSON.stringify(this.config, null, 0)}, verified: ${this.verified})]`
  }

  /**
   * @returns A version of the App suitable for serialization to a JSON
   * configuration file. This should *not* be used for debugging purposes as the
   * unwrapped secret value is used, making this an **insecure** operation.
   */
  toAppInput(): object {
    return {
      id: this.id,
      secret: this.secret(),
      config: this.config,
      version: this.version,
    }
  }
}
