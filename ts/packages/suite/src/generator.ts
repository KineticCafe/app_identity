import { statSync, writeFileSync } from 'node:fs'
import { join as joinPath } from 'node:path'
import { Command } from '@commander-js/extra-typings'
import {
  type App,
  AppIdentityError,
  Info,
  Validations,
  generateProofWithDiagnostic,
  useNodeRuntimeAdapter,
} from '@kineticcafe/app-identity-node'

import optional from './optional.json' with { type: 'json' }
import required from './required.json' with { type: 'json' }
import * as Support from './support.js'

import type * as Generator from './generator/types.js'
import type { Suite, Test } from './schema.js'

export const generator = new Command('generate')
  .description('Generates an integration test suite')
  .argument(
    '[suite]',
    'The filename to use for the suite, adding .json if not present',
    'app-identity-suite-ts.json',
  )
  .option('--stdout', 'Prints the suite to standard output instead of saving it')
  .option('-q, --quiet', 'Silences diagnostic messages')
  .action((name: string, options: Generator.Options, command: Command<[string]>) => {
    useNodeRuntimeAdapter()

    try {
      const suiteName =
        !options.stdout && !name.endsWith('.json')
          ? statSync(name).isDirectory()
            ? joinPath(name, 'app-identity-suite-ts.json')
            : `${name}.json`
          : name

      const suite = generateSuite()

      if (suite === null) {
        command.error('Error generating suite')
      }

      if (!options.quiet && !options.stdout) {
        const description = suite.description ?? `${suite.name} ${suite.version}`

        console.log(`Generated ${suite.tests.length} tests for ${description}.`)
      }

      if (options.stdout) {
        console.log(JSON.stringify(suite, null, 2))
      } else {
        writeFileSync(suiteName, JSON.stringify(suite))
        if (!options.quiet) {
          console.log(`Saved as ${suiteName}`)
        }
      }
    } catch (e) {
      if (e instanceof Error) {
        command.error(`${e.message}\n${e.stack}`)
      } else {
        command.error('Unknown error not involving an exception')
      }
    }
  })

const generateSuite = (): Suite => {
  // const description = `${Info.core.name} ${Info.core.version} (${
  //   Info.core.version === Info.version ? Info.name : `${Info.name} ${Info.version}`
  // })`

  return {
    description: Support.versionString(Info),
    name: Info.core.name,
    spec_version: Info.core.spec_version,
    tests: [
      ...generateTests('required', required),
      ...generateTests('optional', optional),
    ],
    version: Info.version,
  }
}

type InputType = 'required' | 'optional'

const generateTests = (type: InputType, input: unknown[]): Test[] => {
  if (Array.isArray(input)) {
    return input.map((input, index) => generateTest(type, input, index))
  }

  throw new AppIdentityError(
    `Cannot generate tests for ${type} because input is not an array`,
  )
}

const generateTest = (type: InputType, input: unknown, index: number): Test => {
  const testInput = checkTest(type, input, index)

  const app: App = testInput.app
    ? Support.app(testInput.app.version, testInput.app.config?.fuzz)
    : Support.app(1)

  const proof = makeProof(type, testInput, index, app)

  if (proof === undefined) {
    throw new Error('Proof is undefined: this should be impossible')
  }

  return {
    description: testInput.description,
    expect: testInput.expect,
    app: { ...app, secret: app.secret() },
    proof,
    required: type === 'required',
    spec_version: testInput.spec_version,
  }
}

const makeProof = (
  type: InputType,
  input: Generator.Input,
  index: number,
  app: App,
): string => {
  try {
    const version = Validations.checkVersion(input.proof.version).expect(
      'Requested version is not supported',
      AppIdentityError,
    )

    const nonce = input.nonce?.empty
      ? Support.EMPTY_NONCE
      : input.nonce?.offset_minutes
        ? Support.timestampNonce(input.nonce.offset_minutes)
        : input.nonce?.value
          ? input.nonce.value
          : app.generateNonce(version)

    const proofOptions: Support.BuildProofOptions = { nonce, version }

    setOptional(proofOptions, 'id', input.proof.id)
    setOptional(proofOptions, 'secret', input.proof.secret)

    if (input.padlock?.type === 'value') {
      return Support.buildProof(app, input.padlock.value, proofOptions)
    }

    const padlockOptions: Support.BuildPadlockOptions = { nonce, version }

    setOptional(padlockOptions, 'id', input.proof.id)
    setOptional(padlockOptions, 'secret', input.proof.secret)

    if (input.padlock?.type === 'build') {
      setOptional(padlockOptions, 'nonce', input.padlock?.nonce)
      setOptional(padlockOptions, 'case', input.padlock?.case)

      const padlock = Support.buildPadlock(app, padlockOptions)

      return Support.buildProof(app, padlock, proofOptions)
    }

    if (input.proof.id || input.proof.secret || input.nonce) {
      const padlock = Support.buildPadlock(app, padlockOptions)

      return Support.buildProof(app, padlock, proofOptions)
    }

    if (nonce === Support.EMPTY_NONCE) {
      throw 'Unreachable nonce error was somehow reached'
    }

    return generateProofWithDiagnostic(app, { nonce: nonce, version })
  } catch (e) {
    throw fail(type, input, index, e instanceof Error ? e.message : 'UNKNOWN ERROR')
  }
}

const checkTest = (type: InputType, input: unknown, index: number): Generator.Input => {
  const object = checkObject(type, input, index)

  const description = mustHave(type, object, index, 'description', checkString)
  const expect = mustHave(type, object, index, 'expect', (type, index, key, value) => {
    if (value === 'pass' || value === 'fail') {
      return value
    }

    throw fail(type, value, index, `Invalid ${key} value '${value}'`)
  })
  const app = checkApp(type, object, index)
  const spec_version = mustHave(type, object, index, 'spec_version', checkVersion)
  const nonce = checkNonce(type, object, index)
  const padlock = checkPadlock(type, object, index)
  const proof = checkProof(type, object, index)

  const output: Generator.Input = { description, expect, spec_version, proof }

  setOptional(output, 'app', app)
  setOptional(output, 'nonce', nonce)
  setOptional(output, 'padlock', padlock)

  return output
}

const checkApp = (
  type: InputType,
  input: Generator.Object,
  index: number,
): Generator.InputApp | undefined => {
  if ('app' in input) {
    const object = checkObject(type, input, index, 'app')
    const version = mustHave(type, object, index, 'version', checkVersion, {
      input,
      name: 'app.version',
    })

    const config = checkConfig(type, object, index)

    const app: Generator.InputApp = { version }

    setOptional(app, 'config', config)

    return app
  }

  return undefined
}

const checkNonce = (
  type: InputType,
  input: Generator.Object,
  index: number,
): Generator.InputNonce | undefined => {
  if (!('nonce' in input)) {
    return undefined
  }

  const object = checkObject(type, input, index, 'nonce') as Generator.InputNonce

  if ('empty' in object) {
    if ('offset_minutes' in object || 'value' in object) {
      throw fail(type, input, index, 'nonce must only have one sub-key')
    }

    if (object.empty === true) {
      return { empty: true }
    }

    throw fail(type, input, index, 'nonce.empty may only be true')
  }

  if ('offset_minutes' in object) {
    if ('value' in object) {
      throw fail(type, input, index, 'nonce must only have one sub-key')
    }

    const value = object.offset_minutes

    if (typeof value === 'number' && Number.isInteger(value)) {
      return { offset_minutes: value }
    }

    throw fail(type, input, index, 'nonce.offset_minutes must be an integer')
  }

  if ('value' in object) {
    if (typeof object.value !== 'string') {
      throw fail(type, input, index, 'nonce.value must be a string')
    }

    return { value: object.value as string }
  }

  throw fail(type, input, index, 'nonce requires exactly one sub-key')
}

const checkPadlock = (
  type: InputType,
  input: Generator.Object,
  index: number,
): Generator.InputPadlock | undefined => {
  if (!('padlock' in input)) {
    return undefined
  }

  const object = checkObject(
    type,
    input,
    index,
    'padlock',
  ) as Partial<Generator.InputPadlock>
  const keyCount = Object.keys(object).length

  if (keyCount === 0) {
    throw fail(
      type,
      input,
      index,
      'padlock must have at least one sub-key: value, nonce, or case',
    )
  }

  if ('value' in object) {
    if (keyCount > 1) {
      throw fail(
        type,
        input,
        index,
        'padlock must not have any other sub keys if value is specified',
      )
    }

    if (typeof object.value !== 'string' || object.value === '') {
      throw fail(type, input, index, 'padlock.value must be a non-empty string')
    }

    return { value: object.value, type: 'value' }
  }

  if ('nonce' in object) {
    if (typeof object.nonce !== 'string' || object.nonce === '') {
      throw fail(type, input, index, 'padlock.nonce must be a non-empty string')
    }

    return 'case' in object
      ? {
          type: 'build',
          nonce: object.nonce,
          case: checkPadlockCase(type, index, object.case),
        }
      : { type: 'build', nonce: object.nonce }
  }

  if ('case' in object) {
    return { type: 'build', case: checkPadlockCase(type, index, object.case) }
  }

  throw fail(
    type,
    input,
    index,
    'padlock must have at least one sub-key: value, nonce, or case',
  )
}

const checkPadlockCase = (
  type: InputType,
  index: number,
  input: unknown,
): 'random' | 'upper' | 'lower' => {
  switch (input) {
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
        "padlock.case must be one of 'lower', 'random', or 'upper'",
      )
    }
  }
}

const checkProof = (
  type: InputType,
  input: Generator.Object,
  index: number,
): Generator.InputProof => {
  if (!('proof' in input)) {
    throw fail(type, input, index, 'missing proof key')
  }

  const object = checkObject(type, input, index, 'proof') as Partial<Generator.InputProof>

  const version = mustHave(type, object, index, 'version', checkVersion, {
    input: object,
    name: 'proof.version',
  })

  const proof: Generator.InputProof = { version }

  if ('id' in object) {
    if (typeof object.id !== 'string' || object.id === '') {
      throw fail(type, input, index, 'proof.id must be a non-empty string')
    }

    setOptional(proof, 'id', object.id)
  }

  if ('secret' in object) {
    if (typeof object.secret !== 'string' || object.secret === '') {
      throw fail(type, input, index, 'proof.secret must be a non-empty string')
    }

    setOptional(proof, 'secret', object.secret)
  }

  return proof
}

const fail = (
  type: InputType,
  input: unknown,
  index: number,
  message: string | Error,
): Error => {
  const stack = message instanceof Error ? message.stack : ''
  const msg = message instanceof Error ? message.message : message

  return new Error(
    `Error in ${type} item ${index + 1}: ${msg}\n${JSON.stringify(
      input,
      null,
      2,
    )}${stack}`,
  )
}

const mustHave = <T>(
  type: InputType,
  input: Record<string, unknown>,
  index: number,
  key: string,
  validator: (type: InputType, index: number, key: string, value: unknown) => T,
  options: {
    name?: string
    input?: Record<string, unknown>
  } = {},
): T => {
  if (key in input) {
    return validator(type, index, key, input[key])
  }

  throw fail(type, options.input || input, index, `missing ${options.name || key}`)
}

const checkString = (
  type: InputType,
  index: number,
  key: string,
  value: unknown,
): string => {
  if (typeof value === 'string') {
    return value
  }

  throw fail(type, value, index, `${key} is not a string`)
}

const checkVersion = (
  type: InputType,
  index: number,
  key: string,
  value: unknown,
): number => {
  if (typeof value === 'number' && Validations.checkVersion(value).isOk()) {
    return value
  }

  throw fail(type, value, index, `${key} is not a valid version`)
}

const checkConfig = (
  type: InputType,
  input: Generator.Object,
  index: number,
): Generator.InputApp['config'] | undefined => {
  if (!('config' in input)) {
    return undefined
  }

  const object = checkObject(type, input, index, 'config')

  const fuzz = mustHave(
    type,
    object,
    index,
    'fuzz',
    (type, index, key, value) => {
      if (typeof value === 'number') {
        return value
      }

      throw fail(type, value, index, `${key} is a number`)
    },
    { input: object, name: 'app.config.fuzz' },
  )

  return { fuzz }
}

const checkObject = (
  type: InputType,
  input: unknown,
  index: number,
  key?: string,
): Generator.Object => {
  if (input == null || typeof input !== 'object' || Array.isArray(input)) {
    throw fail(type, input, index, 'is not an object')
  }

  for (const k in input) {
    if (typeof k !== 'string') {
      throw fail(type, input, index, 'is not an object with string keys')
    }
  }

  if (key == null) {
    return input as Generator.Object
  }

  const object = (input as Generator.Object)[key]

  if (object == null || typeof object !== 'object' || Array.isArray(object)) {
    throw fail(type, object, index, `${key} is not an object`)
  }

  for (const k in object) {
    if (typeof k !== 'string') {
      throw fail(type, object, index, `${key} is not an object with string keys`)
    }
  }

  return object as Generator.Object
}

const setOptional = <T extends object>(
  value: T,
  key: keyof T,
  input: T[keyof T] | undefined,
): void => {
  if (input != null) {
    value[key] = input
  }
}
