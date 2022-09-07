# frozen_string_literal: true

require "json"
require "app_identity/support"

class AppIdentity::Suite::Generator # :nodoc:
  include AppIdentity::Validation
  include AppIdentity::Support

  class << self
    private :new

    def run(name, options)
      new(name, options).run
    end
  end

  def initialize(name, options)
    @name = name.first || options[:default_suite]
    @options = options

    if !options[:stdout] && !@name.end_with?(".json")
      @name =
        if File.directory?(@name)
          File.join(@name, options[:default_suite])
        else
          "#{@name}.json"
        end
    end
  end

  def run
    suite = generate_suite

    if !options[:stdout] && !options[:quiet]
      puts "Generated #{suite[:tests].length} tests for #{suite[:name]} #{suite[:version]}."
    end

    if options[:stdout]
      puts JSON.pretty_generate(suite)
    else
      File.write(name, JSON.generate(suite))
      puts "Saved as #{name}" if !options[:quiet]
    end

    true
  end

  private

  def generate_suite
    {
      name: AppIdentity::NAME,
      version: AppIdentity::VERSION,
      spec_version: AppIdentity::SPEC_VERSION,
      tests: [
        *generate_tests("required", load_json(required_tests)),
        *generate_tests("optional", load_json(optional_tests))
      ]
    }
  end

  def load_json(name)
    JSON.load_file!(name)
  end

  def required_tests
    File.expand_path("../required.json", __FILE__)
  end

  def optional_tests
    File.expand_path("../optional.json", __FILE__)
  end

  def generate_tests(type, input)
    input.map.with_index { |entry, index| generate_test(type, entry, index) }
  end

  def generate_test(type, input, index)
    normalized = normalize_test(type, input, index)

    app =
      if normalized[:app]
        make_app(normalized.dig(:app, :version), normalized.dig(:app, :config, :fuzz))
      else
        make_app(1)
      end

    {
      description: normalized.fetch(:description),
      expect: normalized.fetch(:expect),
      app: app.as_json,
      proof: make_proof(type, normalized, index, app),
      required: type == "required",
      spec_version: normalized.fetch(:spec_version)
    }
  end

  def normalize_test(type, input, index)
    must_have!(type, input, index, "description")
    must_have!(type, input, index, "expect")
    must_have!(type, input, index, "proof")
    must_have!(type, input, index, "spec_version")

    if !%w[pass fail].include?(input["expect"])
      fail!(type, input, index, "Invalid expect value '#{input["expect"]}'")
    end

    test = {
      description: input["description"],
      expect: input["expect"],
      spec_version: input["spec_version"]
    }

    if input.key?("app")
      tmp = input["app"]

      must_have!(type, tmp, index, "version", input: input, name: "app.version")

      app = {version: tmp["version"]}

      if tmp.key?("config")
        must_have!(type, tmp["config"], index, "fuzz", input: input, name: "app.config.fuzz")

        app[:config] = {fuzz: tmp.dig("config", "fuzz")}
      end

      test[:app] = app
    end

    if input.key?("nonce")
      nonce = {}
      tmp = input["nonce"]

      if tmp.key?("empty")
        if tmp.key?("offset_minutes") || tmp.key?("value")
          fail!(type, input, index, "nonce must only have one sub-key")
        end

        nonce[:empty] = !!tmp["empty"]
      elsif tmp.key?("offset_minutes")
        if tmp.key?("value")
          fail!(type, input, index, "nonce must only have one sub-key")
        end

        nonce[:offset_minutes] = tmp["offset_minutes"]
      elsif tmp.key?("value")
        nonce[:value] = tmp["value"]
      else
        fail!(type, input, index, "nonce requires exactly one sub-key")
      end

      test[:nonce] = nonce
    end

    if input.key?("padlock")
      tmp = input["padlock"]
      must_have!(type, tmp, index, "nonce", input: input, name: "padlock.nonce")
      test[:padlock] = {nonce: tmp["nonce"]}
    end

    tmp = input["proof"]
    must_have!(type, tmp, index, "version", input: input, name: "proof.version")

    proof = {version: tmp["version"]}
    proof[:id] = tmp["id"] if tmp.key?("id")
    proof[:secret] = tmp["secret"] if tmp.key?("secret")

    test[:proof] = proof

    test
  end

  def make_proof(type, input, index, app)
    version = validate_version(input.fetch(:proof).fetch(:version))

    nonce =
      if input.dig(:nonce, :empty)
        ""
      elsif (value = input.dig(:nonce, :offset_minutes))
        timestamp_nonce(value)
      elsif (value = input.dig(:nonce, :value))
        value
      else
        app.generate_nonce(version)
      end

    if input[:padlock]
      padlock = build_padlock(app, {
        id: input.dig(:proof, :id),
        nonce: input.dig(:padlock, :nonce),
        secret: input.dig(:proof, :secret),
        version: input.dig(:proof, :version)
      })

      return build_proof(app, padlock, {
        id: input.dig(:proof, :id),
        nonce: nonce,
        secret: input.dig(:proof, :secret),
        version: input.dig(:proof, :version)
      })
    end

    if input.dig(:proof, :id) || input.dig(:proof, :secret) || input[:nonce]
      padlock = build_padlock(app,
        id: input.dig(:proof, :id),
        nonce: nonce,
        secret: input.dig(:proof, :secret),
        version: input.dig(:proof, :version))

      return build_proof(app, padlock,
        id: input.dig(:proof, :id),
        nonce: nonce,
        secret: input.dig(:proof, :secret),
        version: input.dig(:proof, :version))
    end

    AppIdentity::Internal.generate_proof!(app, nonce: nonce, version: version)
  rescue => ex
    fail!(type, input, index, ex.message)
  end

  def fail!(type, input, index, message)
    extra = ""

    if message.is_a?(Exception)
      extra = "\n#{message.backtrace.join("\n")}"
      message = message.message
    end

    raise "Error in #{type} item #{index + 1}: #{message}\n" +
      JSON.pretty_generate(input) +
      extra
  end

  def must_have!(type, input, index, key, options = {})
    return if input.key?(key)
    fail!(type, options[:input] || input, index, "missing #{options[:name] || key}")
  end

  attr_reader :name, :options
end
