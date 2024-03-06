import { AppIdentityError } from './app_identity_error.js'

/**
 * Provides a adapter functions for data encoding and cryptographic primitives.
 *
 * \@kineticcafe/app-identity has been written to work with multiple JavaScript
 * runtimes, and the functions defined in `RuntimeAdapter` are implemented
 * differently depending on the platform.
 *
 * Note that all functions defined on `RuntimeAdapter` are synchronous.
 */
export abstract class RuntimeAdapter {
  /**
   * Decodes a Base64 URL encoded string `value`.
   *
   * @returns the decoded string or `null` or `undefined` on error
   */
  abstract decodeBase64Url(value: string): null | string | undefined
  /**
   * Encodes a string `value` to Base64 URL encoding.
   *
   * @returns the encoded string or `null` or `undefined` on error
   */
  abstract encodeBase64Url(value: string): null | string | undefined

  /**
   * Generates a cryptographically random string suitable for use as an App
   * Identity version 1 random nonce.
   *
   * > Version 1 nonces **should** be cryptographically secure and
   * > non-sequential, but sufficiently fine-grained timestamps (those including
   * > microseconds, as `yyyymmddHHMMSS.sss`) **may** be used. Version 1 proofs
   * > verify that the nonce is at least one byte long and do not contain an
   * > ASCII colon (`:`).
   *
   * It is recommended that random value be at least 16 bytes and encoded.
   * Suitable encodings are hex, Base64 URL, or UUID format.
   */
  abstract randomNonceString(): string

  /**
   * Creates a SHA2-256 digest of the `value` string and returns it as a hex
   * encoded string. Uppercase hex is recommended, but not required.
   */
  abstract sha256(value: string): string

  /**
   * Creates a SHA2-384 digest of the `value` string and returns it as a hex
   * encoded string. Uppercase hex is recommended, but not required.
   */
  abstract sha384(value: string): string

  /**
   * Creates a SHA2-512 digest of the `value` string and returns it as a hex
   * encoded string. Uppercase hex is recommended, but not required.
   */
  abstract sha512(value: string): string
}

let currentRuntimeAdapter: RuntimeAdapter

/**
 * Retrieve the runtime adapter.
 *
 * Raises an exception if a runtime adapter has not been previously set.
 */
export const getRuntimeAdapter = (): RuntimeAdapter => {
  if (currentRuntimeAdapter == null) {
    throw new AppIdentityError('Runtime adapter has not been set')
  }

  return currentRuntimeAdapter
}

/**
 * Sets the runtime adapter.
 *
 * Raises an exception if a runtime adapter has already been set.
 */
export const setRuntimeAdapter = (runtimeAdapter: new () => RuntimeAdapter): void => {
  if (currentRuntimeAdapter != null) {
    throw new AppIdentityError('Runtime adapter has already been set')
  }

  currentRuntimeAdapter = new runtimeAdapter()
}
