# frozen_string_literal: true

require_relative "error"
require_relative "validation"
require_relative "versions"

class AppIdentity::Internal # :nodoc:
  include AppIdentity::Validation

  class << self
    private :new

    def instance
      @instance ||= new
    end

    def generate_proof!(app, **kwargs)
      instance.generate_proof!(app, **kwargs)
    end

    def parse_proof!(proof)
      instance.parse_proof!(proof)
    end

    def verify_proof!(proof, app, **kwargs)
      instance.verify_proof!(proof, app, **kwargs)
    end
  end

  def generate_proof!(app, nonce: nil, version: nil, disallowed: nil)
    app = AppIdentity::App.new(app)
    version ||= app.version
    nonce ||= app.generate_nonce(version)

    __generate_proof(app, nonce, version, disallowed: disallowed)
  end

  def parse_proof!(proof)
    return proof if proof.is_a?(Hash)

    raise AppIdentity::Error, "proof must be a string or a map" unless proof.is_a?(String)

    parts = Base64.decode64(proof).split(":", -1)

    case parts.length
    when 4
      version, id, nonce, padlock = parts

      version = validate_version(version)
      AppIdentity::Versions.allowed!(version)

      {version: version, id: id, nonce: nonce, padlock: padlock}
    when 3
      id, nonce, padlock = parts

      {version: 1, id: id, nonce: nonce, padlock: padlock}
    else
      raise AppIdentity::Error, "proof must have 3 parts (version 1) or 4 parts (any version)"
    end
  end

  def verify_proof!(proof, app, disallowed: nil)
    proof = parse_proof!(proof)

    app = app.call(proof) if app.respond_to?(:call)
    app = AppIdentity::App.new(app)

    raise AppIdentity::Error, "proof and app do not match" unless app.id == proof[:id]
    raise AppIdentity::Error, "proof and app version mismatch" if app.version > proof[:version]
    AppIdentity::Versions.allowed!(proof[:version], disallowed)

    valid_nonce!(proof[:nonce], proof[:version], app.config)
    validate_padlock(proof[:padlock])

    padlock = __generate_padlock(app, proof[:nonce], proof[:version])

    compare_padlocks(padlock, proof[:padlock]) ? app.verify : nil
  end

  private

  def __generate_proof(app, nonce, version, disallowed: nil)
    AppIdentity::Versions.allowed!(version, disallowed)

    padlock = __generate_padlock(app, nonce, version)

    return unless padlock

    parts =
      case version
      when 1
        [app.id, nonce, padlock]
      else
        [version, app.id, nonce, padlock]
      end

    Base64.urlsafe_encode64(parts.join(":"))
  end

  def __generate_padlock(app, nonce, version)
    versions_compatible!(app.version, version)
    valid_nonce!(nonce, version, app.config)
    AppIdentity::Versions[version].make_digest([app.id, nonce, app.secret.call].join(":"))
  end

  def versions_compatible!(app_version, version)
    return if app_version <= version
    raise AppIdentity::Error, "app version #{app_version} is not compatible with proof version #{version}"
  end

  def valid_nonce!(nonce, version, config)
    AppIdentity::Versions[version].check_nonce!(nonce, config)
  end

  def compare_padlocks(generated, provided)
    return false if generated.nil? || generated.empty?
    return false if provided.nil? || provided.empty?
    return false if generated.length != provided.length

    generated = generated.upcase.unpack("C*")
    provided = provided.upcase.unpack("C*")

    generated.zip(provided).map { |a, b| a ^ b }.reduce(:+) == 0
  end

  def generate_version_nonce(version)
    version = validate_version(version)
    AppIdentity[validate_version(version)][:nonce].call
  end
end
