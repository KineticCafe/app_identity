defmodule AppIdentity.PlugCallbacks do
  @moduledoc """
  This utility module is used during Config tests to centralize and simplify
  Plug callback testing.
  """

  def init(options \\ []) do
    for {name, value} <- options do
      Process.put(name, value)
    end
  end

  # `finder` implementations.
  def finder(proof) do
    :context
    |> Process.get()
    |> Map.values()
    |> Enum.filter(&match?(%AppIdentity.App{}, &1))
    |> Enum.find(fn %{id: id} -> id == proof.id end)
  end

  # `on_failure` implementations
  def on_failure(_conn), do: Process.get(:on_failure)

  def forbidden(_conn), do: :forbidden

  def halt_401(_conn), do: {:halt, 401}

  def halt_teapot(_conn), do: {:halt, 418, "Teapot"}

  def continue(_conn), do: :continue

  # `on_success` implementation

  def on_success(conn) do
    Plug.Conn.put_private(conn, :on_success, %{
      errors?: has_errors?(conn, Process.get(:name))
    })
  end

  # `on_resolution` implementation
  def on_resolution(conn) do
    Plug.Conn.put_private(conn, :on_resolution, %{
      errors?: has_errors?(conn, Process.get(:name))
    })
  end

  defp has_errors?(conn, name) do
    results = conn.private[name || :app_identity]

    Enum.empty?(results) ||
      Enum.any?(results, fn
        {_, nil} -> true
        {_, []} -> true
        {_, values} -> Enum.any?(values, &(match?(nil, &1) || match?(%{verified: false}, &1)))
      end)
  end
end
