# @kineticcafe/app-identity-node 2.0.0: AppIdentity for JavaScript

- code :: https://github.com/KineticCafe/app-identity/tree/main/ts/
- issues :: https://github.com/KineticCafe/app-identity/issues

## Description

@kineticcafe/app-identity-node is the Node.js runtime adapter for the Kinetic
Commerce application identity proof algorithm as described in its [spec][spec].

## Synopsis

```javascript
import * as AppIdentity from "@kineticcafe/app-identity-node";

// Required at program start.
AppIdentity.useNodeRuntimeAdapter();

const app = { id, secret, version: 2 };
const proof = AppIdentity.generateProof(app);
AppIdentity.verifyProof(proof, app);
```

## Installation

`@kineticcafe/app-identity-node` should be added to your list of depdencies in
`package.json`.

```console
$ npm add @kineticcafe/app-identity-node@^2.0
```

## Semantic Versioning

`AppIdentity` uses a [Semantic Versioning][semver] scheme with one significant
change:

- When PATCH is zero (`0`), it will be omitted from version references.

Additionally, the major version will generally be reserved for specification
revisions.

## Contributing

AppIdentity for JavaScript [welcomes contributions][contributions]. This
project, like all Kinetic Commerce [open source projects][projects], is under
the Kinetic Commerce Open Source [Code of Conduct][coc].

AppIdentity for Elixir is licensed under the Apache License, version 2.0 and
requires certification via a Developer Certificate of Origin. See
[Licence][Licence] for more details.

[contributions]: https://github.com/KineticCafe/app-identity/blob/main/ts/Contributing.md
[coc]: https://github.com/KineticCafe/code-of-conduct
[projects]: https://github.com/KineticCafe
[semver]: http://semver.org/
[spec]: https://github.com/KineticCafe/app-identity/blob/main/spec/README.md
[licence]: https://github.com/KineticCafe/app-identity/blob/main/ts/Licence.md
