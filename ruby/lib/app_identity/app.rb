# frozen_string_literal: true

require "ostruct"

require_relative "error"
require_relative "validation"

# The class used by the App Identity proof generation and verification
# algorithms. This will typically be constructed from another object, structure,
# or hash, such as from a static configuration file or a database record.
#
# AppIdentity::App objects are created frozen, and certain operations may
# provide a modified duplicate.
class AppIdentity::App
  def self.new(input) # :nodoc:
    if input.is_a?(AppIdentity::App) && !input.verified
      input
    else
      super
    end
  end

  include AppIdentity::Validation

  # The AppIdentity App unique identifier. Validation of the `id` value will
  # convert non-string IDs using #to_s.
  #
  # If using integer IDs, it is recommended that the `id` value be provided as
  # some form of extended string value, such as that provided by Rails [global
  # ID](https://github.com/rails/globalid). Such representations are _also_
  # recommended if the ID is a compound value.
  #
  # `id` values _must not_ contain a colon (`:`) character.
  attr_reader :id

  # The App Identity app secret value. This value is used _as provided_ with no
  # encoding or decoding. As this is a sensitive value, it may be provided
  # as a 0-arity closure proc.
  #
  # For security purposes, this is always stored as a 0-arity closure proc.
  attr_reader :secret

  # The positive integer version of the AppIdentity algorithm to use. Will be
  # validated to be a supported version for app creation, and not an explicitly
  # disallowed version during proof validation.
  #
  # A string `version` must convert cleanly to an integer value, meaning that
  # `"3.5"` is not a valid value.
  #
  # AppIdentity algorithm versions are strictly upgradeable. That is, a version
  # 1 app can verify version 1, 2, 3, or 4 proofs. However, a version 2 app will
  # _never_ validate a version 1 proof.
  #
  # <table>
  #   <thead>
  #     <tr>
  #       <th rowspan=2>Version</th>
  #       <th rowspan=2>Nonce</th>
  #       <th rowspan=2>Digest Algorithm</th>
  #       <th colspan=4>Can Verify</th>
  #     </tr>
  #     <tr><th>1</th><th>2</th><th>3</th><th>4</th></tr>
  #   </thead>
  #   <tbody>
  #     <tr><th>1</th><td>random</td><td>SHA 256</td><td>✅</td><td>✅</td><td>✅</td><td>✅</td></tr>
  #     <tr><th>2</th><td>timestamp ± fuzz</td><td>SHA 256</td><td>⛔️</td><td>✅</td><td>✅</td><td>✅</td></tr>
  #     <tr><th>3</th><td>timestamp ± fuzz</td><td>SHA 384</td><td>⛔️</td><td>⛔️</td><td>✅</td><td>✅</td></tr>
  #     <tr><th>4</th><td>timestamp ± fuzz</td><td>SHA 512</td><td>⛔️</td><td>⛔️</td><td>⛔️</td><td>✅</td></tr>
  #   </tbody>
  # </table>
  attr_reader :version

  # An optional configuration value for validation of an App Identity proof.
  #
  # If not provided, the default value when required is `{fuzz: 600}`,
  # specifying that the timestamp may not differ from the current time by more
  # than ±600 seconds (±10 minutes). Depending on the nature of the app being
  # verified and the expected network conditions, a shorter time period than 600
  # seconds is recommended.
  #
  # The App Identity version 1 algorithm does not use `config`.
  attr_reader :config

  # The original object used to construct this App Identity object.
  attr_reader :source

  # Whether this app was used in the successful verification of a proof.
  attr_reader :verified

  # Constructs an AppIdentity::App from a provided object or zero-arity
  # callable that returns an initialization object. These values should be
  # treated as immutable objects.
  #
  # The object must respond to `#id`, `#secret`, `#version`, and `#config` or
  # have indexable keys (via `#[]`) of `id`, `secret`, `version`, and `config`
  # as either Symbol or String values. That is, the `id` should be retrievable
  # in one of the following ways:
  #
  # ```ruby
  # input.id
  # input[:id]
  # input["id"]
  # ```
  #
  # If the input parameter is a callable, it will be called with no
  # parameters to produce an input object.
  #
  # The AppIdentity::App is frozen on creation.
  #
  # ```ruby
  # AppIdentity::App.new({id: 1, secret: "secret", version: 1})
  #
  # AppIdentity::App.new(->() { {id: 1, secret: "secret", version: 1} })
  # ```
  #
  # If the provided `input` is already an App and is not #verified, the existing
  # app will be returned instead of creating a new application.
  def initialize(input)
    input = input.call if input.respond_to?(:call)

    @id = get(input, :id)
    @secret = fwrap(get(input, :secret).dup)
    @version = get(input, :version)
    @config = get(input, :config)
    @source = input
    @verified = false

    validate!
    freeze
  end

  # If the current App is not `verified`, then return a copy of the current App
  # with the verified flag set to `true`.
  def verify
    verified ? self : dup.tap { |v| v.instance_variable_set(:@verified, true) }.freeze
  end

  # If the current App is `verified`, then return a copy of the current App
  # with the verified flag set to `false`.
  def unverify
    verified ? dup.tap { |v| v.instance_variable_set(:@verified, false) }.freeze : self
  end

  # Generate a nonce for this application. Optionally provide a version number
  # override to generate a compatible (upgraded) nonce version.
  def generate_nonce(version = nil)
    version ||= self.version

    unless self.version <= version
      raise "app version #{self.version} is not compatible with requested version #{version}"
    end

    AppIdentity::Versions[version].generate_nonce
  end

  def to_h # :nodoc:
    {config: config, id: id, secret: secret.call, version: version}
  end

  alias_method :as_json, :to_h

  def to_s # :nodoc:
    inspect
  end

  def to_json(*args, **kwargs) # :nodoc:
    as_json.to_json(*args, **kwargs)
  end

  def hash # :nodoc:
    [AppIdentityApp::App, id, version, config, secret]
  end

  def inspect # :nodoc:
    "#<#{self.class} id: #{id} version: #{version} config: #{config} verified: #{verified}>"
  end

  def ==(other) # :nodoc:
    other.is_a?(self.class) &&
      id == other.id &&
      version == other.version &&
      config == other.config &&
      verified == other.verified &&
      secret.call == other.secret.call
  end

  private

  def get(input, key)
    case input
    when Hash, Struct, OpenStruct
      input[key] || input[key.to_s]
    else
      if input.respond_to?(key)
        input.__send__(key)
      elsif input.respond_to?(:[]) && !input.is_a?(Array)
        input[key] || input[key.to_s]
      else
        raise AppIdentity::Error, "app cannot be created from input (missing value #{key.inspect})"
      end
    end
  end

  def fwrap(value)
    value.respond_to?(:call) ? value : -> { value }
  end

  def validate!
    @id = validate_id(@id)
    @secret = fwrap(validate_secret(@secret))
    @version = validate_version(@version)
    @config = validate_config(@config)
  end
end
