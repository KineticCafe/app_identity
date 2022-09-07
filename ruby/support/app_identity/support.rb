# frozen_string_literal: true

require "securerandom"
require "digest/sha2"

# This module should only be used by the unit tests and the test suite
# generator.
module AppIdentity::Support # :nodoc:
  private

  def make_app(version, fuzz = nil)
    case version
    when 1 then AppIdentity::App.new(v1_input(fuzz))
    when 2 then AppIdentity::App.new(v2_input(fuzz))
    when 3 then AppIdentity::App.new(v3_input(fuzz))
    when 4 then AppIdentity::App.new(v4_input(fuzz))
    end
  end

  def v1_input(fuzz = nil)
    {version: 1, id: SecureRandom.uuid, secret: SecureRandom.hex(32)}.tap { |app|
      app[:config] = {fuzz: fuzz} if fuzz
    }
  end

  def v2_input(fuzz = nil)
    v1_input(fuzz).merge(version: 2)
  end

  def v3_input(fuzz = nil)
    v1_input(fuzz).merge(version: 3)
  end

  def v4_input(fuzz = nil)
    v1_input(fuzz).merge(version: 4)
  end

  def v1(fuzz = nil)
    @v1 ||= v1_input(fuzz)
  end

  def v1_app(fuzz = nil)
    AppIdentity::App.new(v1(fuzz))
  end

  def v2(fuzz = nil)
    @v2 ||= v2_input(fuzz)
  end

  def v2_app(fuzz = nil)
    AppIdentity::App.new(v2)
  end

  def v3(fuzz = nil)
    @v3 ||= v3_input(fuzz)
  end

  def v3_app(fuzz = nil)
    AppIdentity::App.new(v3)
  end

  def v4(fuzz = nil)
    @v4 ||= v4_input(fuzz)
  end

  def v4_app(fuzz = nil)
    AppIdentity::App.new(v4)
  end

  def build_padlock(app, opts = {})
    app_id = opts.delete(:id) { app.id }
    nonce = opts.delete(:nonce) { "nonce" }
    secret = opts.delete(:secret) { app.secret }
    secret = secret.call if secret.respond_to?(:call)
    version = opts.delete(:version) { app.version }

    case version
    when 1, 2
      Digest::SHA256.hexdigest([app_id, nonce, secret].join(":")).upcase
    when 3
      Digest::SHA384.hexdigest([app_id, nonce, secret].join(":")).upcase
    when 4
      Digest::SHA512.hexdigest([app_id, nonce, secret].join(":")).upcase
    end
  end

  def build_proof(app, padlock, opts = {})
    app_id = opts.delete(:id) { app.id }
    nonce = opts.delete(:nonce) { "nonce" }
    version = opts.delete(:version) { 1 }

    proof = version == 1 ? "#{app_id}:#{nonce}:#{padlock}" : "#{version}:#{app_id}:#{nonce}:#{padlock}"

    Base64.urlsafe_encode64(proof)
  end

  def decode_to_parts(header)
    Base64.decode64(header).split(":")
  end

  def timestamp_nonce(diff = nil, scale = :minutes)
    ts = adjust(Time.now.utc, diff, scale)

    ts.strftime("%Y%m%dT%H%M%S.%6NZ")
  end

  def adjust(ts, diff, scale)
    return ts if diff.nil?

    case scale
    when :second, :seconds
      ts + diff
    when :minute, :minutes
      ts + (diff * 60)
    when :hour, :hours
      ts + (diff * 60 * 60)
    end
  end
end
