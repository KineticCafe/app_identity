# App Identity for JavaScript Changelog

## 2.0.0 / 2024-03-13

### Breaking Changes

@kineticcafe/app-identity has been divided into multiple packages in order to
enable support for JavaScript runtime environments other than Node, such as
React Native.

When upgrading from version 1 for use in an application server, use
`@kineticcafe/app-identity-node` instead of `@kineticcafe/app-identity`.

When using the Node version for the cross-implementation integration testing,
use `@kineticcafe/app-identity-suite-ts`.

### Other Changes

- Added support for padlock case testing for the integration suite.

- Replaced `tsup` with `tsx` and `pkgroll`.

- Moved from `eslint` / `prettier` to `biome`.

## 1.0.0 / 2022-09-07

- Initial release.
