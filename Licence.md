# Licence

- App Identity is copyright © 2022 Kinetic Commerce and contributors

## Software

All software in this repository, except as noted below, is licensed under
[Apache Licence, version 2.0][apache-licence-20].

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
  a permissive BSD-2-clause license.

## Documentation

All documentation in this repository, except as noted below, is licensed under
Creative Commons Attribution, version 4.0 ([CC BY 4.0][]).

This **includes**:

- The repository-level documentation (all `.md` files at the root of the
  repository).

- The specification (`spec/README.md`).

- The documentation, JSON, and YAML files in `integration/`.

This **excludes**:

- The copies of the Apache Licence, the Creative Commons Attribution Licence,
  and the Developer Certificate of Origin in `licenses/`.

## Developer Certificate of Origin

All contributors **must** certify they are able and willing to provide their
contributions under the terms of this project's licenses with the certification
of the [Developer Certificate of Origin (Version 1.1)][dco].

Such certification is provided by ensuring that the following line must be
included as the last line of a commit message for every commit contributed:

    Signed-off-by: FirstName LastName <email@example.org>

The `Signed-off-by` line can be automatically added by git with the `-s` or
`--signoff` option on `git commit`:

```sh
git commit --signoff
```

[apache-licence-20]: licences/APAHCE-2.0.txt
[mit]: licenses/MIT.txt
[cc by 4.0]: licenses/CC-BY-4.0.txt
[dco]: licenses/dco.txt
