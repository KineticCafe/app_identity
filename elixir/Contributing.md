# Contributing

We value contributions to AppIdentity for Elixir—bug reports, discussions,
feature requests, and code contributions. New features should be proposed and
[discussed][] prior to implementation, and release of any new feature may be
delayed until implemented in the reference implementations.

Before contributing patches, please read the [Licence](./Licence.md).

App Identity is governed under the Kinetic Commerce Open Source [Code of
Conduct][].

## Code Guidelines

We have several guidelines to contributing code through pull requests to App
Identity reference implementations:

- All code changes require tests. In most cases, this will be added or updated
  unit tests.

  For the Elixir implementation, we use [ExUnit][].

  In some cases, new [integration tests][] will be required, which will require
  updates to the integration test generators for all implementations.

- We use code formatters, static analysis tools, and linting to ensure
  consistent styles and formatting. There should be no warnings output from
  compile or test run processes.

  For the Elixir implementation, we use `mix compile --warnings-as-errors`,
  [Credo][], and `mix format`.

- Proposed changes should be on a thoughtfully-named topic branch and organized
  into logical commit chunks as appropriate.

- Use [Conventional Commits][] with our [conventions][].

- Versions must not be updated in pull requests; implementations may have
  other restrictions on file updates as they are part of the release process.

- Documentation should be added or updated as appropriate for new or updated
  functionality.

- New dependencies are discouraged and their addition must be discussed,
  regardless whether it is a development dependency, optional dependency, or
  runtime dependency.

- All GitHub Actions checks marked as required must pass before a pull request
  may be accepted and merged.

## Integration Testing

As one of the reference App Identity implementations, AppIdentity for Elixir
contains a mix task, `mix app_identity`, that can `generate` and `run`
[integration test suite files][].

These files can be shared as files (see the [integration workflow][]) or passed
between suite generators and suite runners through a pipe, even for a self-test:

```console
$ mix app_identity generate --stdout | mix app_identity run --stdin
TAP Version 14
1..75
# generator: AppIdentity for Elixir 1.3.2 (spec 4)
# runner: AppIdentity for Elixir 1.3.2 (spec 4)
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
  - `--stdin`: Reads a suite from standard input
  - `-D`, `--diagnostic`: Enables output diagnostics

[code of conduct]: https://github.com/KineticCafe/code-of-conduct
[conventional commits]: https://www.conventionalcommits.org/en/v1.0.0/
[conventions]: https://github.com/KineticCafe/app-identity/blob/main/Contributing.md#commit-conventions
[credo]: https://github.com/rrrene/credo
[discussed]: https://github.com/KineticCafe/app_identity/discussions
[exunit]: https://hexdocs.pm/ex_unit/ExUnit.html
[integration test suite files]: https://github.com/KineticCafe/app-identity/blob/main/integration/README.md#integration-suite-definition
[integration tests]: https://github.com/KineticCafe/app-identity/blob/main/integration/README.md
[integration workflow]: https://github.com/KineticCafe/app_identity/blob/main/.github/workflows/integration.yml
