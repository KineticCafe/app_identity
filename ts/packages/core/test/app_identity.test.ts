import { describe, expect, test } from 'vitest'

import { App, type AppInput } from '../src/app.js'
import {
  generateProof,
  generateProofAsync,
  parseProof,
  verifyProof,
  verifyProofAsync,
} from '../src/index.js'
import {
  generateProofWithDiagnostic,
  generateProofWithDiagnosticAsync,
  parseProofWithDiagnostic,
  verifyProofWithDiagnostic,
} from '../src/internal.js'
import { Proof } from '../src/proof.js'

import * as Support from './support/index.js'
import './support/matchers.js'

const loader = (input: App | AppInput) => () => input
const asyncLoader = (input: App | AppInput) => async () => input
const finder = (input: App | AppInput) => (_: Proof) => input
const asyncFinder = (input: App | AppInput) => async (_: Proof) => input

describe('generateProof', () => {
  describe('v1', () => {
    test('success: direct input', () => {
      const proof = generateProof(Support.v1Input()) || ''
      expect(Support.decodeToParts(proof).length).toEqual(3)
    })

    test('success: direct app', async () => {
      const proof = (await generateProofAsync(new App(Support.v1Input()))) || ''
      expect(Support.decodeToParts(proof).length).toEqual(3)
    })

    test('success: loader', () => {
      const proof = generateProofWithDiagnostic(loader(Support.v1Input()))
      expect(Support.decodeToParts(proof).length).toEqual(3)
    })

    test('success: async loader', async () => {
      const proof = await generateProofWithDiagnosticAsync(asyncLoader(Support.v1Input()))
      expect(Support.decodeToParts(proof).length).toEqual(3)
    })

    test('success: async direct input', async () => {
      const proof = await generateProofWithDiagnosticAsync(Support.v1Input())
      expect(Support.decodeToParts(proof).length).toEqual(3)
    })

    test('success: self-validates', () => {
      const v1 = Support.v1Input()
      const app = new App(v1)
      const proof = generateProofWithDiagnostic(v1)
      expect(verifyProofWithDiagnostic(proof, v1)).toBeVerified(app)
    })

    test('fail: invalid app', () => {
      expect(generateProof({ ...Support.v1Input(), id: null })).toBeNull()
    })

    test('fail: invalid app (async)', async () => {
      expect(await generateProofAsync({ ...Support.v1Input(), id: null })).toBeNull()
    })

    test('fail: v1 apps disallowed', () => {
      expect(() =>
        generateProofWithDiagnostic(Support.v1Input, { disallowed: [1] }),
      ).toThrowError('version 1 is not allowed')
    })

    test('fail: v1 apps (invalid disallowed)', () => {
      expect(() =>
        generateProofWithDiagnostic(Support.v1Input, { disallowed: 1 }),
      ).toThrowError('disallowed must be an array of versions')
    })

    test('fail: v1 apps (invalid disallowed version)', () => {
      expect(() =>
        generateProofWithDiagnostic(Support.v1Input, { disallowed: [-1] }),
      ).toThrowError('version must be')
    })
  })

  describe('v2', () => {
    test('success: direct', () => {
      const proof = generateProofWithDiagnostic(Support.v2Input())

      expect(Support.decodeToParts(proof).length).toEqual(4)
    })

    test('success: self-validates', () => {
      const v2 = Support.v2Input()
      const app = new App(v2)

      const proof = generateProofWithDiagnostic(v2)
      expect(verifyProofWithDiagnostic(proof, v2)).toBeVerified(app)
    })
  })

  describe('v3', () => {
    test('success: self-validates', () => {
      const v3 = Support.v3Input()
      const app = new App(v3)

      const proof = generateProofWithDiagnostic(v3)
      expect(verifyProofWithDiagnostic(proof, v3)).toBeVerified(app)
    })
  })

  describe('v4', () => {
    test('success: self-validates', () => {
      const v4 = Support.v4Input()
      const app = new App(v4)

      const proof = generateProofWithDiagnostic(v4)
      expect(verifyProofWithDiagnostic(proof, v4)).toBeVerified(app)
    })
  })
})

describe('parseProof', () => {
  test('parse a v1 proof correctly', () => {
    const proof = generateProofWithDiagnostic(Support.v1Input())
    const parsed = parseProofWithDiagnostic(proof)
    const parts = Support.decodeToParts(proof)

    expect(parsed).toBeInstanceOf(Proof)
    expect(parsed).toMatchObject({
      id: parts[0],
      nonce: parts[1],
      padlock: parts[2],
      version: 1,
    })
  })

  test('does not reparse', () => {
    const proof = generateProofWithDiagnostic(Support.v1Input())
    const parsed = parseProof(proof) || ''
    expect(parsed).not.toBeNull()
    expect(parseProof(parsed)).toBe(parsed)
  })

  test('does not parse a bad proof', () => {
    const v1 = Support.v1Input()
    const app = new App(v1)
    const padlock = Support.buildPadlock(app, { nonce: 'n:once' })
    const proof = Support.buildProof(app, padlock, { nonce: 'n:once' })

    expect(parseProof(proof)).toBeNull()
  })

  test('parse a v2 proof correctly', () => {
    const proof = generateProofWithDiagnostic(Support.v2Input())
    const parsed = parseProofWithDiagnostic(proof)
    const parts = Support.decodeToParts(proof)

    expect(parsed).toBeInstanceOf(Proof)
    expect(parsed).toMatchObject({
      id: parts[1],
      nonce: parts[2],
      padlock: parts[3],
      version: Number.parseInt(parts[0], 10),
    })
  })

  test('parse a v3 proof correctly', () => {
    const proof = generateProofWithDiagnostic(Support.v3Input())
    const parsed = parseProofWithDiagnostic(proof)
    const parts = Support.decodeToParts(proof)

    expect(parsed).toBeInstanceOf(Proof)
    expect(parsed).toMatchObject({
      id: parts[1],
      nonce: parts[2],
      padlock: parts[3],
      version: Number.parseInt(parts[0], 10),
    })
  })

  test('parse a v4 proof correctly', () => {
    const proof = generateProofWithDiagnostic(Support.v4Input())
    const parsed = parseProofWithDiagnostic(proof)
    const parts = Support.decodeToParts(proof)

    expect(parsed).toBeInstanceOf(Proof)
    expect(parsed).toMatchObject({
      id: parts[1],
      nonce: parts[2],
      padlock: parts[3],
      version: Number.parseInt(parts[0], 10),
    })
  })
})

describe('verifyProof', () => {
  describe('invalid proof types', () => {
    test('proof is not base64', () => {
      expect(() =>
        verifyProofWithDiagnostic('not base64', Support.v1Input()),
      ).toThrowError('proof must have 3 parts (version 1) or 4 parts (any version)')
    })

    test('proof does not have enough parts', () => {
      expect(verifyProof(Support.encodeBase64Url('a:b'), Support.v1Input())).toBeNull()
    })

    test('proof version is not a number', () => {
      expect(() =>
        verifyProofWithDiagnostic(Support.encodeBase64Url('a:b:c:d'), Support.v1Input()),
      ).toThrowError('version cannot be converted to an integer')
    })
  })

  describe('invalid nonce values', () => {
    test('bad v1 nonce', () => {
      const v1 = Support.v1Input()
      const app = new App(v1)
      const padlock = Support.buildPadlock(app, { nonce: 'n:once' })
      const proof = Support.buildProof(app, padlock, { nonce: 'n:once' })

      expect(() => verifyProofWithDiagnostic(proof, v1)).toThrowError(
        'version cannot be converted to an integer',
      )
    })

    test('bad v1 nonce (async)', async () => {
      const v1 = Support.v1Input()
      const app = new App(v1)
      const padlock = Support.buildPadlock(app, { nonce: 'n:once' })
      const proof = Support.buildProof(app, padlock, { nonce: 'n:once' })

      expect(await verifyProofAsync(proof, v1)).toBeNull()
    })

    test('bad v2+ nonce (non-timestamp)', () => {
      const v1 = Support.v1Input()
      const app = new App(v1)
      const padlock = Support.buildPadlock(app)
      const proof = Support.buildProof(app, padlock, { version: 2 })

      expect(() => verifyProofWithDiagnostic(proof, v1)).toThrowError(
        'nonce does not look like a timestamp',
      )
    })

    test('v2+ nonce out of fuzz range', () => {
      const v1 = Support.v1Input()
      const app = new App(v1)
      const nonce = Support.timestampNonce(-11, 'minutes')
      const padlock = Support.buildPadlock(app, { nonce })
      const proof = Support.buildProof(app, padlock, { version: 4, nonce })

      expect(() => verifyProofWithDiagnostic(proof, v1)).toThrowError('nonce is invalid')
    })

    test('v1 nonce provided for v2+ app', () => {
      const v3 = Support.v2Input()
      const app = new App(v3)
      const padlock = Support.buildPadlock(app, { version: 1 })
      const proof = Support.buildProof(app, padlock, { version: 1 })

      expect(() => verifyProofWithDiagnostic(proof, v3)).toThrowError(
        'proof and app version mismatch',
      )
    })
  })

  describe('v1 success', () => {
    test('with pre-parsed proof', () => {
      const v1 = Support.v1Input()
      const app = new App(v1)
      const padlock = Support.buildPadlock(app)
      const proof = Support.buildProof(app, padlock)
      const parsed = parseProof(proof) || ''

      expect(verifyProof(parsed, v1)).toBeVerified(app)
    })

    test('lowercase proof', () => {
      const v1 = Support.v1Input()
      const app = new App(v1)
      const padlock = Support.buildPadlock(app, { case: 'lower' })
      const proof = Support.buildProof(app, padlock)

      expect(verifyProof(proof, v1)).toBeVerified(app)
    })
  })

  describe('v2+ success', () => {
    test('default fuzz', () => {
      const v2 = Support.v2Input()
      const app = new App(v2)
      const nonce = Support.timestampNonce(-6, 'minutes')
      const padlock = Support.buildPadlock(app, { nonce })
      const proof = Support.buildProof(app, padlock, { nonce })
      expect(verifyProof(proof, v2)).toBeVerified(app)
    })

    test('custom fuzz', () => {
      const v2 = Support.v2Input(300)
      const app = new App(v2)
      const nonce = Support.timestampNonce(-2, 'minutes')
      const padlock = Support.buildPadlock(app, { nonce })
      const proof = Support.buildProof(app, padlock, { nonce })

      expect(verifyProof(proof, finder(v2))).toBeVerified(app)
    })

    test('default fuzz (lowercase proof)', async () => {
      const v3 = Support.v3Input()
      const app = new App(v3)
      const nonce = Support.timestampNonce(-6, 'minutes')
      const padlock = Support.buildPadlock(app, { nonce })
      const proof = Support.buildProof(app, padlock, { nonce, case: 'lower' })
      const parsed = parseProof(proof) || ''

      expect(await verifyProofAsync(parsed, asyncFinder(v3))).toBeVerified(app)
    })

    test('custom fuzz (lowercase proof)', async () => {
      const v2 = Support.v2Input(300)
      const app = new App(v2)
      const nonce = Support.timestampNonce(-2, 'minutes')
      const padlock = Support.buildPadlock(app, { nonce })
      const proof = Support.buildProof(app, padlock, { nonce, case: 'lower' })

      expect(await verifyProofAsync(proof, v2)).toBeVerified(app)
    })
  })

  test('verify fail on different app ids', () => {
    const v1 = Support.v1Input()
    const app = new App(v1)
    const id = '00000000-0000-0000-0000-000000000000'
    const padlock = Support.buildPadlock(app, { id })
    const proof = Support.buildProof(app, padlock, { id })

    expect(() => verifyProofWithDiagnostic(proof, v1)).toThrowError(
      'proof and app do not match',
    )
  })

  test('verify fail on bad padlock', () => {
    const v1 = Support.v1Input()
    const app = new App(v1)
    const padlock = Support.buildPadlock(app, { nonce: 'foo' })
    const proof = Support.buildProof(app, padlock)

    expect(verifyProofWithDiagnostic(proof, v1)).toBeNull()
  })

  test('verify fail on non-hex padlock', () => {
    const v1 = Support.v1Input()
    const app = new App(v1)
    const padlock = Support.buildPadlock(app, { nonce: 'foo' }).replace(/[A-F]/gi, 'z')
    const proof = Support.buildProof(app, padlock)

    expect(verifyProof(proof, v1)).toBeNull()
  })
})
