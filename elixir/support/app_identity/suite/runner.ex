defmodule AppIdentity.Suite.Runner do
  @moduledoc false

  @command "run"

  @help_doc """
  Runs one or more integration suites

  ## Usage

      mix app_identity #{@command} [options] [paths...]

  ## Options for run:

      -S, --strict        Runs in strict mode; optional tests will cause failure
      --stdin             Reads a suite from stdin
      -D, --diagnostic    Enables output diagnostics

  ## Global Options:

      -V, --version       Display the version number
      --help              Display help
  """

  def command do
    @command
  end

  def help do
    @help_doc
  end

  @switches [
    aliases: [D: :diagnostic, h: :help, S: :strict, V: :version],
    strict: [
      diagnostic: :boolean,
      help: :boolean,
      quiet: :boolean,
      stdin: :boolean,
      strict: :boolean,
      version: :boolean
    ]
  ]

  def run(args) do
    {options, paths, errors} = OptionParser.parse(args, @switches)

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
        unless run_suites(paths, options) do
          System.halt(1)
        end
    end
  end

  defp run_suites(paths, options) do
    suites = piped_suite(options) ++ load_suites(paths)

    case summarize_and_annotate(suites) do
      {0, _suites} ->
        true

      {_, suites} ->
        Enum.reduce(suites, true, fn suite, result -> run_suite(suite, options) && result end)
    end
  end

  defp load_suites(names) do
    Enum.flat_map(names, &load_suite/1)
  end

  defp load_suite(name) do
    case File.stat!(name).type do
      :directory ->
        name
        |> Path.join("*.json")
        |> Path.wildcard()
        |> load_suites()

      :regular ->
        [parse_suite(File.read!(name))]

      :symlink ->
        [parse_suite(File.read!(name))]

      _ ->
        Mix.raise("Path #{name} is not a file or a directory.")
    end
  end

  defp piped_suite(options) do
    if options[:stdin] do
      [parse_suite(read_stdin())]
    else
      []
    end
  end

  def parse_suite(data) do
    Jason.decode!(data)
  end

  if Version.compare(System.version(), "1.13.0") == :lt do
    defp read_stdin(acc \\ []) do
      IO.read(:stdio, :all)
    end
  else
    defp read_stdin(acc \\ []) do
      case IO.read(:stdio, :eof) do
        :eof ->
          acc
          |> Enum.reverse()
          |> IO.iodata_to_binary()

        {:error, reason} ->
          Mix.raise(reason)

        data ->
          read_stdin([data | acc])
      end
    end
  end

  defp summarize_and_annotate(suites) do
    %{total: total, suites: annotated_suites} =
      suites
      |> Enum.reduce(%{index: 0, total: 0, suites: []}, &annotate_suite/2)

    Mix.shell().info("TAP Version 14\n1..#{total}\n")

    if total == 0 do
      Mix.shell().info("# No suites provided.")
    end

    {total, Enum.reverse(annotated_suites)}
  end

  defp annotate_suite(suite, %{index: index, total: total, suites: suites}) do
    %{length: length, index: current_index, tests: tests} = annotate_tests(suite["tests"], index)

    %{
      total: total + length,
      index: current_index,
      suites: [Map.put(suite, "tests", Enum.reverse(tests)) | suites]
    }
  end

  defp annotate_tests(tests, last_index) do
    Enum.reduce(tests, %{length: 0, index: last_index, tests: []}, &annotate_test/2)
  end

  defp annotate_test(test, %{length: length, index: index, tests: tests}) do
    %{
      length: length + 1,
      index: index + 1,
      tests: [Map.put(test, "index", index + 1) | tests]
    }
  end

  defp run_suite(suite, options) do
    Mix.shell().info(
      "# #{AppIdentity.Suite.banner()} testing #{suite["name"]} #{suite["version"]} (spec #{suite["spec_version"]})"
    )

    Enum.reduce(suite["tests"], true, fn test, result -> run_test(test, options) && result end)
  end

  defp run_test(test, options) do
    {result, message} =
      if AppIdentity.info(:spec_version) < test["spec_version"] do
        {true,
         "ok #{test["index"]} - #{test["description"]} # SKIP unsupported spec version #{AppIdentity.info(:spec_version)} < #{test["spec_version"]}"}
      else
        check_result(
          test,
          AppIdentity.Internal.verify_proof(test["proof"], test["app"]),
          options
        )
      end

    Mix.shell().info(message)
    result
  rescue
    ex ->
      {result, message} = check_result(test, {:error, ex})

      Mix.shell().info(message)
      result
  end

  defp check_result(%{"expect" => "pass"} = test, {:ok, %AppIdentity.App{}}, _options) do
    ok(test)
  end

  defp check_result(%{"expect" => "pass"} = test, {:ok, nil}, options) do
    not_ok(test, "proof verification failed", options)
  end

  defp check_result(%{"expect" => "pass"} = test, {:error, message}, options) do
    not_ok(test, message, options)
  end

  defp check_result(%{"expect" => "fail"} = test, {:ok, %AppIdentity.App{id: app_id}}, options) do
    not_ok(test, "proof should have failed #{app_id}", options)
  end

  defp check_result(%{"expect" => "fail"} = test, {:error, _}) do
    ok(test)
  end

  defp ok(test) do
    {true, "ok #{test["index"]} - #{test["description"]}"}
  end

  defp not_ok(test, error, options) do
    message = "not ok #{test["index"]} - #{test["description"]}"

    message =
      case {!test["required"], !options[:strict]} do
        {true, true} -> "#{message} # TODO optional failing test"
        _ -> message
      end

    message =
      if options[:diagnostic] do
        "#{message}\n  ---\n  message: #{AppIdentity.Suite.extract_message(error)}\n  ..."
      else
        message
      end

    {false, message}
  end
end
