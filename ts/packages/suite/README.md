# @kineticcafe/app-identity-suite-ts 2.0.0: AppIdentity for JavaScript

- code :: https://github.com/KineticCafe/app-identity/tree/main/ts/
- issues :: https://github.com/KineticCafe/app-identity/issues

## Description

@kineticcafe/app-identity-suite-ts is the [integration test][] tool for
AppIdentity for JavaScript.

## Synopsis

```console
$ npm install --global @kineticcafe/app-identity-suite-ts
$ app-identity-suite-ts generate --stdout | app-identity-suite-ts run --stdin
TAP Version 14
1..78
# generator: @kineticcafe/app-identity 2.0.0 (@kineticcafe/app-identity-node, spec 4)
# runner: @kineticcafe/app-identity 2.0.0 (@kineticcafe/app-identity-node, spec 4)
ok 1 - App V1, Proof V1
ok 2 - App V1, Proof V2
ok 3 - App V1, Proof V3
ok 76 - Proof V2, Mismatched Padlock
ok 77 - Proof V3, Mismatched Padlock
ok 78 - Proof V4, Mismatched Padlock
```

### `app-identity-suite-ts generate`

Generates an integration test suite JSON file, defaulting to
`app-identity-suite-ts.json`.

- **Usage**: `app-identity-suite-ts generate [options] [suite]`
- **Options**:
  - `--stdout`: Prints the suite to standard output instead of saving it
  - `-q`, `--quiet`: Silences diagnostic messages

### `app-identity-suite-ts generate`

Runes one or more integration suites.

- **Usage**: `app-identity-suite-ts run [options] [paths...]`
- **Options**:
  - `-S`, `--strict`: Runs in strict mode; optional tests will cause failure
  - `--stdin`: Reads a suite from standard input
  - `-D`, `--diagnostic`: Enables output diagnostics

## Installation

@kineticcafe/app-identity-suite-ts can be installed globally or locally, as
required.

```sh
npm install --global @kineticcafe/app-identity-suite-ts@^2.0
```

## Semantic Versioning

`AppIdentity` uses a [Semantic Versioning][] scheme with one significant change:

- When PATCH is zero (`0`), it will be omitted from version references.

Additionally, the major version will generally be reserved for specification
revisions.

## Contributing

AppIdentity for JavaScript [welcomes contributions][]. This project, like all Kinetic
Commerce [open source projects][], is under the Kinetic Commerce Open Source
[Code of Conduct][].

AppIdentity for Elixir is licensed under the Apache License, version 2.0 and
requires certification via a Developer Certificate of Origin. See [Licence][]
for more details.

[code of conduct]: https://github.com/KineticCafe/code-of-conduct
[integration test]: https://github.com/KineticCafe/app-identity/blob/main/integration/README.md
[licence]: https://github.com/KineticCafe/app-identity/blob/main/ts/Licence.md
[open source projects]: https://github.com/KineticCafe
[semantic versioning]: http://semver.org/
[spec]: https://github.com/KineticCafe/app-identity/blob/main/spec/README.md
[welcomes contributions]: https://github.com/KineticCafe/app-identity/blob/main/ts/Contributing.md
