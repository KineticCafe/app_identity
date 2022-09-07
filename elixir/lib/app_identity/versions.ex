defmodule AppIdentity.Versions do
  @moduledoc false

  @proof_string_separator ":"

  alias AppIdentity.{App, Validation}

  @version_map %{
    1 => AppIdentity.Versions.V1,
    2 => AppIdentity.Versions.V2,
    3 => AppIdentity.Versions.V3,
    4 => AppIdentity.Versions.V4
  }
  @supported_versions Map.keys(@version_map)

  @doc """
  Returns the algorithm module that matches the provided `version`. Returns
  `{:ok, module}` or `{:error, reason}`.

      iex> AppIdentity.Versions.version(1)
      {:ok, AppIdentity.Versions.V1}

      iex> AppIdentity.Versions.version(5)
      {:error, "unsupported version 5"}
  """
  @spec version(AppIdentity.version()) :: {:ok, module()} | {:error, reason :: String.t()}
  def version(version) do
    case Map.fetch(@version_map, version) do
      {:ok, _} = ok -> ok
      :error -> {:error, "unsupported version #{inspect(version)}"}
    end
  end

  @doc "The list of supported algorithm version numbers."
  @spec supported :: [AppIdentity.version()]
  def supported do
    @supported_versions
  end

  @doc "Generates a nonce appropriate to the provided algorithm version."
  @spec generate_nonce(version :: App.t() | AppIdentity.version()) ::
          {:ok, AppIdentity.nonce()} | {:error, reason :: String.t()}
  def generate_nonce(%{version: app_version}) do
    generate_nonce(app_version)
  end

  def generate_nonce(version) when is_integer(version) do
    case version(version) do
      {:ok, mod} -> mod.generate_nonce()
      error -> error
    end
  end

  @doc "Validates a nonce appropriate to the provided algorithm version."
  @spec validate_nonce(App.t(), AppIdentity.nonce(), AppIdentity.version()) ::
          {:ok, AppIdentity.nonce()} | {:error, reason :: String.t()}
  def validate_nonce(%{config: config}, nonce, version) do
    case version(version) do
      {:ok, mod} -> mod.validate_nonce(nonce, config)
      error -> error
    end
  end

  @doc """
  Creates a digest value for use in a padlock according to the provided algorithm version.
  """
  @spec make_digest(App.t(), AppIdentity.nonce(), AppIdentity.version()) ::
          {:ok, digest :: String.t()} | {:error, reason :: String.t()}
  def make_digest(%{id: id, secret: secret}, nonce, version) do
    case version(version) do
      {:ok, mod} ->
        digest =
          [id, nonce, secret.()]
          |> join()
          |> mod.make_digest()
          |> Base.encode16(case: :upper)

        {:ok, digest}

      error ->
        error
    end
  end

  @doc """
  Tests if the version provided is both supported and has not been explicitly
  disallowed.

  ## Examples

      iex> AppIdentity.Versions.allowed_version(1)
      :ok

      iex> AppIdentity.Versions.allowed_version(1, disallowed: [1])
      {:error, "version 1 has been disallowed"}

      iex> AppIdentity.Versions.allowed_version(5)
      {:error, "unsupported version 5"}

      iex> AppIdentity.Versions.allowed_version(1, disallowed: 5)
      {:error, "error in disallowed version configuration"}
  """
  @spec allowed_version(AppIdentity.version(), [AppIdentity.option()]) ::
          :ok | {:error, reason :: String.t()}
  def allowed_version(version, options \\ [])

  def allowed_version(version, options) when version in @supported_versions do
    case Keyword.get(options, :disallowed) do
      nil ->
        :ok

      [] ->
        :ok

      disallowed when is_list(disallowed) ->
        if version in disallowed do
          {:error, "version #{version} has been disallowed"}
        else
          :ok
        end

      _ ->
        {:error, "error in disallowed version configuration"}
    end
  end

  def allowed_version(version, _options) do
    {:error, "unsupported version #{inspect(version)}"}
  end

  defp join(parts, separator \\ @proof_string_separator) when is_list(parts) do
    parts
    |> Enum.intersperse(separator)
    |> IO.iodata_to_binary()
  end

  defmodule RandomNonce do
    # Generate and validate a randomly generated nonce.
    @moduledoc false

    def generate_nonce do
      {:ok, Base.url_encode64(:crypto.strong_rand_bytes(32))}
    end

    def validate_nonce(nonce, _config) do
      Validation.validate(:nonce, nonce)
    end
  end

  defmodule TimestampNonce do
    # Generate and validate a timestamp nonce.
    @moduledoc false

    def generate_nonce do
      case DateTime.now("Etc/UTC") do
        {:ok, stamp} ->
          {:ok, DateTime.to_iso8601(stamp, :basic)}

        {:error, reason} ->
          {:error, String.replace(Kernel.to_string(reason), "_", " ")}
      end
    end

    def validate_nonce(nonce, config) do
      case Validation.validate(:nonce, nonce) do
        {:ok, nonce} -> parse_and_validate_nonce(nonce, config)
        error -> error
      end
    end

    @default_config %{fuzz: 600}

    defp parse_and_validate_nonce(nonce, config) do
      with {:ok, timestamp} <- parse_timestamp(nonce),
           {:ok, now} <- DateTime.now("Etc/UTC") do
        compare_timestamp(now, timestamp, nonce, config)
      end
    end

    defp compare_timestamp(now, timestamp, nonce, config) do
      config = config || @default_config
      fuzz = Map.get(config, :fuzz) || Map.get(config, "fuzz") || 600
      diff = abs(DateTime.diff(now, timestamp))

      if diff <= fuzz do
        {:ok, nonce}
      else
        {:error, "nonce is invalid"}
      end
    end

    defp parse_timestamp(<<
           year::binary-size(4),
           month::binary-size(2),
           day::binary-size(2),
           "T",
           hour::binary-size(2),
           minute::binary-size(2),
           second::binary-size(2),
           rest::binary
         >>) do
      case DateTime.from_iso8601("#{year}-#{month}-#{day}T#{hour}:#{minute}:#{second}#{rest}") do
        {:ok, timestamp, _offset} -> {:ok, timestamp}
        {:error, reason} -> {:error, String.replace(Kernel.to_string(reason), "_", " ")}
      end
    end

    defp parse_timestamp(_) do
      {:error, "nonce does not look like a timestamp"}
    end
  end

  defmodule V1 do
    @moduledoc false

    defdelegate generate_nonce, to: RandomNonce
    defdelegate validate_nonce(nonce, config), to: RandomNonce

    def make_digest(raw) do
      :crypto.hash(:sha256, raw)
    end
  end

  defmodule V2 do
    @moduledoc false

    defdelegate generate_nonce, to: TimestampNonce
    defdelegate validate_nonce(nonce, config), to: TimestampNonce

    def make_digest(raw) do
      :crypto.hash(:sha256, raw)
    end
  end

  defmodule V3 do
    @moduledoc false

    defdelegate generate_nonce, to: TimestampNonce
    defdelegate validate_nonce(nonce, config), to: TimestampNonce

    def make_digest(raw) do
      :crypto.hash(:sha384, raw)
    end
  end

  defmodule V4 do
    @moduledoc false

    defdelegate generate_nonce, to: TimestampNonce
    defdelegate validate_nonce(nonce, config), to: TimestampNonce

    def make_digest(raw) do
      :crypto.hash(:sha512, raw)
    end
  end
end
