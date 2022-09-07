/**
 * `@kineticcafe/app-identity is a TypeScript implementation of the Kinetic
 * Commerce application [identity proof algorithm][spec].
 *
 * It implements identity proof generation and validation functions. These
 * functions expect to work with an application object ({@link App}).
 *
 * [spec]: https://github.com/KineticCafe/app-identity/blob/main/spec/README.md
 */

import {
  generateProofWithDiagnostic,
  generateProofWithDiagnosticAsync,
  parseProofWithDiagnostic,
  verifyProofWithDiagnostic,
  verifyProofWithDiagnosticAsync,
} from './internal'

import type {
  App,
  AppFinder,
  AppFinderAsync,
  AppInput,
  AppLoader,
  AppLoaderAsync,
} from './app'
import type { Proof } from './proof'
import type { Disallowed, Nonce, Version } from './types'

import { name as NAME, version as VERSION } from '../package.json'

/**
 * Generate an identity proof string for the given application.
 *
 * ### Examples
 *
 * A version 1 app can have a fixed nonce, which will always produce the same
 * value.
 *
 * ```javascript
 * v1 = {id: "decaf", secret: "bad", version: 1}
 * proof = AppIdentity.generateProof(v1, { nonce: "hello"})
 * // => "ZGVjYWY6aGVsbG86RDNGNjJCQTYyOEIyMzhEOTgwM0MyNEU4NkNCOTY3M0ZEOTVCNTdBNkJGOTRFMkQ2NTMxQTRBODg1OTlCMzgzNQ=="
 * ```
 *
 * A version 2 app fails when given a non-timestamp nonce.
 *
 * ```javascript
 * AppIdentity.generateProof(v1, { version: 2, nonce: "hello" })
 * // => null
 * ```
 *
 * A version 2 app _cannot_ generate a version 1 nonce.
 *
 * ```javascript
 * AppIdentity.generateProof({ ...v1, version: 2}, { version: 1, nonce: "hello" })
 * // => null
 * ```
 *
 * A version 2 app will be rejected if the version has been disallowed.
 *
 * ```javascript
 * AppIdentity.generateProof({ ...v1, version: 2}, { disallowed: [1, 2] })
 * // => null
 * ```
 *
 * @param app - The application for which the proof will be generated.
 * @param options.nonce - An optional nonce value . If provided, it will be
 * validated as conforming ot the shape expected by the proof version to be
 * generated. If not provided, it will be generated.
 * @param options.version - An optional algorithm version that allows an app to
 * generate a more secure proof.
 * @param options.disallowed - An optional list of algorithm versions not
 * allowed for this operation.
 * @returns The generated proof string or `null`.
 */
export const generateProof = (
  app: App | AppInput | AppLoader,
  options: {
    nonce?: string | Nonce
    version?: string | number | Version
    disallowed?: number[] | Version[] | Disallowed
  } = {}
): string | null => {
  try {
    return generateProofWithDiagnostic(app, options)
  } catch (_) {
    return null
  }
}

/**
 * Parses a proof string into an AppIdentity.Proof object. Returns the parsed
 * proof or `null`.
 *
 * @param proof - A proof string or proof object.
 */
export const parseProof = (proof: string | Proof): Proof | null => {
  try {
    return parseProofWithDiagnostic(proof)
  } catch (_) {
    return null
  }
}

/**
 * Verify an App Identity proof value using a provided {@link App}.
 *
 * @param proof - The proof value to verify, which may be provided either as
 * a string or a parsed {@link Proof} (from {@link parseProof}). String proof
 * values are usually obtained from HTTP headers. At Kinetic Commerce, this has
 * generally been `KCS-Application` or `KCS-Service`.
 * @param app - The application with which to verify the proof. If an {@link
 * AppFinder} function is provided, it will be called with the parsed {@link
 * Proof} value.
 * @param options.disallowed - An optional list of algorithm versions not
 * allowed for this operation.
 *
 * @returns The verified {@link App} or `null`
 */
export const verifyProof = (
  proof: string | Proof,
  app: App | AppFinder | AppInput,
  options: { disallowed?: number[] | Version[] | Disallowed } = {}
): App | null => {
  try {
    return verifyProofWithDiagnostic(proof, app, options)
  } catch (_) {
    return null
  }
}

/**
 * Generate an identity proof string for the given application. This is an
 * asynchronous version of {@link generateProof}.
 *
 * If `nonce` is provided, it must conform to the shape expected by the proof
 * version. If not provided, it will be generated.
 *
 * If `version` is provided, it will be used to generate the nonce and the
 * proof. This will allow a lower level application to raise its version level.
 *
 * ### Examples
 *
 * A version 1 app can have a fixed nonce, which will always produce the same
 * value.
 *
 *
 * ```javascript
 * v1 = {id: "decaf", secret: "bad", version: 1}
 * proof = await AppIdentity.generateProofAsync(v1, { nonce: "hello"})
 * // => "ZGVjYWY6aGVsbG86RDNGNjJCQTYyOEIyMzhEOTgwM0MyNEU4NkNCOTY3M0ZEOTVCNTdBNkJGOTRFMkQ2NTMxQTRBODg1OTlCMzgzNQ=="
 * ```
 *
 * A version 2 app fails when given a non-timestamp nonce.
 *
 * ```javascript
 * await AppIdentity.generateProofAsync(v1, { version: 2, nonce: "hello" })
 * // => null
 * ```
 *
 * A version 2 app _cannot_ generate a version 1 nonce.
 *
 * ```javascript
 * await AppIdentity.generateProofAsync({ ...v1, version: 2}, { version: 1, nonce: "hello" })
 * // => null
 * ```
 *
 * A version 2 app will be rejected if the version has been disallowed.
 *
 * ```javascript
 * await AppIdentity.generateProofAsync({ ...v1, version: 2}, { disallowed: [1, 2] })
 * // => null
 * ```
 *
 * @param app - The application for which the proof will be generated.
 * @param options.nonce - An optional nonce value . If provided, it will be
 * validated as conforming ot the shape expected by the proof version to be
 * generated. If not provided, it will be generated.
 * @param options.version - An optional algorithm version that allows an app to
 * generate a more secure proof.
 * @param options.disallowed - An optional list of algorithm versions not
 * allowed for this operation.
 * @returns A promise for the generated proof string or `null`.
 */
export const generateProofAsync = (
  app: App | AppInput | AppLoader | AppLoaderAsync,
  options: {
    nonce?: string | Nonce
    version?: string | number | Version
    disallowed?: number[] | Version[] | Disallowed
  } = {}
): Promise<string | null> => {
  try {
    return generateProofWithDiagnosticAsync(app, options)
  } catch (_) {
    return Promise.resolve(null)
  }
}

/**
 * An Verify an App Identity proof value using a provided {@link App}.
 * An asynchronous version of {@link verifyProof}.
 *
 * @param proof - The proof value to verify, which may be provided either as
 * a string or a parsed {@link Proof} (from {@link parseProof}). String proof
 * values are usually obtained from HTTP headers. At Kinetic Commerce, this has
 * generally been `KCS-Application` or `KCS-Service`.
 * @param app - The application with which to verify the proof. If an {@link
 * AppFinder} or {@link AppFinderAsync} function is provided, it will be called
 * with the parsed {@link Proof} value.
 * @param options.disallowed - An optional list of algorithm versions not
 * allowed for this operation.
 *
 * @returns A promise for the verified {@link App} or `null`
 */
export const verifyProofAsync = (
  proof: string | Proof,
  app: App | AppFinder | AppFinderAsync | AppInput,
  options: { disallowed?: number[] | Version[] | Disallowed } = {}
): Promise<App | null> => {
  try {
    return verifyProofWithDiagnosticAsync(proof, app, options)
  } catch (_) {
    return Promise.resolve(null)
  }
}

export * from './app'
export * from './types'
export * from './proof'
export { allowVersion, disallowVersion } from './versions'

/**
 * A summary object describing this version of App Identity for Node.js.
 */
export type AppIdentityVersionInfo = {
  /**
   * The name of the App Identity implementation. From the package name.
   */
  readonly name: string
  /**
   * The version of the App Identity implementation. From the package version.
   */
  readonly version: string
  /**
   * The supported major specification version. Must be an integer value.
   */
  readonly spec_version: number
}

/**
 * The name, version, and supported specification version of this App Identity
 * package for Node.js.
 *
 * This value is immutable.
 */
export const Info: AppIdentityVersionInfo = Object.freeze({
  name: NAME as string,
  version: VERSION as string,
  spec_version: 4,
})
