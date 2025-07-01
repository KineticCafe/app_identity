defmodule AppIdentity.Case do
  @moduledoc """
  App Identity test cases.
  """

  use ExUnit.CaseTemplate

  import AppIdentity.Support

  using do
    quote do
      import AppIdentity.Case
      import AppIdentity.Support
    end
  end

  def setup_context(context) do
    {:ok, _} = Application.ensure_all_started(:telemetry)
    name = to_string(context.test)

    :ok = AppIdentity.TelemetryHandler.attach(name)
    on_exit(fn -> :telemetry.detach(name) end)

    v1 = v1()
    v2 = v2()
    v3 = v3()
    v4 = v4()

    %{
      1 => v1,
      2 => v2,
      3 => v3,
      4 => v4,
      :v1 => v1,
      :v1_app => elem(AppIdentity.App.new(v1), 1),
      :v2 => v2,
      :v2_app => elem(AppIdentity.App.new(v2), 1),
      :v3 => v3,
      :v3_app => elem(AppIdentity.App.new(v3), 1),
      :v4 => v4,
      :v4_app => elem(AppIdentity.App.new(v4), 1)
    }
  end

  setup :setup_context

  def assert_error_reason(reason, fun) do
    assert_raise AppIdentity.AppIdentityError, reason, fun
  end

  def assert_generate_proof_telemetry_span(%{id: id}, options \\ []) do
    assert_received {:event, [:app_identity, :generate_proof, :start], %{system_time: _}, %{app: %{id: ^id}}}

    case {Keyword.get(options, :proof), Keyword.get(options, :error)} do
      {nil, nil} ->
        assert_received {:event, [:app_identity, :generate_proof, :stop], %{duration: _}, %{app: %{id: ^id}}}

      {proof, nil} ->
        assert_received {:event, [:app_identity, :generate_proof, :stop], %{duration: _},
                         %{app: %{id: ^id}, proof: ^proof}}

      {nil, error} ->
        assert_received {:event, [:app_identity, :generate_proof, :stop], %{duration: _},
                         %{app: %{id: ^id}, error: ^error}}
    end
  end

  def assert_verify_proof_telemetry_span(%{id: id}, candidate, options \\ []) do
    assert_received {:event, [:app_identity, :verify_proof, :start], %{system_time: _},
                     %{app: %{id: ^id}, candidate: ^candidate}}

    case {Keyword.get(options, :app), Keyword.get(options, :error)} do
      {nil, nil} ->
        {:ok, proof} = AppIdentity.Proof.from_string(candidate)

        assert_received {:event, [:app_identity, :verify_proof, :stop], %{duration: _},
                         %{app: %{id: ^id, verified: true}, proof: ^proof}}

      {:none, nil} ->
        {:ok, proof} = AppIdentity.Proof.from_string(candidate)

        assert_received {:event, [:app_identity, :verify_proof, :stop], %{duration: _}, %{app: nil, proof: ^proof}}

      {nil, error} ->
        assert_received {:event, [:app_identity, :verify_proof, :stop], %{duration: _},
                         %{app: %{id: ^id}, error: ^error}}
    end
  end
end
