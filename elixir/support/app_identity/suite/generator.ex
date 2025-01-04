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
      IO.write(:stdio, Jason.encode!(suite, pretty: true))
      :timer.sleep(1000)
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

  @file_path Path.dirname(__ENV__.file)
  @required_file Path.join(@file_path, "required.json")
  @optional_file Path.join(@file_path, "optional.json")

  @tests %{
    required: Jason.decode!(File.read!(@required_file)),
    optional: Jason.decode!(File.read!(@optional_file))
  }

  @external_resource @required_file
  @external_resource @optional_file

  defp generate_suite do
    name = AppIdentity.info(:name)
    spec_version = AppIdentity.info(:spec_version)
    version = AppIdentity.info(:version)
    description = "#{name} #{version} (spec #{spec_version})"

    %{
      name: name,
      version: version,
      spec_version: spec_version,
      description: description,
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
      case resolve_normalized_nonce(nonce) do
        {:ok, new_nonce} -> new_nonce
        {:error, reason} -> fail!(type, input, index, reason)
      end

    Map.put_new(output, :nonce, new_nonce)
  end

  defp normalize_nonce(output, _input, _type, _index) do
    output
  end

  defp normalize_padlock(output, %{"padlock" => %{"value" => _} = padlock} = input, type, index) do
    cond do
      map_size(padlock) > 1 ->
        fail!(type, input, index, "padlock.value must not have any other sub-keys specified")

      padlock["value"] == "" ->
        fail!(type, input, index, "padlock.value must not be an empty string")

      true ->
        Map.put_new(output, :padlock, %{value: padlock["value"]})
    end
  end

  defp normalize_padlock(output, %{"padlock" => %{} = padlock} = input, type, index) do
    if map_size(padlock) == 0 do
      fail!(type, input, index, "padlock must have at least one sub-key: value, nonce, or case")
    else
      new =
        case padlock do
          %{"nonce" => _, "case" => _} ->
            %{
              nonce: padlock["nonce"],
              case: normalize_padlock_case(padlock["case"], type, input, index)
            }

          %{"nonce" => _} ->
            %{nonce: padlock["nonce"]}

          %{"case" => _} ->
            %{case: normalize_padlock_case(padlock["case"], type, input, index)}

          _ ->
            fail!(
              type,
              input,
              index,
              "padlock must have at least one sub-key: value, nonce, or case"
            )
        end

      if new[:case] not in [nil, :lower, :random, :upper] do
        fail!(type, input, index, "padlock.case must be one of 'lower', 'random', or 'upper'")
      end

      Map.put_new(output, :padlock, new)
    end
  end

  defp normalize_padlock(output, _input, _type, _index) do
    output
  end

  defp normalize_padlock_case("lower", _type, _input, _index), do: :lower
  defp normalize_padlock_case(:lower, _type, _input, _index), do: :lower
  defp normalize_padlock_case("random", _type, _input, _index), do: :random
  defp normalize_padlock_case(:random, _type, _input, _index), do: :random
  defp normalize_padlock_case("upper", _type, _input, _index), do: :upper
  defp normalize_padlock_case(:upper, _type, _input, _index), do: :upper

  defp normalize_padlock_case(_, type, input, index),
    do: fail!(type, input, index, "padlock.case must be one of 'lower', 'random', or 'upper'")

  defp normalize_proof(output, %{"proof" => proof} = input, type, index) do
    must_have!(type, proof, index, "version", input: input, name: "proof.version")

    new_proof =
      [version: proof["version"], id: proof["id"], secret: proof["secret"]]
      |> Enum.reject(&match?({_, nil}, &1))
      |> Map.new()

    Map.put_new(output, :proof, new_proof)
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
         %{padlock: %{value: padlock_value}, proof: proof},
         _type,
         _index
       ) do
    {:ok,
     Support.build_proof(app, padlock_value,
       id: proof[:id],
       nonce: nonce,
       secret: proof[:secret],
       version: version
     )}
  end

  defp build_proof(
         app,
         nonce,
         version,
         %{padlock: %{nonce: padlock_nonce} = padlock, proof: proof},
         _type,
         _index
       ) do
    padlock =
      Support.build_padlock(app,
        id: proof[:id],
        nonce: padlock_nonce,
        secret: proof[:secret],
        version: version,
        case: Map.get(padlock, :case, :random)
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
          version: version,
          case: get_in(input, [:padlock, :case]) || :random
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

  @spec fail!(term(), term(), term(), term()) :: no_return()
  defp fail!(type, input, index, message) do
    Mix.raise(
      "Error in #{type} item #{index}: #{AppIdentity.Suite.extract_message(message)}\n#{inspect(input)}"
    )
  end

  defp resolve_normalized_nonce(%{} = nonce) when map_size(nonce) > 1,
    do: {:error, "nonce must only have one sub-key"}

  defp resolve_normalized_nonce(%{"empty" => empty}) when empty in [true, "true"],
    do: {:ok, %{empty: true}}

  defp resolve_normalized_nonce(%{"empty" => _}), do: {:error, "nonce.empty may only be true"}

  defp resolve_normalized_nonce(%{"offset_minutes" => value}) when is_integer(value),
    do: {:ok, %{offset_minutes: value}}

  defp resolve_normalized_nonce(%{"offset_minutes" => _}),
    do: {:error, "nonce.offset_minutes must be an integer"}

  defp resolve_normalized_nonce(%{"value" => value}), do: {:ok, %{value: value}}

  defp resolve_normalized_nonce(_), do: {:error, "nonce requires exactly one sub-key"}
end
