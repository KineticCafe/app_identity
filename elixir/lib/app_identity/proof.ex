defmodule AppIdentity.Proof do
  @proof_string_separator ":"

  @moduledoc """
  A structure describing a computed or parsed App Identity proof.
  """

  alias AppIdentity.{App, Validation, Versions}

  import Bitwise
  import Kernel, except: [to_string: 1]

  @enforce_keys [:version, :id, :nonce, :padlock]
  @derive {Inspect, except: [:padlock]}
  defstruct @enforce_keys

  @typedoc """
  The components of a parsed AppIdentity proof.
  """
  @type t :: %__MODULE__{
          id: AppIdentity.id(),
          nonce: AppIdentity.nonce(),
          padlock: String.t(),
          version: AppIdentity.version()
        }

  @doc """
  Build an `AppIdentity.Proof` struct from an `AppIdentity.App` struct and
  a nonce.

  This method returns the either `{:ok, proof}` or `{:error, reason}`

  ## Examples:

      iex> AppIdentity.Proof.build(
      ...>   AppIdentity.App.new!(%{
      ...>     id: "867-5309",
      ...>     secret: "Something unguessable",
      ...>     version: 1
      ...>   }),
      ...>   "a nonce"
      ...> )
      {:ok, %AppIdentity.Proof{
        id: "867-5309",
        nonce: "a nonce",
        version: 1,
        padlock: "57384B64BF69703296DF9E4C93DC83CF4B96EAF20298006897DFBC2A63904219"
      }}

      iex> AppIdentity.Proof.build(
      ...>   AppIdentity.App.new!(%{
      ...>     id: "123-456-789",
      ...>     secret: fn -> "Something unguessable" end,
      ...>     version: 2
      ...>   }),
      ...>   "",
      ...>   version: 3
      ...> )
      {:error, "nonce must not be an empty string"}
  """
  @spec build(app :: App.t(), nonce :: AppIdentity.nonce(), options :: [AppIdentity.option()]) ::
          {:ok, proof :: t} | {:error, reason :: String.t()}
  def build(%App{version: app_version} = app, nonce, options \\ []) do
    version = Keyword.get(options, :version) || app_version

    with :ok <- Versions.allowed_version(version, options),
         {:ok, padlock} <- generate_padlock(app, nonce, version) do
      {:ok, %__MODULE__{id: app.id, nonce: nonce, version: version, padlock: padlock}}
    end
  end

  # @doc """
  # Convert a base 64-encoded string into a `AppIdentity.Proof` struct.

  # The string is treated as a set of parts separated by the
  # `#{@proof_string_separator}` character.

  # A version 1 proof string consists of three parts:

  # 1. the application id,
  # 2. a nonce, and
  # 3. a padlock.

  # Version 2 and later proof strings consist of four parts:

  # 1. the version as decimal digits,
  # 2. the application id,
  # 3. a nonce,
  # 4. and a padlock.

  # ## Examples:

  #     iex> AppIdentity.Proof.from_string("2:123:a nonce:locked")
  #     {:ok, %AppIdentity.Proof{
  #       id: "123",
  #       nonce: "a nonce",
  #       padlock: "locked",
  #       version: 2
  #     }}

  #     iex> AppIdentity.Proof.from_string("An odd looking string")
  #     {:error, ~S(Can't make a Proof out of ["An odd looking string"])}
  # """

  @spec from_string(proof :: String.t()) :: {:ok, proof :: t} | {:error, reason :: String.t()}
  def from_string(candidate) when is_binary(candidate) do
    case Base.url_decode64(candidate, padding: false) do
      {:ok, proof_string} ->
        proof_string
        |> String.split(@proof_string_separator)
        |> parts_to_proof()

      :error ->
        {:error, "cannot decode proof string"}
    end
  end

  # @doc """
  # Convert a `AppIdentity.Proof` struct into an encoded string.

  # You can interpolate a `Kinetic.Application.Proof` struct into a string and get
  # the same result as using `Kinetic.Application.Proof.to_string/1`

  # ## Example:

  #     iex> proof = %AppIdentity.Proof{
  #     ...>   id: "123",
  #     ...>   nonce: "a nonce",
  #     ...>   padlock: "locked",
  #     ...>   version: 2
  #     ...> }
  #     ...> AppIdentity.Proof.to_string(proof)
  #     "2:123:a nonce:locked"
  # """
  @spec to_string(proof :: t) :: String.t()
  def to_string(%__MODULE__{version: 1} = proof) do
    [proof.id, proof.nonce, proof.padlock]
    |> Enum.join(@proof_string_separator)
    |> Base.url_encode64()
  end

  def to_string(%__MODULE__{} = proof) do
    [proof.version, proof.id, proof.nonce, proof.padlock]
    |> Enum.join(@proof_string_separator)
    |> Base.url_encode64()
  end

  # @doc """
  # Verify a `Proof`.

  ## Raises an exception if there is an error during proof verification. Returns
  ## the AppIdentity.App struct of `app` if it succeeds and `nil` if the
  ## comparison fails with no errors.
  ##
  ## `app` must be provided either as a resolved application or as an app finder
  ## function, which will receive the parsed AppIdentity.Proof struct so that the
  ## app can be loaded from an external source. The result of this block will be
  ## converted to an AppIdentity.App struct using AppIdentity.App.from/2.
  ##
  ## ```elixir
  ## AppIdentity.verify_proof(prood, app: fn %{id: id} ->
  ##   Applications.get!(proof[:id])
  ## end)
  ## ```
  # """
  @spec verify(proof :: t, app :: App.finder() | App.t(), options :: [AppIdentity.option()]) ::
          {:ok, app :: AppIdentity.App.t() | nil} | {:error, reason :: String.t()}
  def verify(proof, %App{} = app, options) do
    with :ok <- verify_same_app(proof.id, app.id),
         :ok <- verify_compatible_versions(proof.version, app.version),
         :ok <- Versions.allowed_version(proof.version, options),
         {:ok, _} <- Versions.validate_nonce(app, proof.nonce, proof.version),
         {:ok, _} <- Validation.validate(:padlock, proof.padlock),
         {:ok, padlock} <- generate_padlock(app, proof.nonce, proof.version) do
      if compare_padlocks(padlock, proof.padlock) do
        {:ok, %{app | verified: true}}
      else
        {:ok, nil}
      end
    end
  end

  def verify(proof, %{} = candidate, options) do
    case App.new(candidate) do
      {:ok, app} -> verify(proof, app, options)
      error -> error
    end
  end

  def verify(proof, finder, options) when is_function(finder, 1) do
    verify(proof, finder.(proof), options)
  end

  def verify(_proof, _app, _options) do
    {:error, "invalid app"}
  end

  defp generate_padlock(%{version: app_version}, _nonce, version) when app_version > version do
    {:error, "app version #{app_version} is not compatible with proof version #{version}"}
  end

  defp generate_padlock(app, nonce, version) do
    case Versions.validate_nonce(app, nonce, version) do
      {:ok, _} -> Versions.make_digest(app, nonce, version)
      error -> error
    end
  end

  defp parts_to_proof([id, nonce, padlock]) do
    with {:ok, id} <- Validation.validate(:id, id),
         {:ok, nonce} <- Validation.validate(:nonce, nonce),
         {:ok, padlock} <- Validation.validate(:padlock, padlock) do
      {:ok, %__MODULE__{version: 1, id: id, nonce: nonce, padlock: padlock}}
    end
  end

  defp parts_to_proof([version_string, id, nonce, padlock]) do
    with {:ok, version} <- Validation.validate(:version, version_string),
         {:ok, id} <- Validation.validate(:id, id),
         {:ok, nonce} <- Validation.validate(:nonce, nonce),
         {:ok, padlock} <- Validation.validate(:padlock, padlock) do
      {:ok, %__MODULE__{version: version, id: id, nonce: nonce, padlock: padlock}}
    end
  end

  defp parts_to_proof(_parts) do
    {:error, "proof must have 3 parts (version 1) or 4 parts (any version)"}
  end

  defp verify_same_app(id, id) do
    :ok
  end

  defp verify_same_app(_, _) do
    {:error, "proof and app do not match"}
  end

  defp verify_compatible_versions(proof_version, app_version) when app_version <= proof_version do
    :ok
  end

  defp verify_compatible_versions(_, _) do
    {:error, "proof and app version mismatch"}
  end

  @blank_padlock [nil, ""]

  # Adapted from Plug.Crypto
  defp compare_padlocks(left, right) when left in @blank_padlock or right in @blank_padlock do
    false
  end

  defp compare_padlocks(left, right) when is_binary(left) and is_binary(right) do
    byte_size(left) == byte_size(right) and compare_padlocks(left, right, 0)
  end

  defp compare_padlocks(<<x, left::binary>>, <<y, right::binary>>, acc) do
    xorred = bxor(x, y)
    compare_padlocks(left, right, acc ||| xorred)
  end

  defp compare_padlocks(<<>>, <<>>, acc) do
    acc === 0
  end
end
