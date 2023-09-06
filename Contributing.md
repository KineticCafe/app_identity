# Contributing

We value contributions to App Identity—bug reports, discussions, feature
requests, and code contributions. New features should be proposed and
[discussed][discussed] prior to implementation, and release of any new feature
may be delayed until implemented in the reference implementations.

Before contributing patches, please read the [Licence](./Licence.md).

App Identity is governed under the Kinetic Commerce Open Source
[Code of Conduct][conduct].

## Code Guidelines

We have several guidelines to contributing code through pull requests to App
Identity reference implementations:

- All code changes require tests. In most cases, this will be added or updated
  unit tests for the implementations: [ExUnit][ExUnit] (Elixir),
  [minitest][minitest] (Ruby), or [vitest][vitest] (Typescript).

  In some cases, new [integration tests](integration/README.md) will be
  required, which will require updates to the integration test generators for
  all implementations.

- We use code formatters, static analysis tools, and linting to ensure
  consistent styles and formatting. There should be no warnings output from
  compile or test run processes.

- Proposed changes should be on a thoughtfully-named topic branch and organized
  into logical commit chunks as appropriate.

- Use [Conventional Commits][conventional] with our
  [conventions](#commit-conventions).

- Versions must not be updated in pull requests; implementations may have other
  restrictions on file updates as they are part of the release process.

- Documentation should be added or updated as appropriate for new or updated
  functionality.

- New dependencies are discouraged and their addition must be discussed,
  regardless whether it is a development dependency, optional dependency, or
  runtime dependency.

- All GitHub Actions checks marked as required must pass before a pull request
  may be accepted and merged.

### Commit Conventions

App Identity has adopted the Conventional Commits format for commit messages.
Because there are three reference implementations, integration tests, and a
specification in this repository, the `(scope)` is required for _most_ commits.
The `scope` constraints the permitted commit `type`s, as outlined below.

| `scope`      | Purpose                                                  | Allowed `type`s                        | Example            |
| ------------ | -------------------------------------------------------- | -------------------------------------- | ------------------ |
| `spec`       | Updates to the App Identity [spec](./spec/README.md).    | `feat`, `fix`, `chore`                 | `feat(spec)`       |
| `int`        | Updates to integration test specification or definitions | `feat`, `fix`, `chore`                 | `feat(int)`        |
| `int/elixir` | Updates to Elixir integration test support               | `feat`, `fix`, `chore`                 | `feat(int/elixir)` |
| `int/ruby`   | Updates to Ruby integration test support                 | `feat`, `fix`, `chore`                 | `feat(int/ruby)`   |
| `int/ts`     | Updates to Typescript integration test support           | `feat`, `fix`, `chore`                 | `feat(int/ts)`     |
| `elixir`     | Updates to the Elixir implementation                     | `feat`, `fix`, `chore`, `docs`, `deps` | `docs(elixir)`     |
| `ruby`       | Updates to the Ruby implementation                       | `feat`, `fix`, `chore`, `docs`, `deps` | `fix(ruby)`        |
| `ts`         | Updates to the Typescript implementation                 | `feat`, `fix`, `chore`, `docs`, `deps` | `feat(ts)`         |
|              | Updates to global documentation or configuration         | `feat`, `fix`, `chore`, `docs`, `deps` | `chore`            |

Updates to GitHub Actions _may_ be global, but should be scoped if applied to a
single implementation's workflow.

We encourage the use of [Tim Pope's][tpope-qcm] or [Chris Beam's][cbeams]
guidelines on the writing of commit messages

We require the use of [git][trailers1] [trailers][trailers2] for specific
additional metadata and strongly encourage it for others. The conditionally
required metadata trailers are:

- `Breaking-Change`: if the change is a breaking change. **Do not** use the
  shorthand form (`feat!(scope)`) or `BREAKING CHANGE`.

- `Signed-off-by`: required for non-Kinetic Commerce contributors, as outlined
  in the [Licence](./Licence.md#developer-certificate-of-origin).

- `Fixes` or `Resolves`: If a change fixes one or more open [issues][issues],
  that issue must be included in the `Fixes` or `Resolves` trailer. Multiple
  issues should be listed comma separated in the same trailer:
  `Fixes: #1, #5, #7`, but _may_ appear in separate trailers. While both `Fixes`
  and `Resolves` are synonyms, only _one_ should be used in a given commit or
  pull request.

- `Related to`: If a change does not fix an issue, those issue references should
  be included in this trailer.

- `Discussion`: If a change is related to a [discussion][discussed], those
  discussion URLs should be in `Discussion` trailers.

## Contributors

Austin Ziegler ([@halostatue][@halostatue]), Mike Stok ([@mikestok][@mikestok]),
and Nitin Malik ([@ohnit][@ohnit]) created and maintained the Elixir and Ruby
versions of the original code at Kinetic Commerce that defined what has become
App Identity.

[@halostatue]: https://github.com/halostatue
[@mikestok]: https://github.com/mikestok
[@ohnit]: https://github.com/ohnit
[cbeams]: https://cbea.ms/git-commit/
[conduct]: https://github.com/KineticCafe/code-of-conduct
[conventional]: https://www.conventionalcommits.org/en/v1.0.0/
[discussed]: https://github.com/KineticCafe/app_identity/discussions/
[exunit]: https://hexdocs.pm/ex_unit/ExUnit.html
[issues]: https://github.com/KineticCafe/app_identity/issues/
[minitest]: https://github.com/seattlerb/minitest
[tpope-qcm]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
[trailers1]: https://git-scm.com/docs/git-interpret-trailers
[trailers2]: https://git-scm.com/docs/git-commit#Documentation/git-commit.txt---trailerlttokengtltvaluegt
[vitest]: https://vitest.dev/
