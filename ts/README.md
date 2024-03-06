# AppIdentity for JavaScript 2.0

- code :: https://github.com/KineticCafe/app-identity/tree/main/ts/
- issues :: https://github.com/KineticCafe/app-identity/issues

## Description

AppIdentity for JavaScript is a Typescript implementation of the Kinetic
Commerce application identity proof algorithm as described in its [spec][].

There are three packages contained in this implementation:

- @kineticcafe/app-identity: The core algorithmic implementation which can be
  used on any JavaScript runtime with an appropriate runtime adapter.

- @kineticcafe/app-identity-node: The runtime adapter for Node.js, which
  re-exports the functional parts of @kineticcafe/app-identity.

- @kineticcafe/app-identity-suite-ts: The [integration test][] tool, used to
  generate and run integration tests.

## Synopsis

```javascript
import * as AppIdentity from '@kineticcafe/app-identity-node'

// Required at program start.
AppIdentity.useNodeRuntimeAdapter()

const app = { id, secret, version: 2 }
const proof = AppIdentity.generateProof(app)
AppIdentity.verifyProof(proof, app)
```

We discourage the use of AppIdentity for JavaScript in a browser because the
App Identity algorithm requires the use of shared secrets for validation.

## Installation

`@kineticcafe/app-identity-node` (or `@kinetic/app-identity` with an appropriate
runtime adapter) should be added to your list of dependencies in `package.json`.

```console
$ npm add @kineticcafe/app-identity-node@^2.0
```

## Semantic Versioning

`AppIdentity` uses a [Semantic Versioning][] scheme with one significant change:

- When PATCH is zero (`0`), it will be omitted from version references.

Additionally, the major version will generally be reserved for specification
revisions.

## Contributing

AppIdentity for JavaScript [welcomes contributions][]. This project, like all
Kinetic Commerce [open source projects][], is under the Kinetic Commerce Open
Source [Code of Conduct][].

AppIdentity for Elixir is licensed under the Apache License, version 2.0 and
requires certification via a Developer Certificate of Origin. See [Licence][]
for more details.

[code of conduct]: https://github.com/KineticCafe/code-of-conduct
[integration test]: https://github.com/KineticCafe/app-identity/blob/main/integration/README.md
[licence]: https://github.com/KineticCafe/app-identity/blob/main/ts/Licence.md
[open source projects]: https://github.com/KineticCafe
[semantic versioning]: http://semver.org/
[spec]: https://github.com/KineticCafe/app-identity/blob/main/spec/README.md
[welcomes contributions]: https://github.com/KineticCafe/app-identity/blob/main/ts/Contributing.md
