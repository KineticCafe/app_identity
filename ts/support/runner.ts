import type { Command } from 'commander'

import fs from 'fs'
import { join as joinPath } from 'path'
import fg from 'fast-glob'

import { App } from '../src/app'
import { Info } from '../src'
import { verifyProofWithDiagnostic } from '../src/internal'

import type { Suite, Test } from './schema'
import type { AppIdentityVersionInfo } from '../src'

/* eslint-disable no-unused-vars,@typescript-eslint/no-unused-vars */
export const runner = (
  program: Command
): ((paths: Array<string>, options: RunOptions) => void) => {
  /* eslint-enable no-unused-vars,@typescript-eslint/no-unused-vars */
  return (paths: Array<string>, options: RunOptions): void => {
    try {
      if (!runSuites(paths, options)) {
        process.exit(1)
      }
    } catch (e) {
      if (e instanceof Error) {
        program.error(e.message + '\n' + e.stack)
      }
    }
  }
}

type RunOptions = { strict: boolean; diagnostic: boolean; stdin: boolean }

type AnnotatedTest = Test & {
  index: number
}

type AnnotatedSuite = Suite & {
  tests: Array<AnnotatedTest>
}

const runSuites = (paths: Array<string>, options: RunOptions): boolean => {
  const providedSuites = [...pipedSuite(options), ...loadSuites(paths)]
  const { total, suites } = summarizeAndAnnotate(providedSuites)

  if (total === 0) {
    return true
  }

  return suites.reduce(
    (result: boolean, suite: AnnotatedSuite): boolean =>
      runSuite(suite, options) && result,
    true
  )
}

const summarizeAndAnnotate = (
  providedSuites: Array<Suite>
): { total: number; suites: Array<AnnotatedSuite> } => {
  let index = 0
  let total = 0

  const suites = providedSuites.map((suite: Suite): AnnotatedSuite => {
    const tests: Array<AnnotatedTest> = suite.tests.map((test: Test): AnnotatedTest => {
      return { index: ++index, ...test } as AnnotatedTest
    })

    total += tests.length

    return {
      name: suite.name,
      version: suite.version,
      spec_version: suite.spec_version,
      tests,
    } as AnnotatedSuite
  })

  console.log('TAP Version 14')
  console.log(`1..${total}`)

  if (total === 0) {
    console.log('# No suites provided.')
  }

  return { total, suites }
}

const runSuite = (suite: AnnotatedSuite, options: RunOptions): boolean => {
  console.log(`# ${infoToString(Info)} testing ${infoToString(suite)}`)
  return suite.tests.reduce(
    (result: boolean, test: AnnotatedTest): boolean => runTest(test, options) && result,
    true
  )
}

const infoToString = (info: AppIdentityVersionInfo | AnnotatedSuite): string =>
  [info.name, info.version, `(spec ${info.spec_version})`].join(' ')

type TestResult = { result: boolean; message: string }

const runTest = (test: AnnotatedTest, options: RunOptions): boolean => {
  if (Info.spec_version < test.spec_version) {
    console.log(
      `ok ${test.index} - ${test.description} # SKIP unsupported spec version ${Info.spec_version} < ${test.spec_version})`
    )
    return true
  }

  try {
    const { result, message } = checkResult(
      verifyProofWithDiagnostic(test.proof, test.app),
      test,
      options
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
  test: AnnotatedTest,
  options: RunOptions
): TestResult => {
  if (test.expect == 'pass') {
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

const ok = (test: AnnotatedTest): TestResult => ({
  result: true,
  message: `ok ${test.index} - ${test.description}`,
})

const notOk = (
  test: AnnotatedTest,
  options: RunOptions,
  error?: string | unknown
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

const loadSuites = (paths: Array<string>): Array<Suite> => paths.flatMap(processPath)

const processPath = (path: string): Array<Suite> => {
  const stat = fs.statSync(path)

  if (stat.isFile()) {
    return [loadSuite(path)]
  }

  if (stat.isDirectory()) {
    return fg.sync(joinPath(path, '*.json')).flatMap(processPath)
  }

  throw new Error(`Path ${path} is not a file or a directory.`)
}

const pipedSuite = (options: RunOptions): Array<Suite> => {
  const data = options.stdin
    ? fs.readFileSync(process.stdin.fd, { encoding: 'utf-8' }).trim()
    : null

  return data ? [parseSuite(data)] : []
}

const loadSuite = (path: string): Suite =>
  parseSuite(fs.readFileSync(path, { encoding: 'utf-8' }))

const parseSuite = (data: string): Suite => JSON.parse(data) as Suite
