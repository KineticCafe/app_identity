# AppIdentity for Elixir

- code :: https://github.com/KineticCafe/app-identity/tree/main/elixir
- issues :: https://github.com/KineticCafe/app-identity/issues

## Description

AppIdentity is an Elixir implementation of the Kinetic Commerce application
identity proof algorithm as described in its [spec][].

## Synopsis

```elixir
app = %{id: id, secret: secret, version: 2}
proof = AppIdentity.generate_proof(app)
AppIdentity.verify_proof(proof, app)
```

There is a Plug available for authenticating applications, `AppIdentity.Plug`.

```elixir
plug AppIdentity.Plug,
  headers: ["app-identity-proof"],
  finder: fn %{id: id} = _proof -> IdentityApplications.get(id) end

```

There is a Tesla Middleware for providing proof generation for clients.

```elixir
def client(app) do
  middleware = [
    {AppIdentity.TeslaMiddleware, identity_app: app, header: "app-identity-proof"}
  ]
end
```

## Installation

The package can be installed by adding `app_identity` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:app_identity, "~> 1.0"}
  ]
end
```

If you need to use a pre-release version, the dependency structure is slightly
different:

```elixir
def deps do
  [
    {:app_identity, github: "KineticCafe/app_identity", sparse: "elixir"}
  ]
end
```

If on Elixir 1.13 or later, you can use `:subdir` instead:

```elixir
def deps do
  [
    {:app_identity, github: "KineticCafe/app_identity", subdir: "elixir"}
  ]
end
```

Optional features are present when [Plug][] and/or [Tesla][] are part of your
application.

Documentation can found at [HexDocs][docs] or generated with [ex_doc][].

## Semantic Versioning

`AppIdentity` uses a [Semantic Versioning][] scheme with one significant change:

- When PATCH is zero (`0`), it will be omitted from version references.

Additionally, the major version will generally be reserved for specification
revisions.

## Contributing

AppIdentity for Elixir [welcomes contributions](Contributing.md). This project,
like all Kinetic Commerce [open source projects][], is under the Kinetic
Commerce Open Source [Code of Conduct][kccoc].

AppIdentity for Elixir is licensed under the Apache Licence, version 2.0 and
requires certification of a Developer Certificate of Origin. See
[Licence.md](Licence.md) for more details.

[docs]: https://hexdocs.pm/app_identity
[ex_doc]: https://github.com/elixir-lang/ex_doc
[kccoc]: https://github.com/KineticCafe/code-of-conduct
[open source projects]: https://github.com/KineticCafe
[plug]: https://hex.pm/packages/plug
[semantic versioning]: http://semver.org/
[spec]: https://github.com/KineticCafe/app-identity/blob/main/spec/README.md
[tesla]: https://hex.pm/packages/tesla
