defmodule AppIdentity.Suite.Help do
  @moduledoc false

  @command "help"
  @help_doc """
  Display help for a command

  ## Usage

      mix app_identity #{@command} [options] <command>

  ## Options:

      -V, --version    Display the version number
      -h, --help       Display help

  ## Commands:

      generate          Generates an integration test suite
      run               Runs one or more integration suites
      help              Display help for a command
  """

  def command do
    @command
  end

  def help do
    @help_doc
  end

  @switches [
    aliases: [h: :help, V: :version],
    strict: [version: :boolean, help: :boolean]
  ]

  def run(args) do
    {options, args, errors} = OptionParser.parse(args, @switches)

    case errors do
      [{bad_option, _} | _] -> Mix.raise("Unknown option #{bad_option}.\n\n")
      _ -> nil
    end

    cond do
      options[:version] ->
        Mix.Task.run("app_identity", ["--version"])

      options[:help] ->
        AppIdentity.Suite.print_help(__MODULE__)

      true ->
        dispatch(args)
    end
  end

  defp dispatch(["generate" | _]) do
    AppIdentity.Suite.print_help(AppIdentity.Suite.Generator)
  end

  defp dispatch(["run" | _]) do
    AppIdentity.Suite.print_help(AppIdentity.Suite.Runner)
  end

  defp dispatch(["help" | _]) do
    AppIdentity.Suite.print_help(__MODULE__)
  end

  defp dispatch([command | _]) do
    Mix.raise("Unknown app_identity command #{inspect(command)}")
  end
end
