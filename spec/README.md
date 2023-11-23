# App Identity Specification

App Identity provides a fast, lightweight, cryptographically secure app
authentication mechanism as an improvement over just using API keys or app IDs.
It does this by computing a proof with an application identifier, a nonce, an
application secret key, and a hashing algorithm. The secret key is embedded in
client applications and stored securely on the server, so it is never passed
over the wire.

## Terminology and Typographic Notes

The key words **must**, **must not**, **required**, **shall**, **shall not**,
**should**, **should not**, **recommended**, **may**, and **optional** in this
document are to be interpreted as described in [RFC2199][rfc2119].

Core algorithmic concepts will be expressed with _emphasis_.

Only the text of this specification is normative. Code examples in this document
are informative and may have bugs.

## Version and Versioning

This specification is versioned with a modified [Semantic Versioning][] scheme.
The major version of the specification will always be the number of algorithm
versions defined. Minor versions of the specification **may** be used adjust the
text.

The current specification is 4.2.

## Application

For the purposes of this specification, an application **requires** the
following attributes:

- `id`: The unique identifier of the application, which **must** be presented as
  a string. Identifiers **must not** include an ASCII colon (`:`) or they
  **must** be encoded and validating servers must know how to locate
  applications encoded this way.

  It is **recommended** that this value be globally unique and extremely
  difficult to guess. Identifier types meeting such criteria include UUIDs
  ([version 4][uuidv4], [version 7][uuidv7], or [version 8][uuidv8]),
  [ULID][ulid], or [ksuid][ksuid].

  Identifiers **may** include a class identifier (such as `appid=1234`, or the
  Rails [Global ID][global id] format). If an identifier is short, an integer,
  or a compound value, the use of a class identifier is **recommended**.

- `secret`: The random value used as the secret key. This value **must** be used
  as presented. That is, if the secret is presented as a Base64 value, the
  secret is the Base64 value, not a decoded version of it.

  Application secrets **should** be prefixed with a fixed value, such as
  `appid_`. This improves the ability of security tools (such as [gitleaks][],
  [GitGuardian][], or [GitHub secret scanning][]) to detect that an application
  secret key has been leaked.

  Where possible, implementations **should** use memory-safe storage for the
  `secret` value and **must** prevent accidental exposure of the secret in logs
  through normal object introspection.

  > All reference implementations use no-argument closures to store the secret
  > in memory, which prevents accidental logging of the secret. In addition,
  > custom inspect functions have been implemented which hides the secret value
  > by default.

- `version`: The minimum algorithm version supported by the application, an
  integer value. The reference implementations of App Identity do not restrict
  the `version` for backwards compatibility purposes, but new services
  **should** consider version 1 applications deprecated.

- `config`: A configuration object which affects proof verification. Only one
  key for this object is defined when `version` 2 or higher. The `config` only
  affects proof verification.

  - `fuzz`: The fuzziness of time stamp comparison, in seconds, for version `2`
    or higher algorithms. If not present, defaults to `600` seconds, or ±600
    seconds (±10 minutes). Depending on the nature of the app being verified and
    the expected network conditions, a shorter time period than 600 seconds is
    **recommended**.

### Suggested Extra Fields

The following fields are suggested for use in defining applications.

- `code`: A unique text identifier for the application. Not used in the proof
  algorithm, but used to manage the application on the servers.

- `name`: A displayable name for the application. Not used in the proof
  algorithm, but used for human consumption.

- `type`: The type of the application. Because the server deals with many types
  of applications, this value may be used to limit access to APIs to only type
  of applications.

## Algorithm Versions

The algorithm version controls both the shape of the nonce and the specific
algorithm chosen for hashing. Versions are strictly upgradeable. A version 1 app
can verify version 1, 2, 3, or 4 proofs. However, a version 2 app will never
validate a version 1 proof.

<table>
  <thead>
    <tr>
      <th rowspan=2>App Identity<br />Version</th>
      <th rowspan=2>Nonce</th>
      <th rowspan=2>Digest Algorithm</th>
      <th colspan=4>Can Verify Proof<br />from Version</th>
    </tr>
    <tr><th>1</th><th>2</th><th>3</th><th>4</th></tr>
  </thead>
  <tbody>
    <tr>
      <th>1</th>
      <td>random</td>
      <td>SHA2-256</td>
      <td align="center">Yes</td>
      <td align="center">Yes</td>
      <td align="center">Yes</td>
      <td align="center">Yes</td>
    </tr>
    <tr>
      <th>2</th>
      <td>timestamp ± fuzz</td>
      <td>SHA2-256</td>
      <td align="center">-</td>
      <td align="center">Yes</td>
      <td align="center">Yes</td>
      <td align="center">Yes</td>
    </tr>
    <tr>
      <th>3</th>
      <td>timestamp ± fuzz</td>
      <td>SHA2-384</td>
      <td align="center">-</td>
      <td align="center">-</td>
      <td align="center">Yes</td>
      <td align="center">Yes</td>
    </tr>
    <tr>
      <th>4</th>
      <td>timestamp ± fuzz</td>
      <td>SHA2-512</td>
      <td align="center">-</td>
      <td align="center">-</td>
      <td align="center">-</td>
      <td align="center">Yes</td>
    </tr>
  </tbody>
</table>

## Identity Proof

The client identity proof is a short, cryptographically signed value, composed
from the _id_, a _nonce_, and an intermediary _padlock_ generated using the
application _secret_. The application _id_ and _secret_ **should** be provided
securely for compile-time inclusion; all care **should** be taken to ensure that
the secret is not easily extractable from the application or shared in the
clear.

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
any byte sequences except ASCII colon (`:`), but it is **recommended** that
the value be UTF-8 safe.

#### Random Nonces

Version 1 nonces **should** be cryptographically secure and non-sequential, but
sufficiently fine-grained timestamps (those including microseconds, as
`yyyymmddHHMMSS.sss`) **may** be used. Version 1 proofs verify that the nonce is
at least one byte long and do not contain an ASCII colon (`:`).

**Typescript (Node)**:

```typescript
import { randomBytes } from 'crypto'
import base64url from 'base64-url' // https://www.npmjs.com/package/base64-url

base64url.encode(randomBytes(32).toString())
```

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

Version 2, 3, and 4 nonces **must** be a UTC timestamp formatted using ISO 8601
basic formatting. The clocks of the generating and verifying systems **must** be
synchronized for the verification to work as intended, so NTP is strongly
**recommended**.

For the purposes of this document, ISO 8601 basic formatting is this [ABNF][]
definition adapted from [RFC3339][]:

```abnf
date-fullyear = 4DIGIT
date-month    = 2DIGIT  ; 01-12
date-mday     = 2DIGIT  ; 01-28, 01-29, 01-30, 01-31 based on
                        ; month/year
time-hour     = 2DIGIT  ; 00-23
time-minute   = 2DIGIT  ; 00-59
time-second   = 2DIGIT  ; 00-58, 00-59, 00-60 based on leap second
                        ; rules
time-secfrac  = "." 1*DIGIT
time-offset   = "Z"

partial-time  = time-hour time-minute time-second [time-secfrac]
full-date     = date-fullyear date-month date-mday
full-time     = partial-time time-offset

date-time     = full-date "T" full-time
```

This format differs from [RFC3339][] [§5.6][§5.6] timestamp format in the
following ways:

1. It **must** be UTC and the timezone character **must** be `Z`. No other
   timezone specifier is permitted, and it **must not** be omitted.
2. It **must** only have the ASCII characters `[.0-9TZ]`. It **may** have the
   point character (`.`) only preceding the optional fractional seconds digits.

Therefore, a timestamp of `2020-02-25T23:20:03.321423-04:00` **must** be
presented as `20200225T192003.321423Z`.

The C-style `strftime` pattern for this format is `'%Y%m%dT%H%M%S.%6NZ'`, and
the PostgreSQL `TO_CHAR` pattern is `'YYYYMMDD"T"HH24MISS.FF6Z'`.

**Typescript (Node)**:

```typescript
new Date().toISOString().replace(/[-:]/g, '')
```

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

### Padlock Calculation

To compute the padlock value:

1. Concatenate the application _id_, the _nonce_, and the application _secret_
   with ASCII colon (`:`) between each part.
2. Calculate the digest of the above value.
3. Convert to a base 16 string representation.

As noted previously, the digest algorithm used varies based on the application
version.

**Typescript (Node)**:

```typescript
// This demonstrates a version 3 padlock
import { createHash } from 'crypto'
const hash = createHash('sha384')
hash.update(raw, 'utf-8')
hash.digest('hex').toUpperCase()
```

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
`c0ffee` and `C0FFEE` are identical. It is **recommended** that padlocks be
passed as uppercase hex values.

### Proof Presentation

Clients **must** present the computed _padlock_ to the server in a way that
allows verification. This is called the _proof_, which contains the algorithm
_version_, the application _id_, the _nonce_, and the _padlock_. It is typically
provided as a single concatenated string (using colons) and then Base64 encoded.

**Typescript (Node)**:

```typescript
import base64url from 'base64-url' // https://www.npmjs.com/package/base64-url
base64url.encode([version, id, nonce, padlock].join(':'))
```

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
[gitguardian]: https://www.gitguardian.com
[gitleaks]: https://gitleaks.io
[github secret scanning]: https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning
[uuidv4]: https://datatracker.ietf.org/doc/html/draft-ietf-uuidrev-rfc4122bis#name-uuid-version-4
[uuidv7]: https://datatracker.ietf.org/doc/html/draft-ietf-uuidrev-rfc4122bis#name-uuid-version-7
[uuidv8]: https://datatracker.ietf.org/doc/html/draft-ietf-uuidrev-rfc4122bis#name-uuid-version-8
[ulid]: https://github.com/ulid/spec
[ksuid]: https://github.com/segmentio/ksuid
