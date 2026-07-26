# App Identity

> I'm proud of this work, but I currently have no use for this and would likely
> implement it somewhat differently than the current versions. Kinetic Commerce
> has been gone for two years now and there's little value in this except as an
> artifact of something that worked reasonably well.
>
> The concepts here are solid but flawed:
>
> - The spec is well-defined, but was constrained by having a v1 that never
>   should have been deployed and a difficult upgrade process.
> - When both the sides of the communication channel are able to keep the
>   secrets secret, this works well. This does not work well when one of the
>   clients needs to be in the browser, except through an API gateway.
> - The integration tests are _fantastic_. Every system should have similarly
>   strong integration tests.
>
> The only implementation that was _excellent_ was the Elixir one (which is the
> one that this was extracted from). Except that it should have actually been
> implemented in Erlang to maximize use across the BEAM ecosystem. These days I
> might consider implementing it in Gleam, because that would allow one
> implementation for both JavaScript and BEAM runtimes.
>
> On the other hand, the Node and Ruby implementations were mediocre at best.
> The Ruby code was extracted from sidecar applications that Kinetic developed,
> but it never felt like it really belonged in the Ruby ecosystem. I'd probably
> implement a lot of it using Ruby 3.2's `Data` class, but I would take more
> time to get the API correct. The Node implementation? It passed the
> integration tests, but that's about all I'd allow for now.

This repository contains the specification for Kinetic Commerce's App Identity
solution as well as three reference implementations (Elixir, Ruby, and
Typescript) adapted from our previous implementations.

The three implementations are developed and tested against each other.

## Summary

> The specification can be found in [spec/](spec/README.md).

App Identity provides a fast, lightweight, cryptographically secure app
authentication mechanism as an improvement over just using API keys or app IDs.
It does this by computing a proof with an application identifier, a nonce, an
application secret key, and a hashing algorithm. The secret key is embedded in
client applications and stored securely on the server, so it is never passed
over the wire.

App Identity is _not_:

- An app authorization mechanism. By itself, it cannot verify that an app is
  permitted to perform given actions. App authorization may be built _on top of_
  App Identity through the use of multiple apps.

- User authentication or authorization. The validation here is insufficiently
  secure for user authentication, and would require undefined side channels to
  communicate the shared secrets.

App Identity algorithm versions are strictly upgradeable. See
[Algorithm Versions](spec/README.md#algorithm-versions) in the specification for
details.

### Indications and Contraindications

App Identity is _not_ a universal solution to app authorization.

We recommend the use of App Identity for mobile apps, server API clients, and
API gateways. The supported App Identity configurations should be added to the
code bundles as late as possible to avoid secret leaks.

We strongly recommend _against_ the use of App Identity in compiled JavaScript
applications delivered through the browser. There is no way to keep the app
secret secure in a browser environment, which worse than having no security.

If you have browser applications that require App Identity support, we recommend
using an API gateway configuration of App Identity in order to enrich the
request from the client. Securing such requests from the client to the gateway
is _outside_ the scope of App Identity. At Kinetic, have used CORS, CSP, user
authentication, and rate limiting to ensure that the gateway calls themselves
are not abused.

## Implementations

This repository contains three reference implementations:

- [Elixir](elixir/README.md)
- [Ruby](ruby/README.md)
- [Typescript](ts/README.md) for Node

The versioning of each of the reference implementations mostly follows
[Semantic Versioning][semver], but are not linked to each other. Each
implementation identifies which
[specification version](spec/README.md#version-and-versioning) it supports.

### Other Implementations

We encourage implementations in other languages, and will link to them here. We
are planning implementations in the following languages:

- Swift
- Kotlin
- Go
- Rust

If you have created an implementation, please submit a [pull request][pr] to
update the list above.

### Building New Implementations

Non-reference implementations should be written to the provided
[specification](spec/README.md) and tested against at least one other version
(Ruby, Typescript, or Elixir) using the [integration](integration/README.md)
suite.

If you are looking for assistance in developing or testing your implementation,
please start a [discussion][discussion].

## Contributing

See [Contributing.md](./Contributing.md).

[pr]: https://github.com/KineticCafe/app_identity/pulls/
[discussion]: https://github.com/KineticCafe/app_identity/discussions/
[semver]: http://semver.org/
