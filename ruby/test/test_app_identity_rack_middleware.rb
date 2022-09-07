# frozen_string_literal: true

require "minitest_helper"

require "app_identity/rack_middleware"
require "rack/test"
require "rack/mock"

class TestKineticApplicationRackMiddleware < Minitest::Test
  include Rack::Test::Methods

  HEADER = "HTTP_X_APP_IDENTITY"

  attr_reader :options

  def setup
    @options = {headers: ["x-app-identity"], apps: [v1]}
  end

  def app
    options = @options
    @_app ||= Rack::Builder.new do
      use AppIdentity::RackMiddleware, options

      run ->(_) { [200, {"Content-Type" => "text/plain"}, ["OK"]] }
    end
  end

  def test_empty_headers
    get "/"
    refute last_response.successful?
  end

  def test_invalid_proof
    get "/", {}, {HEADER => "invalid proof"}
    refute last_response.successful?
  end

  def test_invalid_app_header
    get "/", {}, {HEADER => AppIdentity.generate_proof(v2)}
    refute last_response.successful?
  end

  def test_valid_app_header
    get "/", {}, {HEADER => AppIdentity.generate_proof(v1)}
    assert last_response.successful?
  end

  def test_valid_app_v2_header
    options[:apps] = [v2]
    get "/", {}, {HEADER => AppIdentity.generate_proof(v2)}
    assert last_response.successful?
  end

  def test_valid_app_v3_header
    options[:apps] = [v3]
    get "/", {}, {HEADER => AppIdentity.generate_proof(v3)}
    assert last_response.successful?
  end

  def test_valid_app_v4_header
    options[:apps] = [v4]
    get "/", {}, {HEADER => AppIdentity.generate_proof(v4)}
    assert last_response.successful?
  end

  def test_valid_app_header_from_list
    options[:apps] = [v1_app, v2_app]
    get "/", {}, {HEADER => AppIdentity.generate_proof(v2)}
    assert last_response.successful?
  end

  def test_valid_app_multiple_headers
    options[:apps] = [v1_app, v2_app]
    options[:headers] = %w[x-app-identity app-identity]

    get "/", {}, {
      HEADER => AppIdentity.generate_proof(v2),
      "HTTP_APP_IDENTITY" => AppIdentity.generate_proof(v1)
    }

    assert last_response.successful?
  end

  def test_alternate_header
    options[:headers] = ["identity-widget"]
    get "/", {}, {"HTTP_IDENTITY_WIDGET" => AppIdentity.generate_proof(v1)}
    assert last_response.successful?
  end
end
