defmodule AppIdentity.Internal do
  @moduledoc false

  alias AppIdentity.{App, Proof, Versions}

  @doc """
  Generate an App Identity proof string or return an error with a reason. This
  is for internal use only.

  Unit tests for `AppIdentity.generate_proof/2` are written with this function
  so we can verify test failures for specific reasons.
  """
  @spec generate_proof(
          app :: App.input() | App.loader() | App.t(),
          options :: [AppIdentity.option()]
        ) ::
          {:ok, proof :: String.t()} | {:error, reason :: String.t()}
  def generate_proof(app, options \\ [])

  def generate_proof(%App{version: app_version} = app, options) do
    options = Keyword.put_new(options, :version, app_version)

    with {:ok, nonce} <- resolve_nonce(options[:version], options),
         {:ok, proof} <- Proof.build(app, nonce, options) do
      {:ok, Proof.to_string(proof)}
    end
  end

  def generate_proof(app, options) do
    case App.new(app) do
      {:ok, app} -> generate_proof(app, options)
      error -> error
    end
  end

  # See AppIdentity.parse_proof/1 for details. This version returns `{:ok,
  # proof}` or `{:error, reason}`.
  @spec parse_proof(proof :: Proof.t() | String.t()) ::
          {:ok, proof :: Proof.t()} | {:error, reason :: String.t()}
  def parse_proof(%Proof{} = proof) do
    {:ok, proof}
  end

  def parse_proof(candidate) when is_binary(candidate) do
    Proof.from_string(candidate)
  end

  # See AppIdentity.verify_proof/3 for details. This version returns `{:ok,
  # proof}` or `{:error, reason}`.
  @spec verify_proof(
          proof :: Proof.t() | String.t(),
          app :: App.finder() | App.input() | App.t(),
          options :: [AppIdentity.option()]
        ) :: {:ok, app :: App.t() | nil} | {:error, reason :: String.t()}
  def verify_proof(proof, app, options \\ [])

  def verify_proof(%Proof{} = proof, app, options) do
    Proof.verify(proof, app, options)
  end

  def verify_proof(candidate, app, options) when is_binary(candidate) do
    case Proof.from_string(candidate) do
      {:ok, proof} -> verify_proof(proof, app, options)
      error -> error
    end
  end

  defp resolve_nonce(version, options) do
    case Keyword.fetch(options, :nonce) do
      {:ok, _} = ok -> ok
      :error -> Versions.generate_nonce(version)
    end
  end
end
