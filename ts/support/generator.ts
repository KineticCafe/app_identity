import fs from 'fs'
import { join as joinPath } from 'path'

import type { Command } from 'commander'

import required from './required.json'
import optional from './optional.json'

import { App } from '../src/app'
import { Info } from '../src'
import { generateProofWithDiagnostic } from '../src/internal'
import { toVersion } from '../src/validation'
import * as Support from './index'

import type { Expect, Suite, Test } from './schema'

type Jsonish = Record<string, unknown>

type TestInputApp = {
  config?: { fuzz: number }
  version: number
}

type TestInputNonce = {
  empty?: boolean
  offset_minutes?: number
  value?: string
}

type TestInputPadlock =
  | {
      nonce?: string
      case?: 'random' | 'upper' | 'lower'
      type: 'build'
    }
  | {
      value: string
      type: 'value'
    }

type TestInputProof = {
  id?: string
  secret?: string
  version: number
}

type TestInput = {
  app?: TestInputApp
  description: string
  spec_version: number
  expect: Expect
  nonce?: TestInputNonce
  padlock?: TestInputPadlock
  proof: TestInputProof
}
/* eslint-disable no-unused-vars,@typescript-eslint/no-unused-vars */
export const generator = (
  program: Command
): ((suiteName: string, options: { quiet: boolean; stdout: boolean }) => void) => {
  /* eslint-enable no-unused-vars,@typescript-eslint/no-unused-vars */
  return (suiteName: string, options: { quiet: boolean; stdout: boolean }): void => {
    try {
      if (!options.stdout && !suiteName.endsWith('.json')) {
        if (fs.statSync(suiteName).isDirectory()) {
          suiteName = joinPath(suiteName, 'app-identity-suite-ts.json')
        } else {
          suiteName = `${suiteName}.json`
        }
      }

      const suite = generateSuite()

      if (suite === null) {
        program.error('Error generating suite')
      }

      if (!options.quiet && !options.stdout) {
        console.log(
          `Generated ${suite.tests.length} tests for ${suite.name} ${suite.version}.`
        )
      }

      if (options.stdout) {
        console.log(JSON.stringify(suite, null, 2))
      } else {
        fs.writeFileSync(suiteName, JSON.stringify(suite))
        if (!options.quiet) {
          console.log(`Saved as ${suiteName}`)
        }
      }
    } catch (e) {
      if (e instanceof Error) {
        program.error(e.message + '\n' + e.stack)
      } else {
        program.error('Unknown error not involving an exception')
      }
    }
  }
}

const generateSuite = (): null | Suite => {
  return {
    name: Info.name,
    version: Info.version,
    spec_version: Info.spec_version,
    tests: [
      ...generateTests('required', required),
      ...generateTests('optional', optional),
    ],
  }
}

type InputType = 'required' | 'optional'

const generateTests = (type: InputType, input: Array<Jsonish>): Array<Test> =>
  input.map((input: Jsonish, index: number) => generateTest(type, input, index))

const generateTest = (type: InputType, input: Jsonish, index: number): Test => {
  const normalized = normalizeTest(type, input, index)

  const app: App = normalized.app
    ? Support.app(normalized.app.version, normalized.app.config?.fuzz)
    : Support.app(1)

  const proof = makeProof(type, normalized, index, app)

  if (proof === undefined) {
    throw new Error('Proof is undefined: this should be impossible')
  }

  return {
    description: normalized.description,
    expect: normalized.expect,
    app: { ...app, secret: app.secret() },
    proof,
    required: type == 'required',
    spec_version: normalized.spec_version,
  }
}

const makeProof = (
  type: InputType,
  input: TestInput,
  index: number,
  app: App
): string | void => {
  try {
    let nonce: null | string | typeof Support.EMPTY_NONCE = null
    const version = toVersion(input.proof.version)

    if (input.nonce) {
      if (input.nonce.empty) {
        nonce = Support.EMPTY_NONCE
      } else if (input.nonce.offset_minutes) {
        nonce = Support.timestampNonce(input.nonce.offset_minutes)
      } else if (input.nonce.value) {
        nonce = input.nonce.value
      }
    } else {
      nonce = app.generateNonce(version) as string
    }

    if (input.padlock?.type === 'value') {
      return Support.buildProof(app, input.padlock.value, {
        id: input.proof.id,
        nonce,
        secret: input.proof.secret,
        version: input.proof.version,
      })
    }

    if (input.padlock?.type === 'build') {
      const padlock = Support.buildPadlock(app, {
        id: input.proof.id,
        nonce: input.padlock.nonce || nonce,
        secret: input.proof.secret,
        version: input.proof.version,
        case: input.padlock.case || 'random',
      })

      return Support.buildProof(app, padlock, {
        id: input.proof.id,
        nonce,
        secret: input.proof.secret,
        version: input.proof.version,
      })
    }

    if (input.proof.id || input.proof.secret || input.nonce) {
      const padlock = Support.buildPadlock(app, {
        id: input.proof.id,
        nonce,
        secret: input.proof.secret,
        version: input.proof.version,
        case: 'random',
      })

      return Support.buildProof(app, padlock, {
        id: input.proof.id,
        nonce,
        secret: input.proof.secret,
        version: input.proof.version,
      })
    } else if (nonce === Support.EMPTY_NONCE) {
      throw 'Unreachable nonce error was somehow reached'
    }

    return generateProofWithDiagnostic(app, { nonce, version })
  } catch (e) {
    fail(type, input, index, e instanceof Error ? e.message : 'UNKNOWN ERROR')
  }
}

const normalizeTest = (type: InputType, input: Jsonish, index: number): TestInput => {
  mustHave(type, input, index, 'description')
  mustHave(type, input, index, 'expect')
  mustHave(type, input, index, 'proof')
  mustHave(type, input, index, 'spec_version')

  if (input['expect'] !== 'pass' && input['expect'] !== 'fail') {
    throw fail(type, input, index, `Invalid expect value '${input['expect']}'`)
  }

  let output: Partial<TestInput> = {
    description: input['description'] as string,
    expect: input['expect'] as Expect,
    spec_version: input['spec_version'] as number,
  }

  output = normalizeApp(output, input, type, index)
  output = normalizeNonce(output, input, type, index)
  output = normalizePadlock(output, input, type, index)
  return normalizeProof(output, input, type, index) as TestInput
}

const normalizeApp = (
  output: Partial<TestInput>,
  input: Jsonish,
  type: InputType,
  index: number
): Partial<TestInput> => {
  if (!has(input, 'app')) {
    return output
  }

  const app = input['app'] as Jsonish

  mustHave(type, app, index, 'version', { input, name: 'app.version' })

  const newApp: Partial<TestInputApp> = {
    version: app['version'] as number,
  }

  if (has(app, 'config')) {
    const appConfig = app['config'] as Jsonish
    mustHave(type, appConfig, index, 'fuzz', { input, name: 'app.config.fuzz' })
    newApp.config = { fuzz: appConfig['fuzz'] as number }
  }

  return {
    ...output,
    app: newApp as TestInputApp,
  }
}

const normalizeNonce = (
  output: Partial<TestInput>,
  input: Jsonish,
  type: InputType,
  index: number
): Partial<TestInput> => {
  if (!has(input, 'nonce')) {
    return output
  }

  const newNonce: Partial<TestInputNonce> = {}
  const nonce = input['nonce'] as Jsonish

  if (has(nonce, 'empty')) {
    if (has(nonce, 'offset_minutes') || has(nonce, 'value')) {
      throw fail(type, input, index, 'nonce must only have one sub-key')
    }

    if (nonce['empty'] === true || nonce['empty'] === 'true') {
      return { ...output, nonce: { empty: true } }
    }

    throw fail(type, input, index, 'nonce.empty may only be true')
  }

  if (has(nonce, 'offset_minutes')) {
    if (has(nonce, 'value')) {
      throw fail(type, input, index, 'nonce must only have one sub-key')
    }

    const value = nonce['offset_minutes']

    if (Number.isInteger(value)) {
      return { ...output, nonce: { offset_minutes: value as number } }
    }

    throw fail(type, input, index, 'nonce.offset_minutes must be an integer')
  }

  if (has(nonce, 'value')) {
    return { ...output, nonce: { value: nonce['value'] as string } }
  }

  throw fail(type, input, index, 'nonce requires exactly one sub-key')
}

const normalizePadlock = (
  output: Partial<TestInput>,
  input: Jsonish,
  type: InputType,
  index: number
): Partial<TestInput> => {
  if (!has(input, 'padlock')) {
    return output
  }

  const padlock = input['padlock'] as Jsonish

  if (Object.keys(padlock).length === 0) {
    throw fail(
      type,
      input,
      index,
      'padlock must have at least one sub-key: value, nonce, or case'
    )
  }

  if (has(padlock, 'value')) {
    if (Object.keys(padlock).length > 1) {
      throw fail(
        type,
        input,
        index,
        'padlock.value must not have any other sub-keys specified'
      )
    }

    if (padlock['value'] == null || padlock['value'] === '') {
      throw fail(type, input, index, 'padlock.value must not be an empty string')
    }

    return { ...output, padlock: { value: padlock['value'] as string, type: 'value' } }
  }

  if (has(padlock, 'nonce')) {
    if (has(padlock, 'case')) {
      return {
        ...output,
        padlock: {
          nonce: padlock['nonce'] as string,
          case: normalizePadlockCase(padlock['case'], type, input, index),
          type: 'build',
        },
      }
    }

    return { ...output, padlock: { nonce: padlock['nonce'] as string, type: 'build' } }
  }

  if (has(padlock, 'case')) {
    return {
      ...output,
      padlock: {
        case: normalizePadlockCase(padlock['case'], type, input, index),
        type: 'build',
      },
    }
  }

  throw fail(
    type,
    input,
    index,
    'padlock must have at least one sub-key: value, nonce, or case'
  )
}

const normalizePadlockCase = (
  value: unknown,
  type: InputType,
  input: Jsonish,
  index: number
): 'random' | 'upper' | 'lower' => {
  switch (value) {
    case undefined:
    case null:
    case 'random': {
      return 'random'
    }
    case 'upper': {
      return 'upper'
    }
    case 'lower': {
      return 'lower'
    }
    default: {
      throw fail(
        type,
        input,
        index,
        "padlock.case must be one of 'lower', 'random', or 'upper'"
      )
    }
  }
}

const normalizeProof = (
  output: Partial<TestInput>,
  input: Jsonish,
  type: InputType,
  index: number
): Partial<TestInput> => {
  const proof = input['proof'] as Jsonish
  mustHave(type, proof, index, 'version', { input, name: 'proof.version' })

  const newProof: Partial<TestInputProof> = {
    version: proof['version'] as number,
  }

  if (has(proof, 'id')) {
    newProof.id = proof['id'] as string
  }

  if (has(proof, 'secret')) {
    newProof.secret = proof['secret'] as string
  }

  return { ...output, proof: newProof as TestInputProof }
}

const fail = (
  type: InputType,
  input: Jsonish,
  index: number,
  message: string | Error
): Error => {
  let extra = ''

  if (message instanceof Error) {
    extra = `\n${message.stack}`
    message = message.message
  }

  return new Error(
    `Error in ${type} item ${index + 1}: ${message}\n` +
      JSON.stringify(input, null, 2) +
      extra
  )
}

const has = (record: Jsonish, key: string): boolean => key in record

const mustHave = (
  type: InputType,
  input: Jsonish,
  index: number,
  key: string,
  options: {
    name?: string
    input?: Jsonish
  } = {}
): void => {
  if (!has(input, key)) {
    throw fail(type, options.input || input, index, `missing ${options.name || key}`)
  }
}
