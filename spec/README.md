# App Identity Specification

App Identity provides a fast, lightweight, cryptographically secure app
authentication mechanism as an improvement over just using API keys or app IDs.
It does this by computing a proof with an application identifier, a nonce, an
application secret key, and a hashing algorithm. The secret key is embedded in
client applications and stored securely on the server, so it is never passed
over the wire.

## Terminology Notes

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be
interpreted as described in [RFC2199][rfc2119].

Only the text of this specification is _normative_. Code examples in this
document are _informative_ and may have bugs.

## Version and Versioning

This specification is versioned with a modified [Semantic Versioning][] scheme.
The major version of the specification will always be the highest algorithms
version defined. Minor versions may adjust the text of the specification.

As the current specification defines four algorithm versions, the current
specification is `4.0`.

## Application

For the purposes of this specification, an `application` requires the following
attributes:

- `id`: The unique identifier of the application. It is recommended that this
  value is a `UUID`. When using an integer identifier, it is recommended that
  this value be extended, such as that provided by Rails [global ID][global id].
  Such representations are _also_ recommended if the ID is a compound value.
  Non-string identifiers must be converted to string values.

- `secret`: The random value used as the secret key. This value _must_ be used
  as presented (if presented as a base-64 value, the secret _is_ the base-64
  value, not a decoded version of it).

- `version`: The minimum algorithm version supported by the application, an
  integer value. The reference implementations of App Identity do not currently
  restrict the `version` for compatibility purposes, but new applications
  **should not** use version 1 applications.

- `config`: A configuration object. As of this writing, only one key for this
  object is defined when `version` 2 or higher. The `config` only affects proof
  verification.

  - `fuzz`: The fuzziness of time stamp comparison, in seconds, for version `2`
    or higher algorithms. If not present, defaults to `600` seconds, or ±600
    seconds (±10 minutes). Depending on the nature of the app being verified and
    the expected network conditions, a shorter time period than 600 seconds is
    recommended.

### Suggested Extra Fields

The following fields are recommended for use on by proof verifiers.

- `code`: A unique text identifier for the application. Not used in the proof
  algorithm, but used to manage the application on the servers.

- `name`: A displayable name for the application. Not used in the proof
  algorithm, but used for human consumption.

- `type`: The type of the application. Because the server deals with many types
  of applications, this value may be used to _limit_ access to APIs to only type
  of applications.

## Algorithm Versions

The algorithm version controls both the shape of the nonce and the specific
algorithm chosen for hashing. Versions are _strictly upgradeable_. That is,
a version 1 app can verify version 1, 2, 3, or 4 proofs. However, a version
2 app will _never_ validate a version 1 proof.

<table>
  <thead>
    <tr>
      <th rowspan=2>Version</th>
      <th rowspan=2>Nonce</th>
      <th rowspan=2>Digest Algorithm</th>
      <th colspan=4>Can Verify</th>
    </tr>
    <tr><th>1</th><th>2</th><th>3</th><th>4</th></tr>
  </thead>
  <tbody>
    <tr><th>1</th><td>random</td><td>SHA 256</td><td>✅</td><td>✅</td><td>✅</td><td>✅</td></tr>
    <tr><th>2</th><td>timestamp ± fuzz</td><td>SHA 256</td><td>⛔️</td><td>✅</td><td>✅</td><td>✅</td></tr>
    <tr><th>3</th><td>timestamp ± fuzz</td><td>SHA 384</td><td>⛔️</td><td>⛔️</td><td>✅</td><td>✅</td></tr>
    <tr><th>4</th><td>timestamp ± fuzz</td><td>SHA 512</td><td>⛔️</td><td>⛔️</td><td>⛔️</td><td>✅</td></tr>
  </tbody>
</table>

## Identity Proof

The client identity proof is a short signed value, composed from the _id_,
a _nonce_, and an intermediary _padlock_ generated using the _application
secret_. The application id and secret will be provided securely for
compile-time inclusion; all care should be taken to ensure that the secret is
not easily extractable from the application or shared in the clear.

The generation of a proof looks like this:

    padlock = Padlock(Version, Identity, Nonce, Secret)
    proof = Proof(Version, Identity, Nonce, padlock)

The verification of a proof looks like this:

    (Version, Identity, Nonce, padlock) = Parse(proof)
    app = FindApplication(Identity)
    padlockʹ = Padlock(Version, app.Identity, Nonce, app.Secret)
    proofʹ = Proof(Version, Identity, Nonce, padlockʹ)

    ConstantTimeEqualityComparison(proof, proofʹ)

### Nonce

Depending on the version of the application algorithm, the _nonce_ may contain
any byte sequences _except_ ASCII colon (`:`), but it is recommended that the
value be UTF-8 safe.

#### Random Nonces

Version 1 nonces should be cryptographically secure and non-sequential, but
sufficiently fine-grained timestamps (those including microseconds, as
`yyyymmddHHMMSS.sss`) _may_ be used. Version 1 proofs verify that the nonce is
at least one byte long and do not contain a colon (`:`).

**Ruby**:

```ruby
require 'securerandom'
nonce1 = SecureRandom.urlsafe_base64(32)
nonce2 = SecureRandom.hex(32)
```

**Elixir**:

```elixir
# Elixir
Base.url_encode64(:crypto.strong_rand_bytes(32), padding: true)
Base.encode16(:crypto.strong_rand_bytes(32))
```

**Typescript (Node)**:

```typescript
import { randomBytes } from 'crypto'
import base64url from 'base64-url' // https://www.npmjs.com/package/base64-url

base64url.encode(randomBytes(32).toString())
```

**Swift**:

```swift
func secure_random_base64_bytes(count: Int32 = 16) -> String? {
  var data = Data(count: count)
  let result = data.withUnsafeMutableBytes {
    SecRandomCopyBytes(kSecRandomDefaults, data.count, $0)
  }
  if result == errSecSuccess {
    return data.base64EncodedString()
  } else {
    return nil
  }
}

secure_random_base64_bytes(32)
```

#### Timestamp Nonces

Version 2, 3, and 4 nonces **must** be a UTC timestamp formatted using ISO
8601 basic formatting. The timestamp _should_ be generated on a clock synced with
NTP and _should_ be verified using a clock synced with NTP.

For the purposes of this document, ISO 8601 basic formatting uses the
following [ABNF][] format, adapted from [RFC3339][]:

```abnf
date-fullyear = 4DIGIT
date-month    = 2DIGIT  ; 01-12
date-mday     = 2DIGIT  ; 01-28, 01-29, 01-30, 01-31 based on
                        ; month/year
time-hour     = 2DIGIT  ; 00-23
time-minute   = 2DIGIT  ; 00-59
time-second   = 2DIGIT  ; 00-58, 00-59, 00-60 based on leap second
                        ; rules
time-secfrac  = "." 1\*DIGIT
time-offset   = "Z"

partial-time  = time-hour time-minute time-second [time-secfrac]
full-date     = date-fullyear date-month date-mday
full-time     = partial-time time-offset

date-time     = full-date "T" full-time
```

The timestamp must be an ASCII 7-bit or UTF-8 string using only ASCII
characters, and the special characters `T` and `Z` **must** be specified
uppercase.

This format differs from [RFC3339][] [§5.6][§5.6] timestamp format in the
following ways:

1. It **must** be UTC and the timezone character must be `Z`. No other timezone
   specifier is permitted, and it must not be omitted.
2. It **must** only have the characters `[.0-9TZ]`. It **may** have the point
   character (`.`) only preceding the _optional_ fractional seconds digits.

Therefore, a timestamp of `2020-02-25T23:20:03.321423-04:00` must be presented
as `20200225T192003.321423Z`.

C-style `strftime` formatting for this format would be `'%Y%m%dT%H%M%S.%6NZ'`,
and a PostgreSQL format for `TO_CHAR()` would `'YYYYMMDD"T"HH24MISS.FF6Z'`.

**Ruby**:

```ruby
require 'time'
Time.now.utc.strftime('%Y%m%dT%H%M%S.%6NZ')
```

**Elixir**:

```elixir
case DateTime.now("Etc/UTC") do
  {:ok, stamp} ->
    {:ok, DateTime.to_iso8601(stamp, :basic)}

  {:error, reason} ->
    {:error, String.replace(Kernel.to_string(reason), "_", " ")}
end
```

**Typescript (Node)**:

```typescript
new Date().toISOString().replace(/[-:]/g, '')
```

**Swift**:

```swift
func secure_random_base64_bytes(count: Int32 = 16) -> String? {
  var data = Data(count: count)
  let result = data.withUnsafeMutableBytes {
    SecRandomCopyBytes(kSecRandomDefaults, data.count, $0)
  }
  if result == errSecSuccess {
    return data.base64EncodedString()
  } else {
    return nil
  }
}

secure_random_base64_bytes(32)
```

### Padlock Calculation

To compute the padlock value, concatenate the application id, the nonce, and the
application secret using colons, then calculate the digest of the value and
convert to a base 16 string representation. As noted previously, the digest
algorithm used varies based on the application version.

**Ruby**:

```ruby
require 'digest/sha2'
Digest::SHA256.hexdigest([version, id, nonce, secret].join(':')).upcase
```

**Elixir**:

```elixir
[id, nonce, secret]
|> Enum.join(":")
|> then(&:crypto.hash(:sha256, &1))
|> Base.encode16(case: :upper)
```

**Typescript (Node)**:

```typescript
import { createHash } from 'crypto'
const hash = createHash('sha384')
hash.update(raw, 'utf-8')
hash.digest('hex').toUpperCase()
```

**Swift**:

```swift
// Swift
extension Data {
  func hexString() -> String {
    return self.map {
        Int($0).hexString()
    }.joined()
  }

  func SHA256() -> Data {
    var result = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
    _ = result.withUnsafeMutableBytes {
      resultPtr in self.withUnsafeBytes {
        CC_SHA256($0, CC_LONG(count), resultPtr)
      }
    }
    return result
  }
}

extension String {
  func hexString() -> String {
    return self.data(using: .utf8)!.hexString()
  }

  func SHA256() -> String {
    return self.data(using: .utf8)!.SHA256().hexString()
  }
}

let value = "\(id):\(nonce):\(secret)"
let padlock = value.SHA256()
```

**Java**:

```java
// Java (Android)
String value = id + ":" + nonce + ":" + secret;
MessageDigest digest = MessageDigest.getInstance("SHA-256");
byte[] hash = digest.digest(msg.getBytes(StandardCharsets.UTF_8));
StringBuffer padlock = new StringBuffer();

for (int i = 0; i < hash.length; i++) {
  String hex = Integer.toHexString(0xFF & hash[i]);
  if (hex.length() == 1) {
    padlock.append('0');
  }

  padlock.append(hex);
}
```

Validation of the padlock will convert this digest to uppercase, so the values
`c0ffee` and `C0FFEE` are identical. It is recommended that padlocks be passed
as uppercase hex values.

### Padlock Presentation

The padlock cannot be presented by itself, because the digest used are one-way
cryptographic hashes. Therefore, the client must supply the id (used to find the
client definition on the server) and the nonce (because the nonce is generated
by the client application and not known by the server). This will typically be
provided as a concatenated, base-64-encoded string:

**Ruby**:

```ruby
require 'base64'
# Version 1
Base64.urlsafe_encode64([id, nonce, padlock].join(':'))
# Version 2+
Base64.urlsafe_encode64([version, id, nonce, padlock].join(':'))
```

**Elixir**:

```elixir
[version, id, nonce, padlock]
|> Enum.join(":")
|> Base.urlsafe_encode64(padding: false)
```

**Swift**:

```swift
let value = "\(version):\(id):\(nonce):\(padlock)"
let proof = Data(value.utf8).base64EncodedString()
```

**Typescript**:

```typescript
import base64url from 'base64-url' // https://www.npmjs.com/package/base64-url
const parts = version === 1 ? [id, nonce, padlock] : [version, id, nonce, padlock]
base64url.encode(parts.join(':'))
```

**Java**:

```java
String value = version + ":" + id + ":" + nonce + ":" + padlock.toString();
byte[] encodedHash = Base64.getEncoder().encode(encodeValue.getBytes());
String proof = new String(encodedHash, "UTF-8");
```

[global id]: https://github.com/rails/globalid
[rfc2119]: https://datatracker.ietf.org/doc/html/rfc2119
[rfc3339]: https://datatracker.ietf.org/doc/html/rfc3339
[§5.6]: https://tools.ietf.org/html/rfc3339#section-5.6
[semantic versioning]: http://semver.org/
[abnf]: https://www.rfc-editor.org/rfc/rfc2234.txt
