# App Identity Integration Testing

The reference App Identity implementations provide tools to cross-verify that
the implementations are compatible. These tools should be used by external
implementations for cross-verification as well. To cross-verify an
implementation:

- Generate a test suite and verify it with one or more reference
  implementations.
- Generate a test suite using a reference implementation and verify
  it against the implementation under test.

For example, we run suite generation for each of the Elixir, Ruby, and
Typescript implementations, and then verify each generated suite against teach
implementation, including self-verification (running the Elixir suite against
the Elixir implementation, etc.).

## Running Integration Suites

Each implementation has tooling to generate and run integration suites.

- [Elixir](../elixir/README.md#integration)
- [Ruby](../ruby/README.md#integration)
- [Typescript](../ts/README.md#integration)

## Integration Suite Definition

An App Identity integration test suite is a generated JSON file containing
a test `Suite`. Simplified, it looks like this:

```typescript
type Suite = {
  name: string
  version: string
  spec_version: number
  tests: Array<{
    description: string
    app: {
      id: number | string
      secret: string
      version: number
      config?: { fuzz?: number }
    }
    proof: string
    expect: 'pass' | 'fail'
    required: boolean
    spec_version: number
  }>
}
```

For more detail on how this is made available, see [Integration
Tooling](#integration-tooling).

## Implementation Requirements

Each conforming App Identity implementation is required to implement a suite
generator (that generates the test suite JSON) and a suite runner (that parses
and executes the test suite JSON).

### Suite Generator

The suite generator is a tool that uses a combination of the public API and
internal testing tools to generate a test suite that will be verified by one or
more other implementations. Conforming implementations **must** generate the
tests described in Required Tests and **should** generate the tests described in
Optional Tests.

The test description tables below are _informative_. The suite descriptions in
[`required.yaml`](required.yaml) and [`optional.yaml`](optional.yaml) are
_normative_, although suite implementations _usually_ use the JSON
representations.

For more detail on the suite description files, see [Integration
Tooling](#integration-tooling).

#### Required Tests

Required tests **should** be generated using only the public API of the
implementation.

In the table below, if either `Nonce` or `Fuzz` are blank, the test uses the
default values as described in the spec. Otherwise, the included values **must**
be used.

| Description                                  | Expect | App | Proof |         Nonce          | Fuzz  |
| -------------------------------------------- | :----: | :-: | :---: | :--------------------: | :---: |
| App V1, Proof V1                             | `pass` |  1  |   1   |                        |       |
| App V1, Proof V2                             | `pass` |  1  |   2   |                        |       |
| App V1, Proof V3                             | `pass` |  1  |   3   |                        |       |
| App V1, Proof V4                             | `pass` |  1  |   4   |                        |       |
| App V2, Proof V2                             | `pass` |  2  |   2   |                        |       |
| App V2, Proof V3                             | `pass` |  2  |   3   |                        |       |
| App V2, Proof V4                             | `pass` |  2  |   4   |                        |       |
| App V3, Proof V3                             | `pass` |  3  |   3   |                        |       |
| App V3, Proof V4                             | `pass` |  3  |   4   |                        |       |
| App V4, Proof V4                             | `pass` |  4  |   4   |                        |       |
| App V1, Proof V2 (custom fuzz)               | `pass` |  1  |   2   |                        | `300` |
| App V1, Proof V3 (custom fuzz)               | `pass` |  1  |   3   |                        | `300` |
| App V1, Proof V4 (custom fuzz)               | `pass` |  1  |   4   |                        | `300` |
| App V2, Proof V2 (custom fuzz)               | `pass` |  2  |   2   |                        | `300` |
| App V2, Proof V3 (custom fuzz)               | `pass` |  2  |   3   |                        | `300` |
| App V2, Proof V4 (custom fuzz)               | `pass` |  2  |   4   |                        | `300` |
| App V3, Proof V3 (custom fuzz)               | `pass` |  3  |   3   |                        | `300` |
| App V3, Proof V4 (custom fuzz)               | `pass` |  3  |   4   |                        | `300` |
| App V4, Proof V4 (custom fuzz)               | `pass` |  4  |   4   |                        | `300` |
| App V1, Proof V2 old timestamp               | `fail` |  1  |   2   | `20060102T150405.333Z` |       |
| App V1, Proof V3 old timestamp               | `fail` |  1  |   3   | `20060102T150405.333Z` |       |
| App V1, Proof V4 old timestamp               | `fail` |  1  |   4   | `20060102T150405.333Z` |       |
| App V2, Proof V2 old timestamp               | `fail` |  2  |   2   | `20060102T150405.333Z` |       |
| App V2, Proof V3 old timestamp               | `fail` |  2  |   3   | `20060102T150405.333Z` |       |
| App V2, Proof V4 old timestamp               | `fail` |  2  |   4   | `20060102T150405.333Z` |       |
| App V3, Proof V3 old timestamp               | `fail` |  3  |   3   | `20060102T150405.333Z` |       |
| App V3, Proof V4 old timestamp               | `fail` |  3  |   4   | `20060102T150405.333Z` |       |
| App V4, Proof V4 old timestamp               | `fail` |  4  |   4   | `20060102T150405.333Z` |       |
| App V1, Proof V2 old timestamp (custom fuzz) | `fail` |  1  |   2   | `20060102T150405.333Z` | `300` |
| App V1, Proof V3 old timestamp (custom fuzz) | `fail` |  1  |   3   | `20060102T150405.333Z` | `300` |
| App V1, Proof V4 old timestamp (custom fuzz) | `fail` |  1  |   4   | `20060102T150405.333Z` | `300` |
| App V2, Proof V2 old timestamp (custom fuzz) | `fail` |  2  |   2   | `20060102T150405.333Z` | `300` |
| App V2, Proof V3 old timestamp (custom fuzz) | `fail` |  2  |   3   | `20060102T150405.333Z` | `300` |
| App V2, Proof V4 old timestamp (custom fuzz) | `fail` |  2  |   4   | `20060102T150405.333Z` | `300` |
| App V3, Proof V3 old timestamp (custom fuzz) | `fail` |  3  |   3   | `20060102T150405.333Z` | `300` |
| App V3, Proof V4 old timestamp (custom fuzz) | `fail` |  3  |   4   | `20060102T150405.333Z` | `300` |
| App V4, Proof V4 old timestamp (custom fuzz) | `fail` |  4  |   4   | `20060102T150405.333Z` | `300` |

Required tests are also described in [required.json](required.json), which could
be used for code generation.

#### Optional Tests

Optional tests require additional tooling (likely used in the implementation's
unit tests) in order to craft invalid payloads. There are two sets of optional
tests. All optional tests are expected to `fail`.

The first set of tests are similar to the required `fail` tests, but require the
construction of a custom timestamp nonce using a timestamp offset from the
current time.

| Description                                     | App | Proof |     Nonce     | Fuzz  |
| ----------------------------------------------- | :-: | :---: | :-----------: | :---: |
| App V1, Proof V2 offset timestamp               |  1  |   2   | `-11 minutes` |       |
| App V1, Proof V3 offset timestamp               |  1  |   3   | `-11 minutes` |       |
| App V1, Proof V4 offset timestamp               |  1  |   4   | `-11 minutes` |       |
| App V2, Proof V2 offset timestamp               |  2  |   2   | `-11 minutes` |       |
| App V2, Proof V3 offset timestamp               |  2  |   3   | `-11 minutes` |       |
| App V2, Proof V4 offset timestamp               |  2  |   4   | `-11 minutes` |       |
| App V3, Proof V3 offset timestamp               |  3  |   3   | `-11 minutes` |       |
| App V3, Proof V4 offset timestamp               |  3  |   4   | `-11 minutes` |       |
| App V4, Proof V4 offset timestamp               |  4  |   4   | `-11 minutes` |       |
| App V1, Proof V2 offset timestamp (custom fuzz) |  1  |   2   | `-6 minutes`  | `300` |
| App V1, Proof V3 offset timestamp (custom fuzz) |  1  |   3   | `-6 minutes`  | `300` |
| App V1, Proof V4 offset timestamp (custom fuzz) |  1  |   4   | `-6 minutes`  | `300` |
| App V2, Proof V2 offset timestamp (custom fuzz) |  2  |   2   | `-6 minutes`  | `300` |
| App V2, Proof V3 offset timestamp (custom fuzz) |  2  |   3   | `-6 minutes`  | `300` |
| App V2, Proof V4 offset timestamp (custom fuzz) |  2  |   4   | `-6 minutes`  | `300` |
| App V3, Proof V3 offset timestamp (custom fuzz) |  3  |   3   | `-6 minutes`  | `300` |
| App V3, Proof V4 offset timestamp (custom fuzz) |  3  |   4   | `-6 minutes`  | `300` |
| App V4, Proof V4 offset timestamp (custom fuzz) |  4  |   4   | `-6 minutes`  | `300` |

The second set of tests require the explicit construction of bad payloads.
Where the App version column is empty, the tests **may** be generated with V1
apps only, but it is recommended that all appropriate combinations be generated.

The tests described as `Incorrect Proof ID` use a _different_ id when generating
the padlock and proof than is generated for the included app. That is, if the
app id is provided as `decafbad`, the padlock and proof might be generated with
`deadbeef`. The exact values used _do not matter_, but must differ.

The tests described as `Incorrect Secret` generate the padlock and proof with
a _different_ secret than is generated for the included app. That is, if the app
secret is `iaccepttherisk`, the padlock and proof might be generated with
`myvoiceismypassword`. The exact values used _do not matter_, but must differ.

The tests described as `Mismatched Padlock` generate the padlock with different
data than the proof. In our unit tests, we usually do this with a nonce value of
`bad padlock` for building the padlock, and the normal nonce value when generating the
proof.

| Description                   | App | Proof | Nonce                      |
| ----------------------------- | :-: | :---: | -------------------------- |
| App V1, Proof V1, Empty Nonce |  1  |   1   | empty                      |
| App V1, Proof V1, Bad Nonce   |  1  |   1   | `n:once`                   |
| Proof V2, Bad Nonce           |     |   2   | `2006-01-02T15:04:05.333Z` |
| Proof V3, Bad Nonce           |     |   3   | `2006-01-02T15:04:05.333Z` |
| Proof V4, Bad Nonce           |     |   4   | `2006-01-02T15:04:05.333Z` |
| Proof V2, Non-Timestamp Nonce |     |   2   | `nonce`                    |
| Proof V3, Non-Timestamp Nonce |     |   2   | `nonce`                    |
| Proof V4, Non-Timestamp Nonce |     |   2   | `nonce`                    |
| Proof V1, Incorrect Proof ID  |     |   1   |                            |
| Proof V2, Incorrect Proof ID  |     |   2   |                            |
| Proof V3, Incorrect Proof ID  |     |   3   |                            |
| Proof V4, Incorrect Proof ID  |     |   4   |                            |
| Proof V1, Incorrect Secret    |     |   1   |                            |
| Proof V2, Incorrect Secret    |     |   2   |                            |
| Proof V3, Incorrect Secret    |     |   3   |                            |
| Proof V4, Incorrect Secret    |     |   4   |                            |
| Proof V1, Mismatched Padlock  |     |   1   |                            |
| Proof V2, Mismatched Padlock  |     |   2   |                            |
| Proof V3, Mismatched Padlock  |     |   3   |                            |
| Proof V4, Mismatched Padlock  |     |   4   |                            |

Optional tests are also described in [optional.json](optional.json), which could
be used for code generation.

### Suite Runner

The suite runner is a tool that reads a provided test suite and verifies it
against the public API of the implementation under test. The suite runner
**must** use the [TAP][] format (version 14). The runner should accept multiple
suite files and merge them into a single set of tests for output.

The runner **must** be able to switch between normal and strict execution, and
**should** be able to enable diagnostic output. The default run mode should be
normal, non-diagnostic output.

Each suite run **must** output a TAP comment indicating the name and version of
the runner implementation and the name and version of the implementation that
created the suite. It should look something like this:

```tap
# app_identity for Elixir 1.0.0 (spec 4) testing app_identity for Ruby 1.0.0 (spec 4)
```

#### Spec Version Variants

Each test specifies a major specification version indicating the conformance
requirement. If a test specification version exceeds that supported by the
implementation under test, it **must** be skipped as `ok` with a message:

```tap
TAP Version 14
1..76
# app_identity for Elixir 1.0.0 (spec 4) testing app_identity for Ruby 1.0.0 (spec 5)
ok 1 - App V1, Proof V1
ok 2 - App V1, Proof V2
ok 3 - App V1, Proof V3
…
ok 75 - Proof V4, Mismatched Padlock
ok 76 - Basic Proof V5 Support # SKIP unsupported spec version (4 < 5)
```

#### Normal Mode

In normal mode, optional tests that fail will be flagged as `TODO`. The test
runner **must** return a failure status code if any required tests fail, but
**must not** do so if any optional tests fail.

```tap
TAP Version 14
1..75
# app_identity for Elixir 1.0.0 (spec 4) testing app_identity for Ruby 1.0.0 (spec 4)
ok 1 - App V1, Proof V1
ok 2 - App V1, Proof V2
not ok 3 - App V1, Proof V3
…
not ok 75 - Proof V4, Mismatched Padlock # TODO optional failing test
```

#### Strict Mode

In strict mode, all tests are considered required, unless there is a spec
version mismatch. If any test fails, the runner **must** return a failure status
code.

```tap
TAP Version 14
1..75
# app_identity for Elixir 1.0.0 (spec 4) testing app_identity for Ruby 1.0.0 (spec 4)
ok 1 - App V1, Proof V1
ok 2 - App V1, Proof V2
not ok 3 - App V1, Proof V3
…
not ok 75 - Proof V4, Mismatched Padlock
```

#### Diagnostic Output

If diagnostic output can be enabled, it **must** use the [YAML diagnostic
format][yaml] to output the details of the failure. This may require the use of
non-public APIs in the implementation.

```tap
TAP Version 14
1..75
# app_identity for Elixir 1.0.0 (spec 4) testing app_identity for Ruby 1.0.0 (spec 4)
ok 1 - App V1, Proof V1
ok 2 - App V1, Proof V2
ok 3 - App V1, Proof V3
…
not ok 75 - Proof V4, Mismatched Padlock
  ---
  message: padlock does not match
  ...
```

## Integration Tooling

There is tooling present that assists with the definition and development of the
integration suite JSON schema and the definition of the integration suites.

There is a `Makefile` to convert the support files from their canonical formats
to the commonly-used support formats.

### Integration Suite Specification

Integration suites are defined by a JSON schema, [`schema.json`](schema.json).
This file is generated from [`shema.ts`](schema.ts) using
`ts-json-schema-generator`.

If a suite specification modification is required, the [`shema.ts`](schema.ts)
should be modified directly and JSON schema should be generated with `make schema.json`.

### Suite Description Files

The tests that should be generated by a [suite generator](#suite-generator) are
described by the files [`required.yaml`](required.yaml) and
[`optional.yaml`](optional.yaml). The suite _descriptions_ are used by a suite
generator to generate a test suite.

When implementing an integration suite generator, it is recommended that you
study one or more of the reference implementation generators:

- Elixir: [`support/app_identity/suite/generator.ex`](../elixir/support/app_identity/suite/generator.ex)
- Ruby: [`lib/app_identity/suite/generator.rb`](../ruby/lib/app_identity/suite/generator.rb)
- Typescript: [`support/generator.ts`](../ts/support/generator.ts)

### `tapview`

For condensed TAP output, we have included Eric S. Raymond's `tapview` verison
1.3 in the integration directory.

> tapview - a TAP (Test Anything Protocol) viewer in pure POSIX shell
>
> Copyright by Eric S. Raymond
>
> This code is intended to be embedded in your project. The author grants
> permission for it to be distributed under the prevailing license of your
> project if you choose, provided that license is OSD-compliant; otherwise the
> following SPDX tag incorporates a license by reference.
>
> SPDX-License-Identifier: BSD-2-Clause
>
> This is version 1.3
> A newer version may be available at https://gitlab.com/esr/tapview

[tap]: https://testanything.org/tap-version-14-specification.html
[yaml]: https://testanything.org/tap-version-14-specification.html#yaml-diagnostics
