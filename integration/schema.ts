/**
 * The expected result of the test.
 */
export type Expect = 'pass' | 'fail'

/**
 * App configuration.
 */
export type Config = {
  /**
   * An optional fuzz configuration. The value must be a positive integer and is
   * measured in seconds.
   */
  fuzz?: number
}

/**
 * An App Identity app.
 */
export type App = {
  /**
   * A number or string identifier.
   */
  id: number | string
  /**
   * A binary string secret.
   */
  secret: string
  /**
   * The version of the algorithm.
   */
  version: number
  /**
   * The optional configuration.
   */
  config?: Config | null
}

/**
 * An integration test to be run.
 */
export type Test = {
  /**
   * A description of the test. Shown as part of the output.
   */
  description: string
  /**
   * The app used for the test.
   */
  app: App
  /**
   * The generated proof to test.
   */
  proof: string
  /**
   * Whether the proof comparison should pass or fail.
   */
  expect: 'pass' | 'fail'
  /**
   * Indicates whether this is a required test for conformance.
   */
  required: boolean
  /**
   * The major specification version for this test. Integration suite runners
   * should mark unsupported specification versions as skipped.
   */
  spec_version: number
}

/**
 * An integration test suite.
 */
export type Suite = {
  /**
   * The name of the implementation.
   */
  name: string
  /**
   * The version of the implementation.
   */
  version: string
  /**
   * The supported major specification version.
   */
  spec_version: number
  /**
   * The set of tests to run.
   */
  tests: Array<Test>
}
