# AppIdentity for Node (`@kineticcafe/app-identity`)

- code :: https://github.com/KineticCafe/app-identity/tree/main/ts/
- issues :: https://github.com/KineticCafe/app-identity/issues

## Description

AppIdentity is a Node.js implementation (written in Typescript) of the Kinetic
Commerce application identity proof algorithm as described in its [spec][].

## Synopsis

```javascript
import * as AppIdentity from '@kineticcafe/app-identity'

const app = { id, secret, version: 2 }
const proof = AppIdentity.generateProof(app)
AppIdentity.verifyProof(proof, app)
```

## Installation

`@kineticcafe/app-identity` should be added to your list of depdencies in
`package.json`. This package is intended to be run on the server, not in the
browser.

```sh
npm add @kineticcafe/app-identity@^1.0
```

## Semantic Versioning

`AppIdentity` uses a [Semantic Versioning][] scheme with one significant change:

- When PATCH is zero (`0`), it will be omitted from version references.

Additionally, the major version will generally be reserved for specification
revisions.

## Contributing

AppIdentity for Node [welcomes contributions][]. This project, like all Kinetic
Commerce [open source projects][], is under the Kinetic Commerce Open Source
[Code of Conduct][].

AppIdentity for Elixir is licensed under the Apache Licence, version 2.0 and
requires certification via a Developer Certificate of Origin. See [Licence.md][]
for more details.

[welcome contributions]: https://github.com/KineticCafe/app-identity/blob/main/ts/Contributing.md
[code of conduct]: https://github.com/KineticCafe/code-of-conduct
[open source projects]: https://github.com/KineticCafe
[semantic versioning]: http://semver.org/
[spec]: https://github.com/KineticCafe/app-identity/blob/main/spec/README.md
[licence.md]: https://github.com/KineticCafe/app-identity/blob/main/ts/Licence.md
