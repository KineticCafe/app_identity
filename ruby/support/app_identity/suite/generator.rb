# frozen_string_literal: true

require "json"
require "app_identity/support"

class AppIdentity::Suite::Generator # :nodoc:
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
    name, version, spec_version = AppIdentity::NAME, AppIdentity::VERSION, AppIdentity::SPEC_VERSION
    description = "#{name} #{version} (spec #{spec_version})"

    {
      name: name,
      version: version,
      spec_version: spec_version,
      description: description,
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
        AppIdentity::Support.make_app(
          normalized.dig(:app, :version),
          normalized.dig(:app, :config, :fuzz)
        )
      else
        AppIdentity::Support.make_app(1)
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
    must_have!(type, input, index, "proof")
    must_have!(type, input, index, "spec_version")
    must_be_one_of!(type, input, index, "expect", ["pass", "fail"])

    {
      description: input["description"],
      expect: input["expect"],
      spec_version: input["spec_version"]
    }.merge(
      normalize_app(input, type, index),
      normalize_nonce(input, type, index),
      normalize_padlock(input, type, index),
      normalize_proof(input, type, index)
    )
  end

  def normalize_app(input, type, index)
    if (app = input["app"])
      must_have!(type, app, index, "version", input: input, name: "app.version")

      new_app = {version: app["version"]}

      if app.key?("config")
        must_have!(type, app["config"], index, "fuzz", input: input, name: "app.config.fuzz")
        new_app[:config] = {fuzz: app.dig("config", "fuzz")}
      end

      {app: new_app}
    else
      {}
    end
  end

  def normalize_nonce(input, type, index)
    if (nonce = input["nonce"])
      new_nonce =
        if nonce.key?("empty") && nonce.key?("offset_minutes")
          fail!(type, input, index, "nonce must only have one sub-key")
        elsif nonce.key?("empty") && nonce.key?("value")
          fail!(type, input, index, "nonce must only have one sub-key")
        elsif nonce.key?("offset_minutes") && nonce.key?("value")
          fail!(type, input, index, "nonce must only have one sub-key")
        elsif nonce["empty"] == true || nonce["empty"] == "true"
          {empty: true}
        elsif nonce.key?("empty")
          fail!(type, input, index, "nonce.empty may only be true")
        elsif nonce.key?("offset_minutes") && (value = nonce["offset_minutes"])
          if value.is_a?(Integer)
            {offset_minutes: value}
          else
            fail!(type, input, index, "nonce.offset_minutes must be an integer")
          end
        elsif nonce.key?("value")
          {value: nonce["value"]}
        else
          fail!(type, input, index, "nonce requires exactly one sub-key")
        end

      {nonce: new_nonce}
    else
      {}
    end
  end

  def normalize_padlock(input, type, index)
    if (padlock = input["padlock"])
      new_padlock = if padlock.is_a?(Hash) && padlock.size == 0
        fail!(type, input, index, "padlock must have at least one sub-key: value, nonce, or case")
      elsif padlock.key?("value") && padlock.size > 1
        fail!(type, input, index, "padlock.value must not have any other sub-keys specified")
      elsif padlock.key?("value") && padlock["value"].empty?
        fail!(type, input, index, "padlock.value must not be an empty string")
      elsif padlock.key?("value")
        {value: padlock["value"]}
      elsif padlock.key?("nonce") && padlock.key?("case")
        {
          nonce: padlock["nonce"],
          case: normalize_padlock_case(padlock["case"], type, input, index)
        }
      elsif padlock.key?("nonce")
        {nonce: padlock["nonce"]}
      elsif padlock.key?("case")
        {case: normalize_padlock_case(padlock["case"], type, input, index)}
      else
        fail!(type, input, index, "padlock must have at least one sub-key: value, nonce, or case")
      end

      {padlock: new_padlock}
    else
      {}
    end
  end

  def normalize_padlock_case(value, type, input, index)
    case value
    when "lower", :lower then :lower
    when "random", :random then :random
    when "upper", :upper then :upper
    else
      fail!(type, input, index, "padlock.case must be one of 'lower', 'random', or 'upper'")
    end
  end

  def normalize_proof(input, type, index)
    proof = input["proof"]
    must_have!(type, proof, index, "version", input: input, name: "proof.version")

    {
      proof: {
        id: proof["id"],
        secret: proof["secret"],
        version: proof["version"]
      }.delete_if { |_k, v| v.nil? }
    }
  end

  def make_proof(type, input, index, app)
    version = AppIdentity::Validation.validate_version(input.fetch(:proof).fetch(:version))

    nonce =
      if input.dig(:nonce, :empty)
        ""
      elsif (value = input.dig(:nonce, :offset_minutes))
        AppIdentity::Support.timestamp_nonce(value)
      elsif (value = input.dig(:nonce, :value))
        value
      else
        app.generate_nonce(version)
      end

    if (padlock_value = input.dig(:padlock, :value))
      AppIdentity::Support.build_proof(app, padlock_value, {
        id: input.dig(:proof, :id),
        nonce: nonce,
        secret: input.dig(:proof, :secret),
        version: input.dig(:proof, :version)
      })
    elsif (padlock = input[:padlock])
      padlock = AppIdentity::Support.build_padlock(app, {
        id: input.dig(:proof, :id),
        nonce: padlock[:nonce] || nonce,
        secret: input.dig(:proof, :secret),
        version: input.dig(:proof, :version),
        case: padlock[:case] || :random
      })

      AppIdentity::Support.build_proof(app, padlock, {
        id: input.dig(:proof, :id),
        nonce: nonce,
        secret: input.dig(:proof, :secret),
        version: input.dig(:proof, :version)
      })
    elsif input.dig(:proof, :id) || input.dig(:proof, :secret) || input[:nonce]
      padlock = AppIdentity::Support.build_padlock(app, {
        id: input.dig(:proof, :id),
        nonce: nonce,
        secret: input.dig(:proof, :secret),
        version: input.dig(:proof, :version),
        case: :random
      })

      AppIdentity::Support.build_proof(app, padlock,
        id: input.dig(:proof, :id),
        nonce: nonce,
        secret: input.dig(:proof, :secret),
        version: input.dig(:proof, :version))
    else
      AppIdentity::Internal.generate_proof!(app, nonce: nonce, version: version)
    end
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

  def must_be_one_of!(type, input, index, key, values)
    must_have!(type, input, index, key)

    return if values.include?(input[key])

    fail!(
      type,
      input,
      index,
      "Invalid #{key} value '#{input[key]}', must be one of: #{values.join(", ")}"
    )
  end

  attr_reader :name, :options
end
