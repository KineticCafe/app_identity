# frozen_string_literal: true

require_relative "error"

class AppIdentity
  module Validation # :nodoc:
    def validate_id(id) # :nodoc:
      id.tap {
        validate_not_nil(:id, id)
        validate_not_empty(:id, id.to_s)
        validate_no_colons(:id, id.to_s)
      }.to_s
    end

    def validate_secret(secret) # :nodoc:
      secret.tap {
        secret = secret.call if secret.respond_to?(:call)

        validate_not_nil(:secret, secret)
        raise AppIdentity::Error, "secret must be a binary string value" unless secret.is_a?(String)
        validate_not_empty(:secret, secret)
      }
    end

    def validate_version(version) # :nodoc:
      version.tap {
        validate_not_nil(:version, version)

        begin
          version = Integer(version) if version.is_a?(String)
        rescue
          raise AppIdentity::Error, "version cannot be converted to an integer"
        end

        if !version.is_a?(Integer) || version <= 0
          raise AppIdentity::Error, "version must be a positive integer"
        end
      }.to_i
    end

    def validate_config(config) # :nodoc:
      config.tap {
        raise AppIdentity::Error, "config must be nil or a map" unless config.nil? || config.is_a?(Hash)

        if config.is_a?(Hash)
          fuzz = config[:fuzz] || config["fuzz"]

          case fuzz
          when nil
            nil
          when Integer
            raise AppIdentity::Error, "config.fuzz must be a positive integer or nil" unless fuzz > 0
          else
            raise AppIdentity::Error, "config.fuzz must be a positive integer or nil"
          end
        end
      }
    end

    def validate_padlock(padlock) # :nodoc:
      padlock.tap {
        validate_not_nil(:padlock, padlock)
        raise AppIdentity::Error, "padlock must be a string" unless padlock.is_a?(String)
        validate_not_empty(:padlock, padlock)
        validate_no_colons(:padlock, padlock)
      }
    end

    private

    def validate_not_nil(type, value)
      raise AppIdentity::Error, "#{type} must not be nil" if value.nil?
    end

    def validate_not_empty(type, value)
      raise AppIdentity::Error, "#{type} must not be an empty string" if value.empty?
    end

    def validate_no_colons(type, value)
      raise AppIdentity::Error, "#{type} must not contain colons" if /:/.match?(value)
    end
  end
end
