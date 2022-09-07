# AppIdentity for Ruby

- code :: https://github.com/KineticCafe/app-identity/tree/main/ruby/
- issues :: https://github.com/KineticCafe/app-identity/issues

## Description

AppIdentity is a Ruby implementation of the Kinetic Commerce application
identity proof algorithm as described in its [spec][].

## Synopsis

```ruby
app = AppIdentity::App.new(id: id, secret: secret, version: 2)
proof = AppIdentity.generate_proof!(app)
AppIdentity.verify_proof!(proof, app)
```

In a Rails application, proof verification would use
`AppIdentity::RackMiddleware.`

```ruby
require 'app_identity/rack_middleware'

config.middleware.use AppIdentity::RackMiddleware,
  header: "app-identity-proof",
  finder: ->(proof) { IdentityApplication.find(proof[:id]) }
```

There is a Faraday Middleware for providing proof generation for clients.

```ruby
Faraday.new(url: url) do |conn|
  conn.request :app_identity,dentity_app: app,
    header: 'app-proof-identity'
end
```

## Installation

Add `app_identity` to your Gemfile:

```ruby
gem 'app_identity', '~> 1.0'
```

## Semantic Versioning

`AppIdentity` uses a [Semantic Versioning][] scheme with one significant change:

- When PATCH is zero (`0`), it will be omitted from version references.

Additionally, the major version will generally be reserved for specification
revisions.

## Contributing

AppIdentity for Ruby [welcomes contributions](Contributing.md). This project,
all Kinetic Commerce [open source projects][], is under the Kinetic Commerce
Open Source [Code of Conduct][kccoc].

AppIdentity for Ruby is licensed under the Apache Licence, version 2.0 and
requires certification via a Developer Certificate of Origin. See
[Licence.md](Licence.md) for more details.

[contributing]: Contributing.md
[kccoc]: https://github.com/KineticCafe/code-of-conduct
[open source projects]: https://github.com/KineticCafe
[semantic versioning]: http://semver.org/
[spec]: https://github.com/KineticCafe/app-identity/blob/main/spec/README.md
