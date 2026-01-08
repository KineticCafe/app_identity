import { AppIdentityError } from './app_identity_error.js'

export class BaseResult<T, E> {
  constructor() {
    if (this.constructor === BaseResult) {
      throw new Error('BaseResult is abstract, use Ok() or Err()')
    }
  }

  isOk(_pred?: (val: T) => boolean): boolean {
    this.abstractMethod('isOk')
  }

  isErr(_pred?: (val: E) => boolean): boolean {
    this.abstractMethod('isErr')
  }

  map<U>(_fn: (val: T) => U): BaseResult<U, E> {
    this.abstractMethod('map')
  }

  mapOr<U>(_fn: (val: T) => U, _defaultValue: U | ((err: E) => U)): U {
    this.abstractMethod('mapOr')
  }

  mapErr<F>(_fn: (val: E) => F): BaseResult<T, F> {
    this.abstractMethod('mapErr')
  }

  inspectOk(_fn: (val: T) => void): BaseResult<T, E> {
    this.abstractMethod('inspectOk')
  }

  inspectErr(_fn: (val: E) => void): BaseResult<T, E> {
    this.abstractMethod('inspectErr')
  }

  expect(_message: string): T | never {
    this.abstractMethod('expect')
  }

  unwrap(): T | never {
    this.abstractMethod('unwrap')
  }

  expectErr(_message: string): E | never {
    this.abstractMethod('expectErr')
  }

  unwrapErr(): E | never {
    this.abstractMethod('unwrapErr')
  }

  unwrapOr(_defaultValue: T | ((err: E) => T)): T {
    this.abstractMethod('unwrapOr')
  }

  and<U>(_result: BaseResult<U, E>): BaseResult<U, E> {
    this.abstractMethod('and')
  }

  andThen<U>(_fn: (val: T) => BaseResult<U, E>): BaseResult<U, E> {
    this.abstractMethod('andThen')
  }

  or<F>(_result: BaseResult<T, F>): BaseResult<T, F> {
    this.abstractMethod('or')
  }

  orElse<F>(_fn: (val: E) => BaseResult<T, F>): BaseResult<T, F> {
    this.abstractMethod('orElse')
  }

  match<U>(_matcher: { ok: (t: T) => U; err: (e: E) => U }): U {
    this.abstractMethod('match')
  }

  private abstractMethod(method: string): never {
    throw new Error(`Abstract method Result#${method}`)
  }
}

class OkBaseResult<T, E> extends BaseResult<T, E> {
  private readonly ok: T

  constructor(ok: T) {
    super()
    this.ok = ok
  }

  override isOk(pred?: (val: T) => boolean): boolean {
    return pred ? pred(this.ok) : true
  }

  override isErr(_pred?: (val: E) => boolean): boolean {
    return false
  }

  override map<U>(fn: (val: T) => U): BaseResult<U, E> {
    return Ok(fn(this.ok))
  }

  override mapOr<U>(fn: (val: T) => U, _defaultValue: U | ((err: E) => U)): U {
    return fn(this.ok)
  }

  override mapErr<F>(_fn: (val: E) => F): BaseResult<T, F> {
    return Ok(this.ok)
  }

  override inspectOk(fn: (val: T) => void): BaseResult<T, E> {
    fn(this.ok)

    return this
  }

  override inspectErr(_fn: (val: E) => void): BaseResult<T, E> {
    return this
  }

  override expect(_message: string): T {
    return this.ok
  }

  override unwrap(): T | never {
    return this.ok
  }

  override expectErr(message: string): never {
    return unwrapFailed(message, this.ok)
  }

  override unwrapErr(): never {
    return unwrapFailed('Called Result#unwrapErr on an Ok value', this.ok)
  }

  override unwrapOr(_defaultValue: T | ((err: E) => T)): T {
    return this.ok
  }

  override and<U>(result: BaseResult<U, E>): BaseResult<U, E> {
    return result
  }

  override andThen<U>(fn: (val: T) => BaseResult<U, E>): BaseResult<U, E> {
    return fn(this.ok)
  }

  override or<F>(_result: BaseResult<T, F>): BaseResult<T, F> {
    return Ok(this.ok)
  }

  override orElse<F>(_fn: (val: E) => BaseResult<T, F>): BaseResult<T, F> {
    return Ok(this.ok)
  }

  override match<U>(matcher: { ok: (t: T) => U; err: (e: E) => U }): U {
    return matcher.ok(this.ok)
  }
}

class ErrBaseResult<T, E> extends BaseResult<T, E> {
  private readonly err: E

  constructor(err: E) {
    super()
    this.err = err
  }

  override isOk(_pred: (val: T) => boolean): boolean {
    return false
  }

  override isErr(pred: (val: E) => boolean): boolean {
    return pred ? pred(this.err) : true
  }

  override map<U>(_fn: (val: T) => U): BaseResult<U, E> {
    return Err(this.err)
  }

  override mapOr<U>(_fn: (val: T) => U, defaultValue: U | ((err: E) => U)): U {
    const isFunction = (value: U | ((err: E) => U)): value is (err: E) => U =>
      typeof value === 'function'

    return isFunction(defaultValue) ? defaultValue(this.err) : defaultValue
  }

  override mapErr<F>(fn: (val: E) => F): BaseResult<T, F> {
    return Err(fn(this.err))
  }

  override inspectOk(_fn: (val: T) => void): BaseResult<T, E> {
    return this
  }

  override inspectErr(fn: (val: E) => void): BaseResult<T, E> {
    fn(this.err)

    return this
  }

  override expect(message: string): never {
    return unwrapFailed(message, this.err)
  }

  override unwrap(): never {
    return unwrapFailed('Called Result#unwrap on an Err value', this.err)
  }

  override expectErr(_message: string): E {
    return this.err
  }

  override unwrapErr(): E | never {
    return this.err
  }

  override unwrapOr(defaultValue: T | ((err: E) => T)): T {
    const isFunction = (value: T | ((err: E) => T)): value is (err: E) => T =>
      typeof value === 'function'

    return isFunction(defaultValue) ? defaultValue(this.err) : defaultValue
  }

  override and<U>(_result: BaseResult<U, E>): BaseResult<U, E> {
    return Err(this.err)
  }

  override andThen<U>(_fn: (val: T) => BaseResult<U, E>): BaseResult<U, E> {
    return Err(this.err)
  }

  override or<F>(result: BaseResult<T, F>): BaseResult<T, F> {
    return result
  }

  override orElse<F>(fn: (val: E) => BaseResult<T, F>): BaseResult<T, F> {
    return fn(this.err)
  }

  override match<U>(matcher: { ok: (t: T) => U; err: (e: E) => U }): U {
    return matcher.err(this.err)
  }
}

export const Ok = <T, E>(ok: T): BaseResult<T, E> => new OkBaseResult<T, E>(ok)
export const Err = <T, E>(err: E): BaseResult<T, E> => new ErrBaseResult<T, E>(err)
export type Result<T> = BaseResult<T, string>

export const flattenResult = <T, E>(
  value: BaseResult<BaseResult<T, E>, E>,
): BaseResult<T, E> => {
  return value.isOk() ? value.unwrap() : Err(value.unwrapErr())
}

export const isOk = <T, E>(value: BaseResult<BaseResult<T, E>, E>): boolean =>
  value.isOk()

export const isErr = <T, E>(value: BaseResult<BaseResult<T, E>, E>): boolean =>
  value.isErr()

// biome-ignore lint/suspicious/noExplicitAny: insufficient inference
export const unwrapErrs = <L extends BaseResult<any, any>[]>(
  results: L,
): InferErr<L[number]>[] => results.filter((v) => v.isErr()).map((v) => v.unwrapErr())

// biome-ignore lint/suspicious/noExplicitAny: insufficient inference
export const throwErrs = <L extends BaseResult<any, any>[]>(
  results: L,
  message?: string,
): void => {
  const errors = unwrapErrs(results)

  if (errors.length > 0) {
    const msg =
      message == null
        ? 'Errors found:\n'
        : message.length === 0
          ? ''
          : message.endsWith(':')
            ? `${message}\n`
            : `${message}:\n`

    throw new AppIdentityError(`${msg}${errors.map((e) => ` - ${e}`).join('\n')}`)
  }
}

// biome-ignore lint/suspicious/noExplicitAny: insufficient inference
export const unwrapOks = <L extends BaseResult<any, any>[]>(
  results: L,
): InferOk<L[number]>[] => results.filter((v) => v.isOk()).map((v) => v.unwrap())

type InferOk<R> = R extends BaseResult<infer T, unknown> ? T : never
type InferErr<R> = R extends BaseResult<unknown, infer E> ? E : never

const unwrapFailed = <E>(message: string, err: E): never => {
  throw new AppIdentityError(`${message}: ${err}`)
}
