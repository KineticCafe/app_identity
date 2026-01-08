import { describe, expect, expectTypeOf, test } from 'vitest'
import { AppIdentityError } from '../src/app_identity_error.js'

import {
  BaseResult,
  Err,
  flattenResult,
  Ok,
  throwErrs,
  unwrapErrs,
  unwrapOks,
} from '../src/result.js'

describe('Err', () => {
  test('makes a BaseResult', () => {
    expect(Err(3)).toBeInstanceOf(BaseResult)
  })

  test('makes a BaseResult<T, number>', () => {
    expectTypeOf(Err(3)).toMatchTypeOf<BaseResult<unknown, number>>()
  })
})

describe('Ok', () => {
  test('makes a BaseResult', () => {
    expect(Ok('value')).toBeInstanceOf(BaseResult)
  })

  test('makes a BaseResult<string, E>', () => {
    expectTypeOf(Ok('value')).toMatchTypeOf<BaseResult<string, unknown>>()
  })
})

describe('Result#isOk()', () => {
  test('Ok(T).isOk() is true', () => {
    expect(Ok('value').isOk()).toBe(true)
  })

  test('Err(E).isOk() is false', () => {
    expect(Err(3).isOk()).toBe(false)
  })

  test('Ok(T).isOk((_) => true) is true', () => {
    expect(Ok('value').isOk((_) => true)).toBe(true)
  })

  test('Ok(T).isOk((_) => false) is false', () => {
    expect(Ok('value').isOk((_) => false)).toBe(false)
  })

  test('Err(E).isOk((_) => true) is true', () => {
    expect(Err(3).isOk((_) => true)).toBe(false)
  })
})

describe('Result#isErr()', () => {
  test('Ok(T).isErr() is false', () => {
    expect(Ok('value').isErr()).toBe(false)
  })

  test('Err(E).isErr() is true', () => {
    expect(Err(3).isErr()).toBe(true)
  })
})

describe('Result#map()', () => {
  test('Ok(T).map(String) is Ok(String(T))', () => {
    expect(Ok(3).map(String)).toMatchObject(Ok('3'))
    expectTypeOf(Ok(3).map(String)).toMatchTypeOf<BaseResult<string, unknown>>()
  })

  test('Err(E).map(String) is Err(E))', () => {
    expect(Err(3).map(String)).toMatchObject(Err(3))
    expectTypeOf(Err(3).map(String)).toMatchTypeOf<BaseResult<string, number>>()
  })
})

describe('Result#mapOr()', () => {
  test(`Ok(T).mapOr(String, 'five') is String(T)`, () => {
    expect(Ok(3).mapOr(String, 'five')).toBe('3')
  })

  test(`Err(E).mapOr(String, 'five') is 'five')`, () => {
    expect(Err(3).mapOr(String, 'five')).toBe('five')
  })

  test(`Ok(T).mapOr(String, () => 'five') is String(T)`, () => {
    expect(Ok(3).mapOr(String, () => 'five')).toBe('3')
  })

  test(`Err(E).mapOr(String, () => 'five') is 'five')`, () => {
    expect(Err(3).mapOr(String, () => 'five')).toBe('five')
  })
})

describe('Result#mapErr()', () => {
  const mapper = <E>(e: E) => String(e)

  test('Ok(T).mapErr((e) => String(e)) is Ok(T)', () => {
    expect(Ok(3).mapErr(mapper)).toMatchObject(Ok(3))
    expectTypeOf(Ok(3).mapErr(mapper)).toMatchTypeOf<BaseResult<unknown, string>>()
  })

  test('Err(E).mapErr((e) => String(e)) is Err(String(E)))', () => {
    expect(Err(3).mapErr(mapper)).toMatchObject(Err('3'))
    expectTypeOf(Err(3).mapErr(mapper)).toMatchTypeOf<BaseResult<unknown, string>>()
  })
})

describe('Result#inspectOk', () => {
  test('Ok(T).inspectOk((t) => result.push(t)) appends t to result', () => {
    const result: number[] = []

    expect(Ok(3).inspectOk((t) => result.push(t))).toMatchObject(Ok(3))
    expect(result).toStrictEqual([3])
  })

  test('Err(E).inspectOk((t) => result.push(t)) to do nothing', () => {
    const result: number[] = []

    expect(Err<number, number>(3).inspectOk((t) => result.push(t))).toMatchObject(Err(3))
    expect(result).toStrictEqual([])
  })
})

describe('Result#inspectErr', () => {
  test('Ok(T).inspectErr((t) => result.push(t)) to do nothing', () => {
    const result: number[] = []

    expect(Ok<number, number>(3).inspectErr((t) => result.push(t))).toMatchObject(Ok(3))
    expect(result).toStrictEqual([])
  })

  test('Err(E).inspectErr((e) => result.push(e)) appends e to result', () => {
    const result: number[] = []

    expect(Err(3).inspectErr((e) => result.push(e))).toMatchObject(Err(3))
    expect(result).toStrictEqual([3])
  })
})

describe('Result#expect', () => {
  test(`Ok(T).expect('no error') unwraps T`, () => {
    expect(Ok(3).expect('no error')).toBe(3)
  })

  test(`Err(E).expect('no error') throws Error('no error: 3')`, () => {
    const fn = () => Err(3).expect('no error')
    expect(fn).toThrowError('no error: 3')
    expect(fn).toThrowError(Error)
  })
})

describe('Result#unwrap', () => {
  test('Ok(T).unwrap() unwraps T', () => {
    expect(Ok(3).unwrap()).toBe(3)
  })

  test(`Err(E).expect('no error') throws an AppIdentityError`, () => {
    const fn = () => Err(3).unwrap()

    expect(fn).toThrowError(/Result#unwrap.+Err value: 3/)
    expect(fn).toThrowError(AppIdentityError)
  })
})

describe('Result#expectErr', () => {
  test(`Ok(T).expectErr('no error') throws Error('expected error: 3')`, () => {
    const fn = () => Ok(3).expectErr('expected error')

    expect(fn).toThrowError('expected error: 3')
    expect(fn).toThrowError(Error)
  })

  test(`Err(E).expectErr('expected error') unwraps E`, () => {
    expect(Err(3).expectErr('no error')).toBe(3)
  })
})

describe('Result#unwrapErr', () => {
  test(`Ok(T).expectErr('no error') throws an AppIdentityError`, () => {
    const fn = () => Ok(3).unwrapErr()

    expect(fn).toThrowError(/Result#unwrapErr.+Ok value: 3/)
    expect(fn).toThrowError(AppIdentityError)
  })

  test('Err(E).unwrapErr() unwraps E', () => {
    expect(Err(3).unwrapErr()).toBe(3)
  })
})

describe('Result#unwrapOr', () => {
  test('Ok(T).unwrapOr(5) unwraps T', () => {
    expect(Ok(3).unwrapOr(5)).toBe(3)
  })

  test('Err(E).unwrapOr(5) is 5', () => {
    expect(Err(3).unwrapOr(5)).toBe(5)
  })

  test('Ok(T).unwrapOr(() => 5) unwraps T', () => {
    expect(Ok(3).unwrapOr(() => 5)).toBe(3)
  })

  test('Err(E).unwrapOr(() => 5) is 5', () => {
    expect(Err(3).unwrapOr(() => 5)).toBe(5)
  })
})

describe('Result#unwrapOr', () => {
  test('Ok(T).unwrapOr(() => 5) unwraps T', () => {
    expect(Ok(3).unwrapOr(() => 5)).toBe(3)
  })

  test('Err(E).unwrapOr(() => 5) is 5', () => {
    expect(Err(3).unwrapOr(() => 5)).toBe(5)
  })
})

describe('Result#and()', () => {
  test('Ok(T).and(Ok(U)) is Ok(U)', () => {
    expect(Ok(3).and(Ok('5'))).toMatchObject(Ok('5'))
  })

  test('Ok(T).and(Err(F)) is Err(F)', () => {
    expect(Ok(3).and(Err('5'))).toMatchObject(Err('5'))
  })

  test('Err(E).and(Ok(U)) is Err(E)', () => {
    expect(Err(3).and(Ok('5'))).toMatchObject(Err(3))
  })
})

describe('Result#andThen()', () => {
  const squaredString = (x: number) => (x <= 9 ? Ok(`${x * x}`) : Err('overflowed'))

  test('Ok(T).andThen((_) => Ok(U)) is Ok(U)', () => {
    expect(Ok(3).andThen(squaredString)).toMatchObject(Ok('9'))
  })

  test('Ok(T).andThen((_) => Err(F)) is Err(F)', () => {
    expect(Ok(10).andThen(squaredString)).toMatchObject(Err('overflowed'))
  })

  test('Err(E).andThen((_) => Ok(U)) is Err(E)', () => {
    expect(Err('underflow').andThen(squaredString)).toMatchObject(Err('underflow'))
  })
})

describe('Result#or()', () => {
  test('Ok(T).or(Err(F)) is Ok(T)', () => {
    expect(Ok(3).or(Err('5'))).toMatchObject(Ok(3))
  })

  test('Err(E).or(Ok(U)) is Ok(U)', () => {
    expect(Err(3).or(Ok('5'))).toMatchObject(Ok('5'))
  })

  test('Err(E).or(Err(F)) is Err(F)', () => {
    expect(Err(3).or(Err('5'))).toMatchObject(Err('5'))
  })
})

describe('Result#orElse()', () => {
  test('Ok(T).orElse((_) => Err(F)) is Err(F)', () => {
    expect(Ok(3).orElse((_) => Err('5'))).toMatchObject(Ok(3))
  })

  test('Err(E).orElse(Ok(U)) is Ok(U)', () => {
    expect(Err(3).orElse((_) => Ok('5'))).toMatchObject(Ok('5'))
  })

  test('Err(E).orElse(Err(F)) is Err(F)', () => {
    expect(Err(3).or(Err('5'))).toMatchObject(Err('5'))
  })
})

describe('Result#match()', () => {
  test('Ok(T).match({ ok: (T) => U, err: (E) => U }) is U', () => {
    expect(Ok(3).match({ ok: (t) => String(t * t), err: String })).toBe('9')
  })

  test('Err(E).match({ ok: (T) => U, err: (E) => U }) is U', () => {
    expect(Err(3).match({ err: (e) => String(e * e), ok: String })).toBe('9')
  })
})

describe('flattenResult', () => {
  const ok_hello = Ok('hello')
  const okok_hello = Ok(ok_hello)
  const err_five: BaseResult<string, number> = Err(5)
  const okerr_five = Ok(err_five)
  const err_five_wrapped: BaseResult<BaseResult<string, number>, number> = Err(5)

  test(`Ok(Ok('hello')) => Ok('hello')`, () => {
    expect(flattenResult(okok_hello)).toMatchObject(ok_hello)
  })

  test('OK(Err(5)) => Err(5)', () => {
    expect(flattenResult(okerr_five)).toMatchObject(err_five)
  })

  test('Err(5) => Err(5)', () => {
    expect(flattenResult(err_five_wrapped)).toMatchObject(err_five)
  })
})

describe('unwrapErrs', () => {
  test('returns an empty list from [Ok, Ok]', () => {
    expect(unwrapErrs([Ok(1), Ok(3)])).toStrictEqual([])
  })

  test('returns only the errors from [Err, Ok, Err]', () => {
    expect(unwrapErrs([Err(3), Ok(1), Err('five')])).toStrictEqual([3, 'five'])
  })
})

describe('throwErrs', () => {
  test('does not throw an exception from [Ok, Ok]', () => {
    expect(() => throwErrs([Ok(1), Ok(3)], 'errors')).not.toThrowError()
  })

  test('throws a single exception from [Err, Ok, Err]', () => {
    expect(() => throwErrs([Err(3), Ok(1), Err('five')], 'errors')).toThrowError(
      'errors:\n - 3\n - five',
    )
  })

  test('throws a single exception from [Err, Ok, Err]', () => {
    expect(() => throwErrs([Err(3), Ok(1), Err('five')])).toThrowError(
      'Errors found:\n - 3\n - five',
    )
  })
})

describe('unwrapOks', () => {
  test('returns an empty list from [Err, Err]', () => {
    expect(unwrapOks([Err(1), Err(5)])).toStrictEqual([])
  })

  test('returns only the errors, as strings, from [Ok, Err, Ok]', () => {
    expect(unwrapOks([Ok(1), Err(7), Ok('nine')])).toStrictEqual([1, 'nine'])
  })
})

test('BaseResult<T, E> is explicitly abstract', () => {
  expect(() => new BaseResult()).toThrowError('BaseResult is abstract, use Ok() or Err()')

  // These are used to prove that we treat `BaseResult<T, E>` methods as abstract.
  // It's a little roundabout, but it does work.

  const ok = Ok(3)
  const err = Err(3)
  const isOk = BaseResult.prototype.isOk
  const isErr = BaseResult.prototype.isErr

  expect(() => isOk.apply(ok)).toThrowError('Abstract method Result#isOk')
  expect(() => isErr.apply(ok)).toThrowError('Abstract method Result#isErr')
  expect(() => isOk.apply(err)).toThrowError('Abstract method Result#isOk')
  expect(() => isErr.apply(err)).toThrowError('Abstract method Result#isErr')
})
