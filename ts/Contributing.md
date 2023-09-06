# Contributing

We value contributions to AppIdentity for JavaScript—bug reports, discussions,
feature requests, and code contributions. New features should be proposed and
[discussed][discussed] prior to implementation, and release of any new feature
may be delayed until implemented in the reference implementations.

Before contributing patches, please read the [Licence](./Licence.md).

App Identity is governed under the Kinetic Commerce Open Source
[Code of Conduct][coc].

## Code Guidelines

We have several guidelines to contributing code through pull requests to App
Identity reference implementations:

- All code changes require tests. In most cases, this will be added or updated
  unit tests.

  For the Typescript implementation, we use [vitest][vitest].

  In some cases, new [integration tests][integration-tests] will be required,
  which will require updates to the integration test generators for all
  implementations.

- We use code formatters, static analysis tools, and linting to ensure
  consistent styles and formatting. There should be no warnings output from
  compile or test run processes.

  For the Typescript implementation, we use [Biome][Biome] and `tsc --noEmit`.

- Proposed changes should be on a thoughtfully-named topic branch and organized
  into logical commit chunks as appropriate.

- Use [Conventional Commits][conventional] with our [conventions][conventions].

- Versions must not be updated in pull requests; implementations may have other
  restrictions on file updates as they are part of the release process.

- Documentation should be added or updated as appropriate for new or updated
  functionality.

- New dependencies are discouraged and their addition must be discussed,
  regardless whether it is a development dependency, optional dependency, or
  runtime dependency.

- All GitHub Actions checks marked as required must pass before a pull request
  may be accepted and merged.

## Integration Testing

As one of the reference App Identity implementations, AppIdentity for JavaScript
provides a package, `@kineticcafe/app-identity-suite-ts`, that can `generate`
and `run` [integration test suite files][integration-files].

These files can be shared as files (see the
[integration workflow][integration-workflow]) or passed between suite generators
and suite runners through a pipe.

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

When developing App Identity for JavaScript, this can also be run with `pnpm`:

```console
# The --silent flags are required for pipes to work.
$ pnpm --silent cli:generate --stdout | pnpm --silent cli:run --stdin --strict
```

### `app-identity-suite-ts generate`

Generates an integration test suite JSON file, defaulting to
`app-identity-suite-ts.json`.

- **Usage**: `app-identity-suite-ts generate [options] [suite]`
- **Options**:
  - `--stdout`: Prints the suite to standard output instead of saving it
  - `-q`, `--quiet`: Silences diagnostic messages

### `app-identity-suite-ts generate`

Runs one or more integration suites.

- **Usage**: `app-identity-suite-ts run [options] [paths...]`
- **Options**:
  - `-S`, `--strict`: Runs in strict mode; optional tests will cause failure
  - `--stdin`: Reads a suite from standard input
  - `-D`, `--diagnostic`: Enables output diagnostics

[biome]: https://biomejs.dev/
[coc]: https://github.com/KineticCafe/code-of-conduct
[conventional]: https://www.conventionalcommits.org/en/v1.0.0/
[conventions]: https://github.com/KineticCafe/app-identity/blob/main/Contributing.md#commit-conventions
[discussed]: https://github.com/KineticCafe/app_identity/discussions
[integration-files]: https://github.com/KineticCafe/app-identity/blob/main/integration/README.md#integration-suite-definition
[integration-tests]: https://github.com/KineticCafe/app-identity/blob/main/integration/README.md
[integration-workflow]: https://github.com/KineticCafe/app_identity/blob/main/.github/workflows/integration.yml
[quality commit messages]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
[vitest]: https://vitest.dev/
