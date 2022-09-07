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

type TestInputPadlock = {
  nonce: string
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

    if (input.padlock) {
      const padlock = Support.buildPadlock(app, {
        id: input.proof.id,
        nonce: input.padlock.nonce,
        secret: input.proof.secret,
        version: input.proof.version,
      })

      return Support.buildProof(app, padlock, {
        id: input.proof.id,
        nonce,
        secret: input.proof.secret,
        version: input.proof.version,
      })
    } else if (input.proof.id || input.proof.secret || input.nonce) {
      const padlock = Support.buildPadlock(app, {
        id: input.proof.id,
        nonce,
        secret: input.proof.secret,
        version: input.proof.version,
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

  const test: Partial<TestInput> = {
    description: input['description'] as string,
    expect: input['expect'] as Expect,
    spec_version: input['spec_version'] as number,
  }

  if (has(input, 'app')) {
    const tmp = input['app'] as Jsonish

    mustHave(type, tmp, index, 'version', { input, name: 'app.version' })

    const app: Partial<TestInputApp> = {
      version: tmp['version'] as number,
    }

    if (has(tmp, 'config')) {
      const appConfig = tmp['config'] as Jsonish
      mustHave(type, appConfig, index, 'fuzz', { input, name: 'app.config.fuzz' })
      app.config = { fuzz: appConfig['fuzz'] as number }
    }

    test.app = app as TestInputApp
  }

  if (has(input, 'nonce')) {
    const nonce: Partial<TestInputNonce> = {}
    const tmp = input['nonce'] as Jsonish

    if (has(tmp, 'empty')) {
      if (has(tmp, 'offset_minutes') || has(tmp, 'value')) {
        throw fail(type, input, index, 'nonce must only have one sub-key')
      }

      nonce.empty = !!tmp['empty']
    } else if (has(tmp, 'offset_minutes')) {
      if (has(tmp, 'value')) {
        throw fail(type, input, index, 'nonce must only have one sub-key')
      }

      nonce.offset_minutes = tmp['offset_minutes'] as number
    } else if (has(tmp, 'value')) {
      nonce.value = tmp['value'] as string
    } else {
      throw fail(type, input, index, 'nonce requires exactly one sub-key')
    }

    test.nonce = nonce as TestInputNonce
  }

  if (has(input, 'padlock')) {
    const tmp = input['padlock'] as Jsonish
    mustHave(type, tmp, index, 'nonce', { input, name: 'padlock.nonce' })

    test.padlock = { nonce: tmp['nonce'] as string }
  }

  {
    const tmp = input['proof'] as Jsonish
    mustHave(type, tmp, index, 'version', { input, name: 'proof.version' })
    const proof: Partial<TestInputProof> = {
      version: tmp['version'] as number,
    }

    if (has(tmp, 'id')) {
      proof.id = tmp['id'] as string
    }

    if (has(tmp, 'secret')) {
      proof.secret = tmp['secret'] as string
    }

    test.proof = proof as TestInputProof
  }

  return test as TestInput
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
