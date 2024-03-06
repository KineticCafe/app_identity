# Licence

- App Identity is copyright © 2022–2024 Kinetic Commerce and
  [contributors](./Contributing.md#contributors).

## Software

All software in this repository, except as noted below, is licensed under
[Apache License, version 2.0](licences/APACHE-2.0.txt).

This **includes**:

- The reference implementations under `elixir/`, `ruby/`, and `ts/`, including
  documentation related to those implementations.

- Any configuration or logic in `docs/` for the generation of the documentation
  site.

- Any configuration or logic in `integration/` for the generation of integration
  test suites files.

- Any other configuration or logic code in the repo, such as the workflow
  configurations under `.github/workflows`.

This **excludes**:

- `integration/tapview`, which is copyright Eric S. Raymond and licensed under
  a permissive MIT no-attribute (MIT-0) license.

## Documentation

All documentation in this repository, except as noted below, is licensed under
Creative Commons Attribution, version 4.0 ([CC BY 4.0](licences/CC-BY-4.0.txt)).

This **includes**:

- The repository-level documentation (all `.md` files at the root of the
  repository).

- The specification (`spec/README.md`).

- The documentation, JSON, and YAML files in `integration/`.

This **excludes**:

- The copies of the Apache License, the Creative Commons Attribution Licence,
  and the Developer Certificate of Origin in `licences/`.

## Developer Certificate of Origin

All contributors **must** certify they are able and willing to provide their
contributions under the terms of this project's licences with the certification
of the [Developer Certificate of Origin (Version 1.1)](licences/dco.txt).

Such certification is provided by ensuring that a `Signed-off-by` [commit
trailer][] is present on every commit:

    Signed-off-by: FirstName LastName <email@example.org>

The `Signed-off-by` trailer can be automatically added by git with the `-s` or
`--signoff` option on `git commit`:

```sh
git commit --signoff
```

[commit trailer]: https://git-scm.com/docs/git-interpret-trailers
