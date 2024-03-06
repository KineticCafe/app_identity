import type * as Schema from '../schema.js'

export interface Options {
  strict?: boolean
  diagnostic?: boolean
  stdin?: boolean
}

export interface Test extends Schema.Test {
  index: number
}

export interface Suite extends Schema.Suite {
  tests: Test[]
}
