import { Info as CoreInfo } from '@kineticcafe/app-identity'

import { name as NAME, version as VERSION } from '../package.json'

import type { AppIdentityVersionInfo as CoreAppIdentityVersionInfo } from '@kineticcafe/app-identity'

/**
 * A summary object describing this version of App Identity node.
 */
export interface AppIdentityVersionInfo extends CoreAppIdentityVersionInfo {
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

  /**
   * The Core App Identity version info.
   */
  readonly core: CoreAppIdentityVersionInfo
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
  spec_version: CoreInfo.spec_version,
  core: CoreInfo,
})

export {
  App,
  AppIdentityError,
  Proof,
  Validations,
  Versions,
  allowVersion,
  disallowVersion,
  generateProof,
  generateProofAsync,
  generateProofWithDiagnostic,
  generateProofWithDiagnosticAsync,
  getRuntimeAdapter,
  parseProof,
  parseProofWithDiagnostic,
  verifyProof,
  verifyProofAsync,
  verifyProofWithDiagnostic,
  verifyProofWithDiagnosticAsync,
} from '@kineticcafe/app-identity'

export type {
  AppFinder,
  AppFinderAsync,
  AppInput,
  AppLoader,
  AppLoaderAsync,
  AppVerified,
  Config,
  Disallowed,
  Fuzz,
  Id,
  Nonce,
  Padlock,
  Secret,
  Version,
  WrappedSecret,
} from '@kineticcafe/app-identity'

export { useNodeRuntimeAdapter } from './adapter.js'
