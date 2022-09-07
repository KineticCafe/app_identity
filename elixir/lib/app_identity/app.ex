defmodule AppIdentity.App do
  @moduledoc """
  The structure used by the App Identity proof generation and verification
  algorithms. This should be constructed from a provided map or struct, such as
  a static configuration file or a database record.

  The original structure or map is stored in the `source` attribute.
  """

  import AppIdentity.Validation, only: [validate: 2]

  @typedoc """
  An optional configuration value for validation of an `AppIdentity` proof.

  If not provided, the default value when required is `{fuzz: 600}`, specifying
  that the timestamp may not differ from the current time by more than ±600
  seconds (±10 minutes). Depending on the nature of the app being verified and
  the expected network conditions, a shorter time period than 600 seconds is
  recommended.

  The `AppIdentity` version 1 algorithm does not use `config`.
  """
  @type config ::
          nil
          | %{optional(:fuzz) => pos_integer(), optional(atom()) => term}
          | %{optional(String.t()) => term}

  @typedoc """
  A map struct that can be converted into an App struct. If the map uses string
  keys, they are required to match the same definitions.
  """
  @type input ::
          %{
            required(:id) => term,
            required(:secret) => term,
            required(:version) => term,
            optional(:config) => term,
            optional(atom) => term
          }
          | %{required(binary()) => term}

  @typedoc """
  A 0-arity loader function that returns a map or struct that can be converted
  into an App struct.
  """
  @type loader :: (() -> input | t)

  @typedoc """
  A finder function accepting a Proof struct parameter that returns a map or
  struct that can be converted into an App struct.
  """
  @type finder :: (AppIdentity.Proof.t() -> input | t)

  @typedoc """
  A representation of an AppIdentity app used for proof generation and
  verification.

  The `t:input/0` value used in the construction of the App is stored in
  `source`.

  The `verified` flag value indicates whether the app was used in the successful
  verification of a proof.
  """
  @type t :: %__MODULE__{
          id: AppIdentity.id(),
          secret: (() -> AppIdentity.secret()),
          version: AppIdentity.version(),
          config: config(),
          source: nil | term(),
          verified: boolean()
        }

  @derive {Inspect, only: [:config, :id, :verified, :version]}

  @enforce_keys [:id, :secret, :version]
  defstruct [:id, :secret, :version, config: nil, source: nil, verified: false]

  @doc """
  Converts the provided `t:input/0` value into an App struct (`t:t/0`). May be
  provided a `t:loader/0` function that will return an `t:input/0` value for
  validation and conversion.

  If provided an App struct (`t:t/0`), returns the provided app struct without
  validation.

  The result is `{:ok, app}` or `{:error, reason}`.

  ### Examples

      iex> App.new(%{})
      {:error, "id must not be nil"} = App.new(%{id: nil})

      iex> {:ok, app} = App.new(%{id: 1, secret: "secret", version: 1})
      iex> app.source
      %{id: 1, secret: "secret", version: 1}
      iex> app.secret.()
      "secret"

      iex> {:ok, app} = App.new(%{id: 1, secret: "secret", version: 1})
      iex> {:ok, app_copy} = App.new(app)
      iex> app == app_copy
      true
  """
  @spec new(input :: input | loader | t) ::
          {:ok, app :: t} | {:error, reason :: String.t()}
  def new(%__MODULE__{} = app) do
    {:ok, app}
  end

  def new(input) when is_function(input, 0) do
    new(input.())
  end

  def new(input) when is_map(input) do
    with {:ok, id} <- get(input, :id),
         {:ok, secret} <- get(input, :secret),
         {:ok, version} <- get(input, :version),
         {:ok, config} <- get(input, :config) do
      secret =
        if is_function(secret, 0) do
          secret
        else
          fn -> secret end
        end

      {:ok,
       %__MODULE__{
         id: id,
         secret: secret,
         version: version,
         config: config,
         source: input
       }}
    end
  end

  def new(_input) do
    {:error, "app can only be created from a map or struct"}
  end

  @doc false
  @spec new!(input :: input | loader | t) :: t
  def new!(input) do
    case new(input) do
      {:ok, value} -> value
      {:error, reason} -> raise reason
    end
  end

  @doc false
  @spec __to_map(app :: t) :: map
  def __to_map(%__MODULE__{} = app) do
    app
    |> Map.take([:config, :id, :version])
    |> Map.put(:secret, app.secret.())
  end

  defp get(map, key) do
    validate(key, Map.get(map, key) || Map.get(map, to_string(key)))
  end
end
