defmodule AppIdentity.PlugCase do
  @moduledoc """
  App Identity Plug test cases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import AppIdentity.Case
      import AppIdentity.PlugCase
      import AppIdentity.Support
    end
  end

  setup context do
    {:ok, _} = Application.ensure_all_started(:plug)
    AppIdentity.Case.setup_context(context)
  end

  def assert_plug_telemetry_span(status, options \\ []) do
    clients =
      options
      |> Keyword.get(:clients, [])
      |> List.wrap()

    for app <- clients, do: AppIdentity.Case.assert_generate_proof_telemetry_span(app)

    assert_received {:event, [:app_identity, :plug, :start], %{system_time: _},
                     %{conn: _, options: _}}

    if apps = Keyword.get(options, :apps) do
      name = Keyword.get(options, :name, :app_identity)

      assert_received {:event, [:app_identity, :plug, :stop], %{duration: _},
                       %{conn: %{status: ^status, private: %{^name => ^apps}}, options: _}}
    else
      assert_received {:event, [:app_identity, :plug, :stop], %{duration: _},
                       %{conn: %{status: ^status}, options: _}}
    end

    assert_received {_ref, {^status, _headers, _body}}
  end
end
