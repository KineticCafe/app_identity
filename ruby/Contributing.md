# Contributing

We value contributions to AppIdentity for Ruby—bug reports, discussions, feature
requests, and code contributions. New features should be proposed and
[discussed][] prior to implementation, and release of any new feature may be
delayed until implemented in the three reference implementations.

Before contributing patches, please read the [Licence.md](licence.md).

App Identity is governed under the Kinetic Commerce Open Source [Code of
Conduct][].

## Code Guidelines

Our usual code contribution guidelines apply:

- Code changes _will not_ be accepted without tests. The test suite is written
  with [minitest][].
- Match our coding style. We use [standard Ruby][] to assist with this.
- Use a thoughtfully-named topic branch that contains your change. Rebase your
  commits into logical chunks as necessary.
- Use [quality commit messages][].
- Certain things must not be changed except as part of the release process. These
  are:
  - the version number in `lib/app_identity.rb`
  - `Gemfile` (this is a stub file)
  - `app_identity.gemspec` (this is a generated file)
- Submit a pull request with your changes.
- New or changed behaviours require new or updated documentation.
- New dependencies are discouraged.

There are code quality checks performed in GitHub Actions that must pass for any
pull request to be accepted.

## Test Dependencies

`app_identity` uses Ryan Davis’s [Hoe][] to manage the release process, and it
adds a number of useful rake tasks.

```console
$ rake
Run options: --seed 45847

# Running:

..............................

Finished in 0.005884s, 5098.5724 runs/s, 10197.1448 assertions/s.

30 runs, 60 assertions, 0 failures, 0 errors, 0 skips
rm -rf doc
rm -r pkg
```

We have provided the simplest possible Gemfile pointing to the (generated)
`app_identity.gemspec` file. This will permit you to use `bundle install` to get
the development dependencies.

```console
$ bundle install
…
Bundle complete!
```

[code of conduct]: https://github.com/KineticCafe/code-of-conduct
[discussed]: https://github.com/KineticCafe/app_identity/discussions
[hoe]: https://github.com/seattlerb/hoe
[minitest]: https://github.com/seattlerb/minitest
[quality commit messages]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
[standard ruby]: https://github.com/testdouble/standard
