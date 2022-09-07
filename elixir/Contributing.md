# Contributing

We value contributions to AppIdentity for Elixir—bug reports, discussions,
feature requests, and code contributions. New features should be proposed and
[discussed][] prior to implementation, and release of any new feature may be
delayed until implemented in the three reference implementations.

Before contributing patches, please read the [Licence.md](Licence.md).

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

[code of conduct]: https://github.com/KineticCafe/code-of-conduct
[credo]: https://github.com/rrrene/credo
[discussed]: https://github.com/KineticCafe/app_identity/discussions
[hoe]: https://github.com/seattlerb/hoe
[quality commit messages]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
