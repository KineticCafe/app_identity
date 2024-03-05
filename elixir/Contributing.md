# Contributing

We value contributions to AppIdentity for Elixir—bug reports, discussions,
feature requests, and code contributions. New features should be proposed and
[discussed][] prior to implementation, and release of any new feature may be
delayed until implemented in the three reference implementations.

Before contributing patches, please read the [Licence.md](./Licence.md).

App Identity is governed under the Kinetic Commerce Open Source [Code of
Conduct][].

## Code Guidelines

Our usual code contribution guidelines apply:

- Code changes _will not_ be accepted without tests.
- We use `mix format` and [Credo][credo] for consistent coding style and
  formatting.
- Use a thoughtfully-named topic branch that contains your change. Rebase your
  commits into logical chunks as necessary.
- Use [quality commit messages][].
- The version number must not be changed except as part of the release process.
- Submit a pull request with your changes.
- New or changed behaviours require new or updated documentation.
- New dependencies are discouraged, unless they are `optional` (as we have done
  for Plug and Tesla).

There are code quality checks performed in GitHub Actions that must pass for any
pull request to be accepted.

## Integration Testing

As one of the reference App Identity implementations, AppIdentity for Elixir
contains a mix ask, `mix app_identity` that understands how to `generate` or
`run` [integration test suite files][].

These files can be shared as files (as is done in the [integration workflow][])
or passed between suite generators and suite runners through a pipe, even for
a self-test:

```console
$ mix app_identity generate --stdout | mix app_identity run --stdin
TAP Version 14
1..75

# AppIdentity for Elixir 1.3.2 (spec 4) testing AppIdentity for Elixir 1.3.2 (spec 4)
ok 1 - App V1, Proof V1
ok 2 - App V1, Proof V2
ok 3 - App V1, Proof V3
…
ok 73 - Proof V2, Mismatched Padlock
ok 74 - Proof V3, Mismatched Padlock
ok 75 - Proof V4, Mismatched Padlock
```

### `mix app_identity generate`

Generates an integration test suite JSON file, defaulting to
`app-identity-suite-elixir.json`.

- **Usage**: `mix app_identity generate [options] [suite]`
- **Options**:
  - `--stdout`: Prints the suite to standard output instead of saving it
  - `-q`, `--quiet`: Silences diagnostic messages

### `mix app_identity run`

Runs one or more integration suites.

- **Usage**: `mix app_identity run [options] [paths...]`
- **Options**:
  - `-S`, `--strict`: Runs in strict mode; optional tests will cause failure
  - `--stdin`: Reads a suite from stdin
  - `-D`, `--diagnostic`: Enables output diagnostics

[code of conduct]: https://github.com/KineticCafe/code-of-conduct
[credo]: https://github.com/rrrene/credo
[discussed]: https://github.com/KineticCafe/app_identity/discussions
[hoe]: https://github.com/seattlerb/hoe
[quality commit messages]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
[integration test suite files]: https://github.com/KineticCafe/app_identity/blob/main/integration/README.md#integration-suite-definition
[integration workflow]: https://github.com/KineticCafe/app_identity/blob/main/.github/workflows/integration.ymol
