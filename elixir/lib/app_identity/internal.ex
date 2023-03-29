defmodule AppIdentity.Internal do
  @moduledoc false

  alias AppIdentity.App
  alias AppIdentity.Proof
  alias AppIdentity.Versions

  import AppIdentity.Telemetry

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

  def generate_proof(%App{} = app, options) do
    {metadata, span_context} =
      start_span(:generate_proof, %{app: telemetry_app(app), options: options})

    __generate_proof(app, options, metadata, span_context)
  end

  def generate_proof(app, options) do
    {metadata, span_context} =
      start_span(:generate_proof, %{app: telemetry_app(app), options: options})

    case App.new(app) do
      {:ok, app} ->
        __generate_proof(app, options, Map.put(metadata, :app, app), span_context)

      {:error, error} ->
        stop_span(span_context, Map.put(metadata, :error, error))

        {:error, error}
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
    {metadata, span_context} =
      start_span(:verify_proof, %{proof: proof, app: telemetry_app(app), options: options})

    __verify_proof(proof, app, options, metadata, span_context)
  end

  def verify_proof(candidate, app, options) when is_binary(candidate) do
    {metadata, span_context} =
      start_span(:verify_proof, %{candidate: candidate, app: telemetry_app(app), options: options})

    case Proof.from_string(candidate) do
      {:ok, proof} ->
        metadata =
          metadata
          |> Map.delete(:candidate)
          |> Map.put(:proof, proof)

        __verify_proof(proof, app, options, metadata, span_context)

      {:error, error} ->
        stop_span(span_context, Map.put(metadata, :error, error))

        {:error, error}
    end
  end

  defp resolve_nonce(version, options) do
    case Keyword.fetch(options, :nonce) do
      {:ok, _} = ok -> ok
      :error -> Versions.generate_nonce(version)
    end
  end

  defp __generate_proof(%App{version: app_version} = app, options, metadata, span_context) do
    options = Keyword.put_new(options, :version, app_version)

    result =
      with {:ok, nonce} <- resolve_nonce(options[:version], options),
           {:ok, proof} <- Proof.build(app, nonce, options) do
        {:ok, Proof.to_string(proof)}
      end

    metadata =
      case result do
        {:ok, proof} -> Map.put(metadata, :proof, proof)
        {:error, error} -> Map.put(metadata, :error, error)
      end

    stop_span(span_context, metadata)

    result
  end

  defp __verify_proof(%Proof{} = proof, app, options, metadata, span_context) do
    result = Proof.verify(proof, app, options)

    metadata =
      case result do
        {:ok, app} -> Map.put(metadata, :app, telemetry_app(app))
        {:error, error} -> Map.put(metadata, :error, error)
      end

    stop_span(span_context, metadata)

    result
  end
end
