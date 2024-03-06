import type { Expect } from '../schema.js'

export type Object = Record<string, unknown>

export interface InputApp {
  config?: { fuzz: number }
  version: number
}

export interface InputNonce {
  empty?: boolean
  offset_minutes?: number
  value?: string
}

export interface ComputedPadlock {
  nonce?: string
  case?: 'random' | 'upper' | 'lower'
  type: 'build'
}

export interface ProvidedPadlock {
  value: string
  type: 'value'
}

export type InputPadlock = ComputedPadlock | ProvidedPadlock

export interface InputProof {
  id?: string
  secret?: string
  version: number
}

export interface Input {
  app?: InputApp
  description: string
  spec_version: number
  expect: Expect
  nonce?: InputNonce
  padlock?: InputPadlock
  proof: InputProof
}

export interface Options {
  quiet?: boolean
  stdout?: boolean
}
