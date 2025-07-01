import type {
  AppFinder,
  AppFinderAsync,
  AppInput,
  AppLoader,
  AppLoaderAsync,
} from './app.js'
import { App } from './app.js'
import { AppIdentityError } from './app_identity_error.js'
import { Proof } from './proof.js'
import { checkDisallowed, checkNonce, checkVersion } from './validation.js'

/** @internal */
export const generateProofWithDiagnostic = (
  input: App | AppInput | AppLoader,
  options: {
    nonce?: unknown
    version?: unknown
    disallowed?: unknown
  } = {},
): string => {
  const app = input instanceof App ? input : new App(input)
  const version = checkVersion(options.version).unwrapOr(app.version)
  const nonce = checkNonce(options.nonce).unwrapOrElse(() => app.generateNonce(version))
  const disallowed = checkDisallowed(options.disallowed).expect(
    'invalid options.disallowed',
    AppIdentityError,
  )

  return Proof.fromApp(app, nonce, { disallowed, version }).toString()
}

/** @internal */
export const generateProofWithDiagnosticAsync = async (
  app: App | AppInput | AppLoader | AppLoaderAsync,
  options: {
    nonce?: unknown
    version?: unknown
    disallowed?: unknown
  } = {},
): Promise<string> => {
  return generateProofWithDiagnostic(
    typeof app === 'function' ? await app() : app,
    options,
  )
}

/** @internal */
export const parseProofWithDiagnostic = (proof: string | Proof): Proof => {
  return proof instanceof Proof ? proof : Proof.fromString(proof)
}

/** @internal */
export const verifyProofWithDiagnostic = (
  input: string | Proof,
  app: AppFinder | App | AppInput,
  options: { disallowed?: unknown } = {},
): App | null => {
  const proof = input instanceof Proof ? input : Proof.fromString(input)

  return proof.verify(app, options)
}

/** @internal */
export const verifyProofWithDiagnosticAsync = (
  input: string | Proof,
  app: App | AppFinder | AppFinderAsync | AppInput,
  options: { disallowed?: unknown } = {},
): Promise<App | null> => {
  const proof = input instanceof Proof ? input : Proof.fromString(input)

  return proof.verifyAsync(app, options)
}
