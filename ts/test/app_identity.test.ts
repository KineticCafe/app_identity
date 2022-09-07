import base64url from 'base64-url'
import { expect, test } from 'vitest'

import { App } from '../src/app'
import { generateProofWithDiagnostic, verifyProofWithDiagnostic } from '../src/internal'
import * as Support from '../support'

import '../support/matchers'

test('generate v1 proof', () => {
  const proof = generateProofWithDiagnostic(Support.v1Input())
  expect(Support.decodeToParts(proof).length).toEqual(3)
})

test('generate valid v1 proof', () => {
  const v1 = Support.v1Input()
  const app = new App(v1)

  const proof = generateProofWithDiagnostic(v1)
  expect(verifyProofWithDiagnostic(proof, v1)).toBeVerified(app)
})

test('generate v2 proof', () => {
  const proof = generateProofWithDiagnostic(Support.v2Input())
  expect(Support.decodeToParts(proof).length).toEqual(4)
})

test('generate valid v2 proof', () => {
  const v2 = Support.v2Input()
  const app = new App(v2)

  const proof = generateProofWithDiagnostic(v2)
  expect(verifyProofWithDiagnostic(proof, v2)).toBeVerified(app)
})

test('generate valid v3 proof', () => {
  const v3 = Support.v3Input()
  const app = new App(v3)

  const proof = generateProofWithDiagnostic(v3)
  expect(verifyProofWithDiagnostic(proof, v3)).toBeVerified(app)
})

test('generate valid v4 proof', () => {
  const v4 = Support.v4Input()
  const app = new App(v4)

  const proof = generateProofWithDiagnostic(v4)
  expect(verifyProofWithDiagnostic(proof, v4)).toBeVerified(app)
})

test('verify fails if not base64', () => {
  expect(() => verifyProofWithDiagnostic('not base64', Support.v1Input())).toThrowError(
    'proof must have 3 parts (version 1) or 4 parts (any version)'
  )
})

test('verify fail on insufficient parts', () => {
  expect(() =>
    verifyProofWithDiagnostic(base64url.encode('a:b'), Support.v1Input())
  ).toThrowError('proof must have 3 parts (version 1) or 4 parts (any version)')
})

test('verify fail on bad v1 nonce', () => {
  const v1 = Support.v1Input()
  const app = new App(v1)
  const padlock = Support.buildPadlock(app, { nonce: 'n:once' })
  const proof = Support.buildProof(app, padlock, { nonce: 'n:once' })

  expect(() => verifyProofWithDiagnostic(proof, v1)).toThrowError(
    'version cannot be converted to an integer'
  )
})

test('verify fail on bad v2 nonce format', () => {
  const v1 = Support.v1Input()
  const app = new App(v1)
  const padlock = Support.buildPadlock(app)
  const proof = Support.buildProof(app, padlock, { version: 2 })

  expect(() => verifyProofWithDiagnostic(proof, v1)).toThrowError(
    'nonce does not look like a timestamp'
  )
})

test('verify fail on v2 nonce out of fuzz', () => {
  const v1 = Support.v1Input()
  const app = new App(v1)
  const nonce = Support.timestampNonce(-11, 'minutes')
  const padlock = Support.buildPadlock(app, { nonce })
  const proof = Support.buildProof(app, padlock, { version: 2, nonce })

  expect(() => verifyProofWithDiagnostic(proof, v1)).toThrowError('nonce is invalid')
})

test('verify fail on v1 nonce for v2 app', () => {
  const v2 = Support.v2Input()
  const app = new App(v2)
  const padlock = Support.buildPadlock(app, { version: 1 })
  const proof = Support.buildProof(app, padlock, { version: 1 })

  expect(() => verifyProofWithDiagnostic(proof, v2)).toThrowError(
    'proof and app version mismatch'
  )
})

test('verify success v1', () => {
  const v1 = Support.v1Input()
  const app = new App(v1)
  const padlock = Support.buildPadlock(app)
  const proof = Support.buildProof(app, padlock)

  expect(verifyProofWithDiagnostic(proof, v1)).toBeVerified(app)
})

test('verify success v2 default fuzz', () => {
  const v2 = Support.v2Input()
  const app = new App(v2)
  const nonce = Support.timestampNonce(-6, 'minutes')
  const padlock = Support.buildPadlock(app, { nonce })
  const proof = Support.buildProof(app, padlock, { nonce })
  expect(verifyProofWithDiagnostic(proof, v2)).toBeVerified(app)
})

test('verify success v2 custom fuzz', () => {
  const v2 = Support.v2Input(300)
  const app = new App(v2)
  const nonce = Support.timestampNonce(-2, 'minutes')
  const padlock = Support.buildPadlock(app, { nonce })
  const proof = Support.buildProof(app, padlock, { nonce })

  expect(verifyProofWithDiagnostic(proof, v2)).toBeVerified(app)
})

test('verify fail on different app ids', () => {
  const v1 = Support.v1Input()
  const app = new App(v1)
  const id = '00000000-0000-0000-0000-000000000000'
  const padlock = Support.buildPadlock(app, { id })
  const proof = Support.buildProof(app, padlock, { id })

  expect(() => verifyProofWithDiagnostic(proof, v1)).toThrowError(
    'proof and app do not match'
  )
})

test('verify fail on bad padlock', () => {
  const v1 = Support.v1Input()
  const app = new App(v1)
  const padlock = Support.buildPadlock(app, { nonce: 'foo' })
  const proof = Support.buildProof(app, padlock)

  expect(verifyProofWithDiagnostic(proof, v1)).toBeNull()
})
