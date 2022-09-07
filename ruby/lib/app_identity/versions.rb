# frozen_string_literal: true

require "time"
require "digest/sha2"
require "securerandom"
require "set"

require_relative "validation"
require_relative "error"

class AppIdentity
  module Versions # :nodoc:
    class Base # :nodoc:
      class << self
        def defined # :nodoc:
          @defined ||= {}
        end

        def instance # :nodoc:
          @_instance = new
        end

        def inherited(subclass) # :nodoc:
          match = /V(?<version>\d+)\z/.match(subclass.name)
          return unless match
          version = match[:version].to_i

          raise AppIdentity::Error, "version is not unique" if Base.defined.has_key?(version)

          subclass.define_method(:version) { version }

          Base.defined[version] = subclass.instance
        end

        private :new
      end

      def make_digest(raw) # :nodoc:
        digest_algorithm.hexdigest(raw).upcase
      end

      def inspect # :nodoc:
        parts = [self.class]
        parts << "version=#{version}" if respond_to?(:version)
        parts << "nonce=#{nonce_type}" if respond_to?(:nonce_type)
        parts << "digest=#{digest_algorithm}" if respond_to?(:digest_algorithm)
        "#<#{parts.join(" ")}>"
      end

      def check_nonce!(nonce, _config) # :nodoc:
        raise AppIdentity::Error, "nonce must not be nil" if nonce.nil?
        raise AppIdentity::Error, "nonce must be a string" unless nonce.is_a?(String)
        raise AppIdentity::Error, "nonce must not be blank" if nonce.empty?
        raise AppIdentity::Error, "nonce must not contain colon characters" if /:/.match?(nonce)
      end
    end

    class RandomNonce < Base # :nodoc:
      def nonce_type # :nodoc:
        :random
      end

      def generate_nonce # :nodoc:
        SecureRandom.urlsafe_base64(32)
      end
    end

    class TimestampNonce < Base # :nodoc:
      def nonce_type # :nodoc:
        :timestamp
      end

      def generate_nonce # :nodoc:
        Time.now.utc.strftime("%Y%m%dT%H%M%S.%6NZ")
      end

      def check_nonce!(nonce, config) # :nodoc:
        super(nonce, config)

        timestamp = parse_timestamp!(nonce)
        config ||= default_config
        fuzz = config[:fuzz] || config["fuzz"] || 600

        diff = (Time.now.utc - timestamp).abs.to_i

        raise AppIdentity::Error, "nonce is invalid" unless diff <= fuzz
      end

      private

      def default_config
        {fuzz: 600}
      end

      def parse_timestamp!(nonce)
        Time.strptime(nonce, "%Y%m%dT%H%M%S.%N%Z").tap { |value| raise if value.nil? }.utc
      rescue
        raise AppIdentity::Error, "nonce does not look like a timestamp"
      end
    end

    # V1 is the original algorithm, using a permanent nonce value and SHA256
    # digests. The use of this version is strongly discouraged for new clients.
    class V1 < RandomNonce # :nodoc:
      def digest_algorithm # :nodoc:
        Digest::SHA256
      end
    end

    # V2 uses a timestamp-based nonce value with SHA256 digests.
    #
    # The nonce values will be verified to be within plus or minus a configured
    # number of seconds.
    class V2 < TimestampNonce # :nodoc:
      def digest_algorithm # :nodoc:
        Digest::SHA256
      end
    end

    # V3 uses a timestamp-based nonce value with SHA384 digests.
    #
    # The nonce values will be verified to be within plus or minus a configured
    # number of seconds.
    class V3 < TimestampNonce # :nodoc:
      def digest_algorithm # :nodoc:
        Digest::SHA384
      end
    end

    # V4 uses a timestamp-based nonce value with SHA512 digests.
    #
    # The nonce values will be verified to be within plus or minus a configured
    # number of seconds.
    class V4 < TimestampNonce # :nodoc:
      def digest_algorithm # :nodoc:
        Digest::SHA512
      end
    end

    class << self
      include AppIdentity::Validation

      # Looks up the version instance by version.
      def [](version) # :nodoc:
        AppIdentity::Versions::Base.defined.fetch(version)
      end

      # Checks to see if the version has been defined.
      def valid?(version) # :nodoc:
        AppIdentity::Versions::Base.defined.has_key?(version)
      end

      # Tests that the version is valid or raises an exception.
      def valid!(version) # :nodoc:
        return true if valid?(version)
        raise AppIdentity::Error, "version must be one of #{AppIdentity::Versions::Base.defined.keys}"
      end

      # Checks to see if the version is valid and not explicitly disallowed,
      # either in the provided list or in global list.
      def allowed?(version, provided = nil)
        valid?(version) && !disallowed.member?(version) &&
          !Set.new(provided).member?(version)
      end

      # Tests that the version is valid and not explicitly disallowed or raises
      # an exception.
      def allowed!(version, provided = nil)
        return true if valid!(version) && allowed?(version, provided)
        raise AppIdentity::Error, "version #{version} has been disallowed"
      end

      # Globally disallow the listed versions.
      def disallow(*versions)
        disallowed.merge(coerce_versions(versions))
      end

      # Globally allow the listed versions.
      def allow(*versions)
        disallowed.subtract(coerce_versions(versions))
      end

      private

      def coerce_versions(versions)
        versions.select { |v| v.is_a?(Integer) }
      end

      def disallowed
        @disalllowed ||= Set.new
      end
    end
  end
end
