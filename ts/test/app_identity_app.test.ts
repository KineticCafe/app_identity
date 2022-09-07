import { expect, test } from 'vitest'

import { App } from '../src/app'

test('id validation', () => {
  expect(() => new App({ id: null })).toThrowError('id must not be nil')
  expect(() => new App({ id: undefined })).toThrowError('id must not be nil')
  expect(() => new App({ id: '' })).toThrowError('id must not be an empty string')
  expect(() => new App({ id: '1:1' })).toThrowError(
    'id must not contain colon characters'
  )
})

test('secret validation', () => {
  expect(() => new App({ id: 1, secret: null })).toThrowError('secret must not be nil')
  expect(() => new App({ id: 1, secret: '' })).toThrowError(
    'secret must not be an empty string'
  )
  expect(() => new App({ id: 1, secret: 3 })).toThrowError(
    'secret must be a binary string value'
  )
  expect(() => new App({ id: 1, secret: '1:1' })).toThrowError(
    'secret must not contain colon characters'
  )
})

test('version validation', () => {
  expect(() => new App({ id: 1, secret: 'a', version: null })).toThrowError(
    'version must not be nil'
  )
  expect(() => new App({ id: 1, secret: 'a', version: 3.5 })).toThrowError(
    'version must be a positive integer'
  )
  expect(() => new App({ id: 1, secret: 'a', version: '' })).toThrowError(
    'version cannot be converted to an integer'
  )
  expect(() => new App({ id: 1, secret: 'a', version: 'a' })).toThrowError(
    'version cannot be converted to an integer'
  )
})

test('config validation', () => {
  expect(() => new App({ id: 1, secret: 'a', version: 1, config: 3 })).toThrowError(
    'config must be nil or a map'
  )
})
