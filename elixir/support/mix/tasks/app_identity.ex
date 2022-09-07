defmodule Mix.Tasks.AppIdentity do
  @shortdoc "Generate or run an app identity test suite"

  @moduledoc """
  #{@shortdoc}

  ## Usage

      mix app_identity [options] [command]

  ## Options

      -V, --version    Display the version number
      -h, --help       Display help

  ## Commands

      generate          Generates an integration test suite
      run               Runs one or more integration suites
      help              Display help for command
  """

  use Mix.Task

  alias AppIdentity.Suite

  @requirements ["app.start"]

  @switches [
    aliases: [h: :help, V: :version],
    strict: [version: :boolean, help: :boolean]
  ]

  def run(args) do
    {options, args, errors} = OptionParser.parse_head(args, @switches)

    case errors do
      [{bad_option, _} | _] -> Mix.raise("Unknown option #{bad_option}.\n\n")
      _ -> nil
    end

    cond do
      options[:version] ->
        version()

      options[:help] ->
        help()

      true ->
        dispatch(args)
    end
  end

  defp dispatch(["generate" | args]) do
    Suite.Generator.run(args)
  end

  defp dispatch(["run" | args]) do
    Suite.Runner.run(args)
  end

  defp dispatch(["help" | args]) do
    Suite.Help.run(args)
  end

  defp dispatch([command | _]) do
    Mix.raise("Unknown app_identity command #{inspect(command)}")
  end

  defp help do
    Mix.Task.run("help", ["app_identity"])
  end

  defp version do
    Mix.shell().info(AppIdentity.Suite.banner())
  end
end
