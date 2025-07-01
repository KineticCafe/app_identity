import type { Result as BaseResult } from '@kineticcafe/result'
import { throwErrs as baseThrowErrors } from '@kineticcafe/result'
import { AppIdentityError } from './app_identity_error.js'

/**
 * AppIdentity always uses string `Err` values.
 *
 * @internal
 */
export type Result<T> = BaseResult<T, string>

/**
 * A specialized version of `throwErrs` for App Identity.
 *
 * @internal
 */
// biome-ignore lint/suspicious/noExplicitAny: insufficient inference
export const throwErrs = <L extends BaseResult<any, any>[]>(
  results: L,
  message?: string,
): void => baseThrowErrors(results, message, AppIdentityError)

export { Err, Ok, unwrapOks } from '@kineticcafe/result'
