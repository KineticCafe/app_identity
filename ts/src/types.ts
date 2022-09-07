declare const id: unique symbol
/**
 * The App Identity app unique identifier. Validation of the `id` value will
 * convert non-string IDs using `toString()`.
 *
 * If using integer IDs, it is recommended that the `id` value be provided as
 * some form of extended string value, such as that provided by Rails [global
 * ID](https://github.com/rails/globalid) or the `absinthe_relay`
 * [Node.IDTranslator](https://hexdocs.pm/absinthe_relay/Absinthe.Relay.Node.IDTranslator.html).
 * Such representations are _also_ recommended if the ID is a compound value.
 *
 * ID values _must not_ contain a colon (`:`) character.
 */
export type Id = string & { [id]: void }

declare const secret: unique symbol
/**
 * The App Identity app secret value. This value is used _as provided_ with no
 * encoding or decoding. Because this is a sensitive value, it may be provided
 * as a closure function.
 *
 * {@link App} always stores this value as a closure.
 */
export type Secret = string & { [secret]: void }

declare const version: unique symbol
/**
 * The positive integer version of the App Identity algorithm to use. Will be
 * validated to be a supported version for app creation, and not an explicitly
 * disallowed version during proof validation
 *
 * If provided as a string value, it must convert cleanly to an integer value,
 * which means that a version of `"3.5"` is not a valid value.
 *
 * App Identity algorithm versions are strictly upgradeable. That is, a version
 * 1 app can verify version 1, 2, 3, or 4 proofs. However, a version 2 app will
 * _never_ validate a version 1 proof.
 *
 * <table>
 *   <thead>
 *     <tr>
 *       <th rowspan=2>Version</th>
 *       <th rowspan=2>Nonce</th>
 *       <th rowspan=2>Digest Algorithm</th>
 *       <th colspan=4>Can Verify</th>
 *     </tr>
 *     <tr><th>1</th><th>2</th><th>3</th><th>4</th></tr>
 *   </thead>
 *   <tbody>
 *     <tr><th>1</th><td>random</td><td>SHA 256</td><td>✅</td><td>✅</td><td>✅</td><td>✅</td></tr>
 *     <tr><th>2</th><td>timestamp ± fuzz</td><td>SHA 256</td><td>⛔️</td><td>✅</td><td>✅</td><td>✅</td></tr>
 *     <tr><th>3</th><td>timestamp ± fuzz</td><td>SHA 384</td><td>⛔️</td><td>⛔️</td><td>✅</td><td>✅</td></tr>
 *     <tr><th>4</th><td>timestamp ± fuzz</td><td>SHA 512</td><td>⛔️</td><td>⛔️</td><td>⛔️</td><td>✅</td></tr>
 *   </tbody>
 * </table>
 */
export type Version = number & { [version]: void }

declare const fuzz: unique symbol
/**
 * The maximum number of seconds offset for which timestamp validation will be
 * permitted.
 */
export type Fuzz = number & { [fuzz]: void }

declare const config: unique symbol
/**
 * An optional configuration value for validation of an App Identity proof.
 *
 * If not provided, the default value when required is `{fuzz: 600}`, specifying
 * that the timestamp may not differ from the current time by more than ±600
 * seconds (±10 minutes). Depending on the nature of the app being verified and
 * the expected network conditions, a shorter time period than 600 seconds is
 * recommended.
 *
 * The App Identity version 1 algorithm does not use Config.
 */
export type Config = { fuzz?: Fuzz } & { [config]: void }

declare const padlock: unique symbol
/**
 * A type representing a computed padlock.
 */
export type Padlock = string & { [padlock]: void }

declare const nonce: unique symbol
/**
 * A nonce value used in the proof algorithm. The shape of the nonce depends on
 * the algorithm version.
 *
 * Version 1 Nonce values should be cryptographically secure and non-sequential,
 * but sufficiently fine-grained timestamps (those including microseconds, as
 * `yyyymmddHHMMSS.sss`) _may_ be used. Version 1 proofs verify that the nonce
 * is at least one byte long and do not contain a colon (`:`).
 *
 * Version 2, 3, and 4 `nonce` values only permit fine-grained timestamps that
 * should be generated from a clock in sync with Network Time Protocol servers.
 * The timestamp will be parsed and compared to the server time (also in sync
 * with an NTP server).
 */
export type Nonce = string & { [nonce]: void }

declare const disallowed: unique symbol
/**
 * A list of algorithm versions that are not allowed.
 *
 * The presence of an app in this list will prevent the generation or
 * verification of proofs for the specified version.
 *
 * If `null` or an empty Set all versions are allowed.
 */
export type Disallowed = Set<Version> & { [disallowed]: void }

/**
 * An anonymous function closure around the App secret value.
 *
 * @see {@link Secret}
 */
export type WrappedSecret = () => Secret
