import { App } from './app'
import { assertIsNonce, toDisallowed, toVersion } from './validation'
import { Proof } from './proof'

import type {
  AppFinder,
  AppFinderAsync,
  AppInput,
  AppLoader,
  AppLoaderAsync,
} from './app'
import type { Version } from './types'

export const generateProofWithDiagnostic = (
  app: App | AppInput | AppLoader,
  options: {
    nonce?: unknown
    version?: unknown
    disallowed?: unknown
  } = {}
): string => {
  if (!(app instanceof App)) {
    app = new App(app)
  }

  const version: Version = options.version ? toVersion(options.version) : app.version
  let nonce

  if (options.nonce) {
    assertIsNonce(options.nonce)
    nonce = options.nonce
  } else {
    nonce = app.generateNonce(version)
  }

  return Proof.fromApp(app, nonce, {
    version,
    disallowed: toDisallowed(options.disallowed),
  }).toString()
}

export const generateProofWithDiagnosticAsync = async (
  app: App | AppInput | AppLoader | AppLoaderAsync,
  options: {
    nonce?: unknown
    version?: unknown
    disallowed?: unknown
  } = {}
): Promise<string> => {
  if (typeof app === 'function') {
    app = await app()
  }

  return generateProofWithDiagnostic(app, options)
}

export const parseProofWithDiagnostic = (proof: string | Proof): Proof => {
  return proof instanceof Proof ? proof : Proof.fromString(proof)
}

export const verifyProofWithDiagnostic = (
  proof: string | Proof,
  app: AppFinder | App | AppInput,
  options: { disallowed?: unknown } = {}
): App | null => {
  if (!(proof instanceof Proof)) {
    proof = Proof.fromString(proof)
  }

  return proof.verify(app, options)
}

export const verifyProofWithDiagnosticAsync = (
  proof: string | Proof,
  app: App | AppFinder | AppFinderAsync | AppInput,
  options: { disallowed?: unknown } = {}
): Promise<App | null> => {
  if (!(proof instanceof Proof)) {
    proof = Proof.fromString(proof)
  }

  return proof.verifyAsync(app, options)
}
