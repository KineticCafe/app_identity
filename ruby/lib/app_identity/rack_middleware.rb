# frozen_string_literal: true

require "rack"
require "app_identity"
require "app_identity/error"
require "set"

# A Rack middleware that verifies App Identity proofs provided via one or more
# HTTP headers.
#
# When multiple proof values are provided in the request, all must be
# successfully verified. If any of the proof values cannot be verified, request
# processing halts with `403 Forbidden`. Should no proof headers are included,
# the request is considered invalid.
#
# All of the above behaviours can be modified through configuration (see below).
#
# The results of completed proof validations can be found at
# env["app_identity"], regardless of success or failure.
#
# ### Configuration
#
# The Rack middlware can be configured with the following options:
#
# - `apps`: A list of AppIdentity::App objects or objects that can be converted
#   into AppIdentity::App objects to be used for proof validation. Duplicate
#   values will be ignored.
#
# - `disallowed`: A list of algorithm versions that are not allowed when
#   processing received identity proofs. See AppIdentity::Versions.allowed?.
#
# - `finder`: A 1-arity callable function that will load an input to
#   AppIdentity::App.new from an external source given a parsed proof.
#
# - `headers`: A list of HTTP header names.
#
# - `on_failure`: The behaviour of the Rack middleware when proof validation
#   fails. Must be one of the following values:
#
#     - `:forbidden`: Halt request processing and respond with a `403`
#       (forbidden) status. This is the same as `[:halt, :forbidden]`. This is
#       the default `on_failure` behaviour.
#
#     - `[:halt, status]`: Halt request processing and return the specified
#       status code. An empty body is emitted.
#
#     - `[:halt, status, body]`: Halt request processing and return the
#       specified status code. The body value is included in the response.
#
#     - `:continue`: Continue processing, ensuring that failure states are
#       recorded for the application to act on at a later point. This could be
#       used to implement a distinction between *validating* a proof and
#       *requiring* that the proof is valid.
#
#     - A 1-arity callable accepting the Rack `env` value and returns one of the
#       above values.
#
# At least one of `apps` or `finder` **must** be supplied. If both are present,
# apps are looked up in the `apps` list first.
#
# ```ruby
# use AppIdentity::RackMiddleware, header: "application-identity",
#   finder: ->(proof) { ApplicationModel.find(proof[:id]) }
# ```
class AppIdentity::RackMiddleware
  def initialize(app, options = {}) # :nodoc:
    @app = app

    if !options.has_key?(:apps) && !options.has_key?(:finder)
      raise AppIdentity::Error, :plug_missing_apps_or_finder
    end

    @apps = get_apps(options)
    @finder = options[:finder]

    if @apps.empty? && @finder.nil?
      raise "One of `apps` or `finder` options is required."
    end

    @disallowed = get_disallowed(options)
    @headers = get_headers(options)
    @on_failure = get_on_failure(options)
  end

  def call(env) # :nodoc:
    headers = verify_headers(Hash[*@headers.flat_map { |h| [h, env[h]] }])

    env["app_identity"] = headers

    if has_errors?(headers)
      dispatch_on_failure(@on_failure, env)
    else
      @app.call(env)
    end
  end

  private

  def dispatch_on_failure(on_failure, env)
    if on_failure.respond_to?(:call)
      dispatch_on_failure(on_failure.call(env), env)
    elsif on_failure == :forbidden
      halt
    elsif on_failure == :continue
      @app.call(env)
    elsif on_failure.is_a?(Array) && on_failure.first == :halt
      _, status, body = on_failure
      halt(status, body)
    end
  end

  def has_errors?(headers)
    headers.empty? || headers.any? { |_k, v| v.nil? || v.empty? || v.any? { |vv| vv.nil? || !vv.verified } }
  end

  def halt(status = nil, body = nil)
    status ||= :forbidden
    status = Rack::Utils.status_code(status) if status.is_a?(Symbol)

    body = Array(body)

    length = body.empty? ? "0" : body.length.to_s

    [status, {"Content-Type" => "text/plain", "Content-Length" => length}, body]
  end

  def verify_headers(headers)
    headers.each_with_object({}) { |(header, values), result|
      next if values.nil? || values.empty?

      # If Rack can start returning arrays, we are ready.

      result[header] = Array(values).each_with_object([]) { |value, list|
        break list if verify_header_value(value, list) == :halt
      }
    }
  end

  def verify_header_value(value, list)
    proof = AppIdentity.parse_proof(value)
    return handle_proof_error(list, nil) unless proof

    app = @apps[proof[:id]]

    if app.nil? && @finder
      app = AppIdentity::App.new(finder.call(proof))
      @apps[app.id] = app
    end

    return handle_proof_error(list, nil) unless app

    verified = AppIdentity.verify_proof(proof, app, disallowed: @disallowed)

    if verified
      list << verified
      :cont
    else
      handle_proof_error(list, verified)
    end
  end

  def handle_proof_error(list, value)
    case @on_failure
    when :continue
      list << value
      :cont
    when :forbidden, Array
      :halt
    else
      list << value
      :cont
    end
  end

  def get_request_headers(env)
    Hash[*@headers.lazy.flat_map { |header| [header, env[header]] }]
  end

  def get_apps(options)
    options.fetch(:apps, []).each_with_object({}) { |input, map|
      app = AppIdentity::App.new(input)
      map[app.id] = app unless map.key?(app.id)
    }
  end

  def get_disallowed(options)
    disallowed = options[:disallowed] || []

    if disallowed.is_a?(Set)
      disallowed
    elsif disallowed.is_a?(Array)
      Set.new(disallowed)
    else
      raise AppIdentity::Error, :plug_disallowed_invalid
    end
  end

  def get_headers(options)
    headers = options[:headers] || []

    raise AppIdentity::Error, :plug_headers_required if !headers.is_a?(Array) || headers.empty?

    headers.map { |header| parse_option_header(header) }
  end

  def get_on_failure(options)
    resolve_on_failure_option(options[:on_failure] || :forbidden)
  end

  def parse_option_header(header)
    if !header.is_a?(String) || header.empty?
      raise AppIdentity::Error, :plug_header_invalid
    end

    if /\AHTTP_[A-Z_0-9]+\z/.match?(header)
      header
    else
      -"HTTP_#{header.to_s.tr("-", "_").upcase}"
    end
  end

  def resolve_on_failure_option(value)
    valid =
      case value
      when :forbidden, :continue
        true
      when Array
        case [value.first, value.length, value[1].class]
        when [:halt, 2, Symbol], [:halt, 2, Integer], [:halt, 3, Symbol], [:halt, 3, Integer]
          true
        end
      else
        value.respond_to?(:call)
      end

    if valid
      value
    else
      raise AppIdentity::Error, :plug_on_failure_invalid
    end
  end
end
