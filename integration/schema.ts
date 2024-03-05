/**
 * The expected result of the test.
 */
export type Expect = 'pass' | 'fail'

/**
 * App configuration.
 */
export interface Config {
  /**
   * An optional fuzz configuration. The value must be a positive integer and is
   * measured in seconds.
   */
  fuzz?: number
}

/**
 * An App Identity app.
 */
export interface App {
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
  /**
   * Apps may have additional configuration values which are ignored by App
   * Identity.
   */
  [key: string]: unknown
}

/**
 * An integration test to be run.
 */
export interface Test {
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
export interface Suite {
  /**
   * The name of the implementation that generated the suite.
   */
  name: string

  /**
   * The version of the implementation that generated the suite.
   */
  version: string

  /**
   * The description of the suite. Marked optional for backwards compatibility,
   * it should be considered required for newer suite generators.
   *
   * This should generally be in the form `{name} {version} (spec {spec-version})`.
   *
   * If a runtime package is required to run the suite, such as
   * @kineticcafe/app-identity-node, the form should be one of:
   *
   * - `{core-name} {core-version} ({runtime-name} {runtime-version}, spec ${spec-version})`
   * - `{core-name} {core-version} ({runtime-name}, spec ${spec-version})`
   *
   * The latter form should be used if the package `core-version` and
   * `runtime-version` entries are the same.
   */
  description?: string

  /**
   * The supported major specification version.
   */
  spec_version: number

  /**
   * The set of tests to run.
   */
  tests: Test[]
}
