# frozen_string_literal: true

require "json"

class AppIdentity::Suite::Runner # :nodoc:
  class << self
    private :new

    def run(paths, options)
      new(paths, options).run
    end
  end

  def initialize(paths, options)
    @paths = paths
    @options = options
    @suites = nil
  end

  def run
    @suites = [*piped_suite, *load_suites(paths)]
    summarize_and_annotate
    suites.reduce(true) { |result, suite| run_suite(suite) && result }
  end

  private

  def load_suites(names)
    names.flat_map { |name| load_suite(name) }
  end

  def load_suite(name)
    if File.file?(name)
      [parse_suite(File.read(name))]
    elsif File.directory?(name)
      load_suites(Dir[File.join(name, "*.json")])
    else
      raise "Path #{name} is not a file or a directory."
    end
  end

  def piped_suite
    data = options[:stdin] ? $stdin.read.strip : nil
    data ? [parse_suite(data)] : []
  end

  def parse_suite(data)
    JSON.parse(data)
  end

  def summarize_and_annotate
    index = 0
    total = 0

    suites.each do |suite|
      tests = suite["tests"]
      total += tests.length

      tests.each do |test|
        index += 1
        test["index"] = index
      end
    end

    puts <<~TAP
      TAP Version 14
      1..#{total}
    TAP

    puts "# No suites provided." if total.zero?
  end

  def run_suite(suite)
    puts "# #{AppIdentity::NAME} #{AppIdentity::VERSION} " \
      "(spec #{AppIdentity::SPEC_VERSION}) testing " \
      "#{suite["name"]} #{suite["version"]} (spec #{suite["spec_version"]})"
    suite["tests"].reduce(true) { |result, test| run_test(test) && result }
  end

  def run_test(test)
    if AppIdentity::INFO[:spec_version] < test["spec_version"]
      compare = [AppIdentity::INFO[:spec_version], "<", test["spec_version"]].join(" ")
      puts "ok #{test["index"]} - #{test["description"]} # SKIP unsupported spec version #{compare}"
      return true
    end

    result, message = check_result(AppIdentity::Internal.verify_proof!(test["proof"], test["app"]), test)

    puts message
    result
  rescue => ex
    result, message = check_result(ex, test)
    puts message
    result
  end

  def check_result(result, test)
    if test["expect"] == "pass"
      if result.is_a?(AppIdentity::App)
        ok(test)
      else
        not_ok(test, result || "proof verification failed")
      end
    elsif result.is_a?(AppIdentity::App)
      not_ok(test, "proof should have failed #{app.inspect}")
    else
      ok(test)
    end
  end

  def ok(test)
    [true, "ok #{test["index"]} - #{test["description"]}"]
  end

  def not_ok(test, error)
    message = "not ok #{test["index"]} - #{test["description"]}"

    if !test["required"] && !options[:strict]
      message << " # TODO optional failing test"
    end

    if options[:diagnostic] && error
      error_message = error.is_a?(Exception) ? error.message : error

      message += "\n  ---\n  message: #{error_message}\n  ..."
    end

    [false, message]
  end

  attr_reader :paths, :options, :suites
end
