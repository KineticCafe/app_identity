defmodule AppIdentity.Suite.Generator do
  @moduledoc false

  alias AppIdentity.Support

  @command "generate"

  @help_doc """
  Generates an integration test suite JSON file, defaulting to
  "app-identity-suite-elixir.json".

  ## Usage

      mix app_identity #{@command} [options] [suite]

  ## Options for generate:

      --stdout         Prints the suite to standard output instead of saving it
      -q, --quiet      Silences diagnostic messages

  ## Global Options:

      -V, --version    Display the version number
      -h, --help       Display help
  """

  def command do
    @command
  end

  def help do
    @help_doc
  end

  @switches [
    aliases: [h: :help, q: :quiet, V: :version],
    strict: [help: :boolean, quiet: :boolean, stdout: :boolean, version: :boolean]
  ]

  @default_suite_name "app-identity-suite-elixir.json"

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
        generate(args, options)
    end
  end

  defp generate([], options) do
    generate(@default_suite_name, options)
  end

  defp generate([suite_name | _], options) do
    generate(suite_name, options)
  end

  defp generate(suite_name, options) do
    name = resolve_suite_name(suite_name)
    suite = generate_suite()
    shell = Mix.shell()

    if !options[:stdout] && !options[:quiet] do
      shell.info(
        "Generated #{length(suite[:tests])} tests for #{suite[:name]} #{suite[:version]}."
      )
    end

    if options[:stdout] do
      suite
      |> Jason.encode!(pretty: true)
      |> shell.info()
    else
      File.write!(name, Jason.encode!(suite))

      unless options[:quiet] do
        shell.info("Saved as #{name}")
      end
    end
  end

  defp resolve_suite_name(name) do
    if String.ends_with?(name, ".json") do
      name
    else
      if File.dir?(name) do
        Path.join(name, @default_suite_name)
      else
        "#{name}.json"
      end
    end
  end

  @priv_dir List.to_string(:code.priv_dir(:app_identity))

  @required_test_file Path.join(@priv_dir, "required.json")
  @optional_test_file Path.join(@priv_dir, "optional.json")

  @tests %{
    required: Jason.decode!(File.read!(@required_test_file)),
    optional: Jason.decode!(File.read!(@optional_test_file))
  }

  @external_resource @required_test_file
  @external_resource @optional_test_file

  defp generate_suite do
    %{
      name: AppIdentity.info(:name),
      version: AppIdentity.info(:version),
      spec_version: AppIdentity.info(:spec_version),
      tests: generate_tests(:required) ++ generate_tests(:optional)
    }
  end

  defp generate_tests(type) do
    @tests[type]
    |> Enum.with_index(1)
    |> Enum.map(&generate_test(type, &1))
  end

  defp generate_test(type, {input, index}) do
    normalized = normalize_test(type, input, index)

    {:ok, app} =
      if normalized[:app] do
        Support.make_app(
          get_in(normalized, [:app, :version]),
          get_in(normalized, [:app, :config, :fuzz])
        )
      else
        Support.make_app(1)
      end

    %{
      description: Map.fetch!(normalized, :description),
      expect: Map.fetch!(normalized, :expect),
      app: app,
      proof: make_proof(type, normalized, index, app),
      required: type == :required,
      spec_version: Map.fetch!(normalized, :spec_version)
    }
  end

  defp normalize_test(type, input, index) do
    must_have!(type, input, index, "description")
    must_have!(type, input, index, "expect")
    must_have!(type, input, index, "proof")
    must_have!(type, input, index, "spec_version")

    unless input["expect"] == "pass" || input["expect"] == "fail" do
      fail!(type, input, index, "Invalid expect value '#{input["expect"]}'")
    end

    %{
      description: input["description"],
      expect: input["expect"],
      spec_version: input["spec_version"]
    }
    |> normalize_app(input, type, index)
    |> normalize_nonce(input, type, index)
    |> normalize_padlock(input, type, index)
    |> normalize_proof(input, type, index)
  end

  defp normalize_app(output, %{"app" => app} = input, type, index) do
    must_have!(type, app, index, "version", input: input, name: "app.version")

    new_app = %{version: app["version"]}

    new_app =
      if Map.has_key?(app, "config") do
        must_have!(type, app["config"], index, "fuzz", input: input, name: "app.config.fuzz")
        Map.put_new(new_app, :config, %{fuzz: get_in(app, ["config", "fuzz"])})
      else
        new_app
      end

    Map.put_new(output, :app, new_app)
  end

  defp normalize_app(output, _input, _type, _index) do
    output
  end

  defp normalize_nonce(output, %{"nonce" => nonce} = input, type, index) do
    new_nonce =
      case nonce do
        %{"empty" => _, "offset_minutes" => _} ->
          fail!(type, input, index, "nonce must only have one sub-key")

        %{"empty" => _, "value" => _} ->
          fail!(type, input, index, "nonce must only have one sub-key")

        %{"offset_minutes" => _, "value" => _} ->
          fail!(type, input, index, "nonce must only have one sub-key")

        %{"empty" => value} ->
          %{empty: !!value}

        %{"offset_minutes" => value} when is_integer(value) ->
          %{offset_minutes: value}

        %{"offset_minutes" => _} ->
          fail!(type, input, index, "nonce.offset_minutes must be an integer")

        %{"value" => value} ->
          %{value: value}

        _ ->
          fail!(type, input, index, "nonce requires exactly one sub-key")
      end

    Map.put_new(output, :nonce, new_nonce)
  end

  defp normalize_nonce(output, _input, _type, _index) do
    output
  end

  defp normalize_padlock(output, %{"padlock" => padlock} = input, type, index) do
    must_have!(type, padlock, index, "nonce", input: input, name: "padlock.nonce")
    Map.put_new(output, :padlock, %{nonce: padlock["nonce"]})
  end

  defp normalize_padlock(output, _input, _type, _index) do
    output
  end

  defp normalize_proof(output, %{"proof" => proof} = input, type, index) do
    must_have!(type, proof, index, "version", input: input, name: "proof.version")

    new = %{version: proof["version"]}

    extra =
      case proof do
        %{"id" => id, "secret" => secret} -> %{id: id, secret: secret}
        %{"id" => id} -> %{id: id}
        %{"secret" => secret} -> %{secret: secret}
        _ -> %{}
      end

    Map.put_new(output, :proof, Map.merge(new, extra))
  end

  defp make_proof(type, input, index, app) do
    version =
      case AppIdentity.Validation.validate(:version, get_in(input, [:proof, :version])) do
        {:ok, value} -> value
        {:error, message} -> Mix.raise(message)
      end

    nonce =
      case input[:nonce] do
        %{empty: true} ->
          ""

        %{offset_minutes: value} ->
          Support.timestamp_nonce(value)

        %{value: value} ->
          value

        _ ->
          case AppIdentity.Versions.generate_nonce(version) do
            {:ok, value} -> value
            {:error, message} -> Mix.raise(message)
          end
      end

    {:ok, proof} = build_proof(app, nonce, version, input, type, index)

    proof
  end

  defp build_proof(
         app,
         nonce,
         version,
         %{padlock: %{nonce: padlock_nonce}, proof: proof},
         _type,
         _index
       ) do
    padlock =
      Support.build_padlock(app,
        id: proof[:id],
        nonce: padlock_nonce,
        secret: proof[:secret],
        version: version
      )

    {:ok,
     Support.build_proof(app, padlock,
       id: proof[:id],
       nonce: nonce,
       secret: proof[:secret],
       version: version
     )}
  end

  defp build_proof(app, nonce, version, %{proof: proof} = input, type, index) do
    if proof[:id] || proof[:secret] || input[:nonce] do
      padlock =
        Support.build_padlock(app,
          id: proof[:id],
          nonce: nonce,
          secret: proof[:secret],
          version: version
        )

      {:ok,
       Support.build_proof(app, padlock,
         id: proof[:id],
         nonce: nonce,
         secret: proof[:secret],
         version: version
       )}
    else
      AppIdentity.Internal.generate_proof(app, nonce: nonce, version: version)
    end
  rescue
    ex ->
      fail!(type, input, index, ex)
  end

  defp must_have!(type, input, index, key, options \\ []) do
    unless Map.has_key?(input, key) do
      fail!(type, options[:input] || input, index, "missing #{options[:name] || key}")
    end
  end

  @spec fail!(:required | :optional, term, integer, term) :: no_return
  defp fail!(type, input, index, message) do
    Mix.raise(
      "Error in #{type} item #{index}: #{AppIdentity.Suite.extract_message(message)}\n#{inspect(input)}"
    )
  end
end
