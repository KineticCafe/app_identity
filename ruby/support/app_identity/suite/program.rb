# frozen_string_literal: true

class AppIdentity::Suite::Program # :nodoc:
  class << self
    private :new

    def run(name:) # :nodoc:
      new(name).parse_and_run
    end
  end

  COMMANDS = {
    "generate" => "Generates an integration test suite",
    "run" => "Runs one or more integration suites",
    "help" => "Display help for a command"
  }

  def initialize(name)
    @name = name
    @default_suite = "#{@name}.json"
    @command = nil
    @main = nil

    @parsers = {
      "generate" => generate_parser,
      "help" => help_parser,
      "main" => main_parser,
      "run" => run_parser
    }
  end

  def parse_and_run
    parse(main_parser)
    return main_parser.educate if ARGV.empty?

    @command = ARGV.shift
    unknown_command!(main_parser)
    __send__(:"#{@command}")
  end

  private

  def generate
    AppIdentity::Suite::Generator.run(ARGV, parse(generate_parser)
      .merge({default_suite: @default_suite}))
  end

  def run
    AppIdentity::Suite::Runner.run(ARGV, parse(run_parser))
  end

  def help
    parse(help_parser)
    return help_parser.educate if ARGV.empty?

    @command = ARGV.shift
    unknown_command!(help_parser)

    @parsers[@command].educate
  end

  def unknown_command!(parser)
    parser.die "unknown command #{@command.inspect}" unless COMMANDS.key?(@command)
  end

  def parse(parser)
    Optimist.with_standard_exception_handling(parser) do
      parser.parse ARGV
    end
  end

  private

  def main_parser
    @main_parser ||= begin
      name = @name
      Optimist::Parser.new do
        version "#{name} #{AppIdentity::VERSION}"
        usage "Usage: #{name} [options] [command]"

        synopsis "Generates or runs App Identity integration tests suites in Ruby"

        banner usage
        banner ""
        banner <<~BANNER
          #{synopsis}

          Options:
        BANNER

        opt :version, "Display the version number", short: "V"
        opt :help, "Display help", short: "h"

        banner ""
        banner "Commands:"

        COMMANDS.each { |cmd, desc| banner format("  %-15s   %s", cmd, desc) }

        educate_on_error
        stop_on COMMANDS.keys
      end
    end
  end

  def help_parser
    @help_parser ||= begin
      name = @name

      Optimist::Parser.new do
        version "#{name} #{AppIdentity::VERSION}"
        usage "Usage: #{name} [options] help <command>"

        synopsis "Display help for a command"

        banner usage
        banner ""
        banner <<~BANNER
          #{synopsis}

          Options:
        BANNER

        opt :version, "Display the version number", short: "V"
        opt :help, "Display help", short: "h"

        banner ""
        banner "Commands:"

        COMMANDS.each { |cmd, desc| banner format("  %-15s   %s", cmd, desc) }

        educate_on_error
      end
    end
  end

  def generate_parser
    @generate_parser ||= begin
      name = @name
      default_suite = @default_suite

      Optimist::Parser.new do
        version "#{name} #{AppIdentity::VERSION}"
        usage "Usage: #{name} generate [options] [suite]"

        synopsis <<~SYNOPSIS
          Generates an integration test suite JSON file, defaulting to
          "#{default_suite}".
        SYNOPSIS

        banner usage
        banner ""
        banner <<~BANNER
          #{synopsis}

          Options for generate:
        BANNER

        opt :stdout, "Prints the suite to standard output instead of saving it", short: :none
        opt :quiet, "Silences diagnostic messages", short: "q"

        banner <<~BANNER

          Global Options:
        BANNER
        opt :version, "Display the version number", short: "V"
        opt :help, "Display help", short: "h"

        educate_on_error
      end
    end
  end

  def run_parser
    @run_parser ||= begin
      name = @name

      Optimist::Parser.new do
        version "#{name} #{AppIdentity::VERSION}"
        usage "Usage: #{name} run [options] [paths...]"

        synopsis "Runs one or more integration suites"

        banner usage
        banner ""
        banner <<~BANNER
          #{synopsis}

          Options for run:
        BANNER

        opt :strict, "Runs in strict mode; optional tests will cause failure", short: "S"
        opt :stdin, "Reads a suite from stdin", short: :none
        opt :diagnostic, "Enables output diagnostics", short: "D"

        banner ""
        banner "Global Options:"
        opt :version, "Display the version number", short: "V"
        opt :help, "Display help", short: "h"

        educate_on_error
      end
    end
  end
end
