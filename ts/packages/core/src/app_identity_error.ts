/**
 * All exceptions raised by App Identity functions will be instances of this
 * Error class.
 */
export class AppIdentityError extends Error {
  constructor(message?: string) {
    super(message)
    this.name = 'AppIdentityError'
    Object.setPrototypeOf(this, AppIdentityError.prototype)
  }
}
