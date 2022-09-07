# Contributing

We value contributions to AppIdentity for Node—bug reports, discussions, feature
requests, and code contributions. New features should be proposed and
[discussed][] prior to implementation, and release of any new feature may be
delayed until implemented in the three reference implementations.

Before contributing patches, please read the [Licence.md](Licence.md).

App Identity is governed under the Kinetic Commerce Open Source [Code of
Conduct][].

## Code Guidelines

Our usual code contribution guidelines apply:

- Code changes _will not_ be accepted without tests. The test suite is written
  with [vitest][].
- Match our coding style. We use ESLint and Prettier to assist with this.
- Use a thoughtfully-named topic branch that contains your change. Rebase your
  commits into logical chunks as necessary.
- Use [quality commit messages][].
- The version number must not be changed except as part of the release process.
- Submit a pull request with your changes.
- New or changed behaviours require new or updated documentation.

There are code quality checks performed in GitHub Actions that must pass for any
pull request to be accepted.

[code of conduct]: https://github.com/KineticCafe/code-of-conduct
[discussed]: https://github.com/KineticCafe/app_identity/discussions
[quality commit messages]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
[vitest]: https://vitest.dev/
