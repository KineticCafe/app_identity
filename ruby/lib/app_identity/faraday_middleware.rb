# frozen_string_literal: true

if defined?(Faraday::Middleware)
  require "app_identity"

  # A Faraday middleware that generates an app identity proof header for
  # a request.
  #
  # The `options` provided has the following parameters:
  #
  # - `app`: (required) An AppIdentity::App or object that can be coerced into
  #   an AppIdentity::app with AppIdentity#new.
  #
  # - `disallowed`: A list of algorithm versions that are not allowed when
  #   processing received identity proofs. See AppIdentity::Versions.allowed?.
  #
  # - `header`: (required) The header to use for sending the app identity proof.
  #
  # - `on_failure`: (optional) The action to take when an app identity proof
  #   cannot be generated for any reason. May be one of the following values:
  #
  #     - `:fail`: Throws an exception. This is the default if `on_failure` is
  #       not specified.
  #
  #     - `:pass`: Sets the header to the empty value returned. The request will
  #       probably fail on the receiving server side.
  #
  #     - `:skip`: Does not add the header, as if the request were not made
  #       using an application.
  #
  # `on_failure` may also be provided a callable object that expects three
  # parameters:
  #
  # - `env`: The Faraday middleware `env` value;
  # - `app`: The identity app value provided to the middleware; and
  # - `header`: The header name provided to the middleware.
  #
  # The callable may return either the `env`, `:fail`, `:skip`, or `:pass`. Any
  # other value will be treated as `:fail`.
  class AppIdentity::FaradayMiddleware < Faraday::Middleware
    def initialize(app, options = {}) # :nodoc:
      super(app)

      @identity_app = AppIdentity::App.new(options.fetch(:app))
      @header = options.fetch(:header).downcase
      @on_failure = options.fetch(:on_failure, :fail)
      @disallowed = options.fetch(:disallowed, nil)
    end

    def call(env) # :nodoc:
      proof = AppIdentity.generate_proof(@identity_app, disallowed: @disallowed)

      if proof.nil?
        handle_failure(@on_failure)
      else
        env[:request_headers][@header] = proof
      end

      @app.call(env)
    end

    private

    def handle_failure(on_failure)
      case on_failure
      when :skip
        nil
      when :pass
        env[:request_headers][@header] = ""
      when :fail
        raise AppIdentity::Error, "unable to generate proof for app #{@identity_app.id}"
      else
        if on_failure.respond_to?(:call)
          result = on_failure.call(env, @identity_app, @header)

          case result
          when :skip, :pass, :fail
            return handle_failure(result)
          else
            if result.eql?(env)
              return
            else
              return handle_failure(:fail)
            end
          end
        end

        handle_failure(:fail)
      end
    end
  end

  Faraday::Request.register_middleware app_identity: -> { AppIdentity::FaradayMiddleware }
end
