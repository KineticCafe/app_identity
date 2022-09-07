# frozen_string_literal: true

require "base64"

# AppIdentity is a Ruby implementation of the Kinetic Commerce application
# [identity proof algorithm](spec.md).
#
# It implements identity proof generation and validation functions. These
# functions expect to work with an application object (AppIdentity::App).
#
# ## Configuration
#
# Most of the configuration is specified in the application, but at an
# application level, AppIdentity can be configured to disallow explicit
# versions:
#
# ```ruby
# AppIdentity.disallow_version 1, 3, 4
# ```
#
# This would only allow AppIdentity version 2.
class AppIdentity
  # The version of the AppIdentity library.
  VERSION = "1.0.0"
  # The name of this implementation for App Identity.
  NAME = "AppIdentity for Ruby"
  # The spec version supported in this library.
  SPEC_VERSION = 4

  # The name, version, and supported specification version of this App Identity
  # package for Ruby.
  INFO = {name: NAME, version: VERSION, spec_version: SPEC_VERSION}.freeze
end

require "app_identity/app"
require "app_identity/error"
require "app_identity/internal"
require "app_identity/validation"
require "app_identity/versions"

class AppIdentity
  class << self
    # Generate an identity proof string for the given application. Returns the
    # generated proof or `nil`.
    #
    # If `nonce` is provided, it must conform to the shape expected by the proof
    # version. If not provided, it will be generated.
    #
    # If `version` is provided, it will be used to generate the nonce and the
    # proof. This will allow a lower level application to raise its version level.
    #
    # If there is *any* error during the generation of the identity proof
    # string, `nil` will be returned.
    #
    # ### Examples
    #
    # A version 1 app can have a fixed nonce, which will always produce the same
    # value.
    #
    # ```ruby
    # app = AppIdentity::App.new({version: 1, id: "decaf", secret: "bad"})
    # AppIdentity.generate_proof(app, nonce: "hello")
    # # => "ZGVjYWY6aGVsbG86RDNGNjJCQTYyOEIyMzhEOTgwM0MyNEU4NkNCOTY3M0ZEOTVCNTdBNkJGOTRFMkQ2NTMxQTRBODg1OTlCMzgzNQ=="
    # ```
    #
    # A version 2 app fails when given a non-timestamp nonce.
    #
    # ```ruby
    # AppIdentity.generate_proof(v1(), version: 2, nonce: "hello")
    # # => nil
    # ```
    #
    # A version 2 app _cannot_ generate a version 1 nonce.
    #
    # ```ruby
    # AppIdentity.generate_proof(v2(), version: 1)
    # # => nil
    # ```
    #
    # A version 2 app will be rejected if the version has been disallowed.
    #
    # ```ruby
    #  AppIdentity.generate_proof(v2(), disallowed: [1, 2])
    #  # => nil
    #  ```
    #
    #  Note that the optional `disallowed` parameter is *in addition* to the
    #  global `disallowed` configuration.
    def generate_proof(app, nonce: nil, version: nil, disallowed: nil)
      internal.generate_proof!(app, nonce: nonce, version: version, disallowed: disallowed)
    rescue
      nil
    end

    # Generate an identity proof string for the given application. Returns the
    # generated proof or raises an exception
    #
    # If `nonce` is provided, it must conform to the shape expected by the proof
    # version. If not provided, it will be generated.
    #
    # If `version` is provided, it will be used to generate the nonce and the
    # proof. This will allow a lower level application to raise its version level.
    #
    # If there is *any* error during the generation of the identity proof
    # string, an exception will be raised.
    #
    # ### Examples
    #
    # A version 1 app can have a fixed nonce, which will always produce the same
    # value.
    #
    # ```ruby
    # app = AppIdentity::App.new({version: 1, id: "decaf", secret: "bad"})
    # AppIdentity.generate_proof!(app, nonce: "hello")
    # # => "ZGVjYWY6aGVsbG86RDNGNjJCQTYyOEIyMzhEOTgwM0MyNEU4NkNCOTY3M0ZEOTVCNTdBNkJGOTRFMkQ2NTMxQTRBODg1OTlCMzgzNQ=="
    # ```
    #
    # A version 2 app fails when given a non-timestamp nonce.
    #
    # ```ruby
    # AppIdentity.generate_proof!(v1(), version: 2, nonce: "hello")
    # # => nil
    # ```
    #
    # A version 2 app _cannot_ generate a version 1 nonce.
    #
    # ```ruby
    # AppIdentity.generate_proof!(v2(), version: 1)
    # # => nil
    # ```
    #
    # A version 2 app will be rejected if the version has been disallowed.
    #
    # ```ruby
    #  AppIdentity.generate_proof!(v2(), disallowed: [1, 2])
    #  # => nil
    #  ```
    #
    #  Note that the optional `disallowed` parameter is *in addition* to the
    #  global `disallowed` configuration.
    def generate_proof!(app, nonce: nil, version: nil, disallowed: nil)
      internal.generate_proof!(app, nonce: nonce, version: version, disallowed: disallowed)
    rescue
      raise AppIdentity::Error, :generate_proof
    end

    # Parses a proof string and returns a Hash containing the proof parts or `nil`
    # if the proof is cannot be determined as valid.
    def parse_proof(proof)
      internal.parse_proof!(proof)
    rescue
      nil
    end

    # Parses a proof string and returns a Hash containing the proof parts or
    # raises an exception if the proof is cannot be determined as valid.
    def parse_proof!(proof)
      internal.parse_proof!(proof)
    rescue
      raise AppIdentity::Error, :parse_proof
    end

    # Verify a `AppIdentity` proof value using a a provided `app`. Returns the
    # validated app or `nil`.
    #
    # The `proof` may be provided either as a string or a parsed proof (from
    # `#parse_proof`). String proof values are usually obtained from HTTP
    # headers. At Kinetic Commerce, this has generally jeen `KCS-Application` or
    # `KCS-Service`.
    #
    # The `app` can be provided as an AppIdentity::App, a valid input to
    # AppIdentity::App.new, or an finder callable that accepts a single
    # parameter—the parsed proof value—and returns an AppIdentity::App input.
    #
    # ```ruby
    # AppIdentity.verify_proof(proof, ->(proof) {
    #   IdentityApplications.get(proof[:id]
    # }))
    # ```
    #
    #  Note that the optional `disallowed` parameter is *in addition* to the
    #  global `disallowed` configuration.
    def verify_proof(proof, app, disallowed: nil)
      internal.verify_proof!(proof, app, disallowed: disallowed)
    rescue
      nil
    end

    # Verify a `AppIdentity` proof value using a a provided `app`. Returns the
    # validated app, `nil`, or raises an exception on error.
    #
    # The `proof` may be provided either as a string or a parsed proof (from
    # `#parse_proof`). String proof values are usually obtained from HTTP
    # headers. At Kinetic Commerce, this has generally jeen `KCS-Application` or
    # `KCS-Service`.
    #
    # The `app` can be provided as an AppIdentity::App, a valid input to
    # AppIdentity::App.new, or an finder callable that accepts a single
    # parameter—the parsed proof value—and returns an AppIdentity::App input.
    #
    # ```ruby
    # AppIdentity.verify_proof!(proof, ->(proof) {
    #   IdentityApplications.get(proof[:id]
    # }))
    # ```
    #
    #  Note that the optional `disallowed` parameter is *in addition* to the
    #  global `disallowed` configuration.
    def verify_proof!(proof, app, disallowed: nil)
      internal.verify_proof!(proof, app, disallowed: disallowed)
    rescue
      raise AppIdentity::Error, :verify_proof
    end

    # Add the `versions` to the global disallowed versions list.
    def disallow_version(*versions)
      AppIdentity::Versions.disallow(*versions)
    end

    # Remove the `versions` from the global disallowed versions list.
    def allow_version(*versions)
      AppIdentity::Versions.allow(*versions)
    end

    private :new

    private

    def internal
      Internal.instance
    end
  end
end
