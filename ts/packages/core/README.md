# @kineticcafe/app-identity 2.0.0: AppIdentity for JavaScript

- code :: https://github.com/KineticCafe/app-identity/tree/main/ts/
- issues :: https://github.com/KineticCafe/app-identity/issues

## Description

@kineticcafe/app-identity is the runtime-agnostic Typescript implementation of
the Kinetic Commerce application identity proof algorithm as described in its
[spec][spec].

This package cannot be used without a runtime adapter. See
[@kineticcafe/app-identity-node][node] for the Node.js adapter. If a different
runtime is required, see [adapter.ts][adapter.ts] for the required functions.

## Synopsis

```javascript
import * as AppIdentity from "@kineticcafe/app-identity";
import { myRuntime } from "./runtime";

// Required at program start.
AppIdentity.setRuntimeAdapter(myRuntime);

const app = { id, secret, version: 2 };
const proof = AppIdentity.generateProof(app);
AppIdentity.verifyProof(proof, app);
```

## Installation

@kineticcafe/app-identity should be added to your list of dependencies in
`package.json`.

```console
$ npm add @kineticcafe/app-identity@^2.0
```

We discourage the use of AppIdentity for JavaScript in a browser because the App
Identity algorithm requires the use of shared secrets for validation.

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
[node]: https://github.com/KineticCafe/app-identity/tree/main/ts/packages/node
[adapter.ts]: https://github.com/KineticCafe/app-identity/bloc/main/ts/packages/node/src/adapter.ts
