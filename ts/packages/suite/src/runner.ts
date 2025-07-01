import assert from 'node:assert'
import { readFileSync, statSync } from 'node:fs'
import { join as joinPath } from 'node:path'
import { Command } from '@commander-js/extra-typings'
import {
  App,
  Info,
  useNodeRuntimeAdapter,
  verifyProofWithDiagnostic,
} from '@kineticcafe/app-identity-node'
import fg from 'fast-glob'
import type * as Runner from './runner/types.js'
import type * as Schema from './schema.js'
import { versionString } from './support.js'

export const runner = new Command('run')
  .description('Runs one or more integration suites')
  .argument('[paths...]', 'The filenames or directories containing the suites to be run')
  .option('-S, --strict', 'Runs in strict mode; optional tests will cause failure')
  .option('--stdin', 'Reads a suite from standard input')
  .option('-D, --diagnostic', 'Enables output diagnostics')
  .action(
    async (paths: string[], options: Runner.Options, command: Command<[string[]]>) => {
      useNodeRuntimeAdapter()

      try {
        if (!(await runSuites(paths, options))) {
          process.exit(1)
        }
      } catch (e) {
        if (e instanceof Error) {
          command.error(`${e.message}\n${e.stack}`)
        }
      }
    },
  )

const runSuites = async (paths: string[], options: Runner.Options): Promise<boolean> => {
  const pipedSuites = await pipedSuite(options)
  const providedSuites = [...pipedSuites, ...loadSuites(paths)]
  const { total, suites } = summarizeAndAnnotate(providedSuites)

  if (total === 0) {
    return true
  }

  return suites.reduce(
    (result: boolean, suite: Runner.Suite): boolean => runSuite(suite, options) && result,
    true,
  )
}

const summarizeAndAnnotate = (
  providedSuites: Schema.Suite[],
): { total: number; suites: Runner.Suite[] } => {
  let index = 0
  let total = 0

  const suites = providedSuites.map((suite: Schema.Suite): Runner.Suite => {
    const tests: Runner.Test[] = suite.tests.map((test: Schema.Test): Runner.Test => {
      return { index: ++index, ...test }
    })

    total += tests.length

    const annotated: Runner.Suite = {
      name: suite.name,
      spec_version: suite.spec_version,
      tests,
      version: suite.version,
    }

    if (suite.description) {
      annotated.description = suite.description
    }

    return annotated
  })

  console.log('TAP Version 14')
  console.log(`1..${total}`)

  if (total === 0) {
    console.log('# No suites provided.')
  }

  return { total, suites }
}

const runSuite = (suite: Runner.Suite, options: Runner.Options): boolean => {
  console.log(`# generator: ${versionString(suite)}`)
  console.log(`# runner: ${versionString(Info)}`)
  return suite.tests.reduce(
    (result: boolean, test: Runner.Test): boolean => runTest(test, options) && result,
    true,
  )
}

type TestResult = { result: boolean; message: string }

const runTest = (test: Runner.Test, options: Runner.Options): boolean => {
  if (Info.spec_version < test.spec_version) {
    console.log(
      `ok ${test.index} - ${test.description} # SKIP unsupported spec version ${Info.spec_version} < ${test.spec_version})`,
    )
    return true
  }

  try {
    const { result, message } = checkResult(
      verifyProofWithDiagnostic(test.proof, test.app),
      test,
      options,
    )
    console.log(message)
    return result
  } catch (e) {
    const { result, message } = checkResult(e, test, options)
    console.log(message)
    return result
  }
}

const checkResult = (
  result: App | null | string | unknown,
  test: Runner.Test,
  options: Runner.Options,
): TestResult => {
  if (test.expect === 'pass') {
    if (result instanceof App) {
      return ok(test)
    }

    return notOk(test, options, result || 'proof verification failed')
  }

  if (result instanceof App) {
    return notOk(test, options, `proof should have failed ${result}`)
  }

  return ok(test)
}

const ok = (test: Runner.Test): TestResult => ({
  result: true,
  message: `ok ${test.index} - ${test.description}`,
})

const notOk = (
  test: Runner.Test,
  options: Runner.Options,
  error?: string | unknown,
): TestResult => {
  let message = `not ok ${test.index} - ${test.description}`

  if (!test.required && !options.strict) {
    message += ' # TODO optional failing test'
  }

  if (options.diagnostic && error) {
    const errorMessage = error instanceof Error ? (error as Error).message : error

    message += `\n  ---\n  message: ${errorMessage}\n  ...`
  }

  return { result: false, message }
}

const loadSuites = (paths: string[]): Schema.Suite[] => paths.flatMap(processPath)

const processPath = (path: string): Schema.Suite[] => {
  const stat = statSync(path)

  if (stat.isFile()) {
    return [loadSuite(path)]
  }

  if (stat.isDirectory()) {
    return fg.sync(joinPath(path, '*.json')).flatMap(processPath)
  }

  throw new Error(`Path ${path} is not a file or a directory.`)
}

const pipedSuite = async (options: Runner.Options): Promise<Schema.Suite[]> => {
  if (process.stdin.isTTY || !options.stdin) {
    return []
  }

  const chunks: Buffer[] = []
  let len = 0

  process.stdin.read()

  for await (const chunk of process.stdin) {
    chunks.push(chunk)
    len += chunk.length
  }

  if (len === 0) {
    return []
  }

  return [parseSuite(Buffer.concat(chunks, len).toString('utf8'))]
}

const loadSuite = (path: string): Schema.Suite =>
  parseSuite(readFileSync(path, { encoding: 'utf-8' }))

const parseSuite = (data: string): Schema.Suite => {
  const input = JSON.parse(data)

  assert(
    input != null && typeof input === 'object' && !Array.isArray(input),
    `Suite is not an object: ${data}`,
  )
  assert(
    'name' in input && 'version' in input && 'spec_version' in input && 'tests' in input,
    `Suite is missing one or more required properties (name, version, spec_version, tests): ${Object.keys(
      input,
    )}`,
  )

  assert(typeof input.name === 'string', `Suite.name is not a string: ${input.name}`)
  assert(
    typeof input.version === 'string',
    `Suite.version is not a string: ${input.version}`,
  )
  assert(
    Number.isInteger(input.spec_version),
    `Suite.spec_version is not an integer: ${input.spec_version}`,
  )

  assert(
    Array.isArray(input.tests),
    `Suite.tests is not an array of tests: ${input.tests}`,
  )

  let description: string | undefined

  if ('description' in input) {
    assert(
      typeof input.description === 'string',
      `Suite.description is not a string: ${input.description}`,
    )

    description = input.description
  }

  const tests = parseTests(input.tests)

  const suite: Schema.Suite = {
    name: input.name,
    version: input.version,
    spec_version: input.spec_version,
    tests,
  }

  if (description) {
    suite.description = description
  }

  return suite
}

const parseTests = (tests: unknown[]): Schema.Test[] => {
  assert(tests.length > 0, 'At least one test must be included in a Suite')

  const parsedTests: Schema.Test[] = []

  for (const [index, test] of tests.entries()) {
    const idx = index + 1

    assert(
      test != null && typeof test === 'object' && !Array.isArray(test),
      `Suite.tests[${idx}] is not an object: ${test}`,
    )
    assert(
      'description' in test &&
        'app' in test &&
        'proof' in test &&
        'expect' in test &&
        'required' in test &&
        'spec_version' in test,
      `Suite.tests[${idx}] is missing one or more required properties (description, app, proof, expect, required, spec_version): ${Object.keys(
        test,
      )}`,
    )
    assert(
      typeof test.description === 'string' && test.description !== '',
      `Suite.tests[${idx}].description is not a non-empty string: ${test.description}`,
    )
    assert(
      typeof test.proof === 'string' && test.proof !== '',
      `Suite.tests[${idx}].proof is not a non-empty string: ${test.proof}`,
    )
    assert(
      test.expect === 'pass' || test.expect === 'fail',
      `Suite.tests[${idx}].expect is must be pass or fail: ${test.proof}`,
    )
    assert(
      typeof test.required === 'boolean',
      `Suite.tests[${idx}].required is must be true or false: ${test.required}`,
    )
    assert(
      typeof test.spec_version === 'number' && Number.isInteger(test.spec_version),
      `Suite.tests[${idx}].spec_version is must be an integer: ${test.spec_version}`,
    )

    assert(
      test.app != null && typeof test.app === 'object' && !Array.isArray(test.app),
      `Suite.tests[${idx}].app is not an object: ${test.app}`,
    )

    const app = parseApp(test.app, idx)

    parsedTests.push({
      description: test.description,
      proof: test.proof,
      expect: test.expect,
      required: test.required,
      spec_version: test.spec_version,
      app,
    })

    // app: App
  }

  return parsedTests
}

const parseApp = (app: object, idx: number): Schema.App => {
  assert(
    'id' in app && 'secret' in app && 'version' in app,
    `Suite.tests[${idx}].app is missing one or more required properties (id, secret, version): ${Object.keys(
      app,
    )}`,
  )
  assert(
    typeof app.id === 'number' || (typeof app.id === 'string' && app.id !== ''),
    `Suite.tests[${idx}].app.id is not a number or non-empty string: ${app.id}`,
  )
  assert(
    typeof app.secret === 'string' && app.secret !== '',
    `Suite.tests[${idx}].app.secret is not a non-empty string: ${app.secret}`,
  )
  assert(
    typeof app.version === 'number' && Number.isInteger(app.version),
    `Suite.tests[${idx}].app.version is not an integer: ${app.version}`,
  )

  const result: Schema.App = { id: app.id, secret: app.secret, version: app.version }

  if ('config' in app) {
    if (app.config == null) {
      result.config = null
    } else {
      assert(
        typeof app.config === 'object' && !Array.isArray(app.config),
        `Suite.tests[${idx}].app.config is not an object: ${app.config}`,
      )

      if ('fuzz' in app.config) {
        assert(
          typeof app.config.fuzz === 'number' && Number.isInteger(app.config.fuzz),
          `Suite.tests[${idx}].app.config.fuzz is not an integer: ${app.config.fuzz}`,
        )

        result.config = { fuzz: app.config.fuzz }
      } else {
        result.config = {}
      }
    }
  }

  return result
}
