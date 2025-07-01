defmodule AppIdentity.Plug.Config do
  @moduledoc """
  AppIdentity.Plug configuration struct builder and telemetry transformer.
  """

  alias AppIdentity.App
  alias AppIdentity.AppIdentityError
  alias Plug.Conn.Status

  @typedoc """
  AppIdentity.Plug configuration options prior to validation.
  """
  @type param ::
          AppIdentity.disallowed()
          | {:headers, list(String.t())}
          | {:header_groups, %{required(binary()) => list(String.t())}}
          | {:apps, list(App.input() | App.t())}
          | {:finder, App.finder()}
          | {:name, atom}
          | {:on_failure, on_failure | on_failure_callback}
          | {:on_success, conn_callback}
          | {:on_resolution, conn_callback}

  @type on_failure ::
          :forbidden
          | :continue
          | {:halt, Plug.Conn.status()}
          | {:halt, Plug.Conn.status(), Plug.Conn.body()}

  @typedoc """
  A callback for `on_failure` configuration. It must return a normal
  `on_failure` value.
  """
  @type on_failure_callback :: (Plug.Conn.t() -> on_failure) | {module(), function :: atom()}

  @typedoc """
  A callback for either `on_success` or `on_resolution` which accepts and
  optionally transforms the request `conn`.
  """
  @type conn_callback :: (Plug.Conn.t() -> Plug.Conn.t()) | {module(), function :: atom()}

  @typedoc """
  The internal representation of a callback function.
  """
  @type callback(t) :: {:fn, t}

  @typedoc """
  Normalized Configuration for AppIdentity.Plug.
  """
  @type t :: %__MODULE__{
          apps: %{optional(AppIdentity.id()) => App.t()},
          finder: nil | {:fn, App.finder() | {module, function :: atom()}},
          headers: nil | list(String.t()),
          header_groups: nil | %{required(binary()) => String.t()},
          on_failure: on_failure | callback(on_failure_callback),
          on_success: nil | callback(conn_callback),
          on_resolution: nil | callback(conn_callback),
          name: atom(),
          disallowed: list(AppIdentity.version())
        }

  defstruct apps: %{},
            finder: nil,
            headers: nil,
            header_groups: nil,
            on_failure: :forbidden,
            on_success: nil,
            on_resolution: nil,
            disallowed: [],
            name: :app_identity

  @doc "Create and validate the configuration struct from input parameters."
  @spec new!([param]) :: t
  def new!(params) do
    if !Keyword.has_key?(params, :apps) && !Keyword.has_key?(params, :finder) do
      raise AppIdentityError, :plug_missing_apps_or_finder
    end

    apps = get_apps(params)
    finder = get_finder(params)

    if Enum.empty?(apps) && is_nil(finder) do
      raise AppIdentityError, :plug_missing_apps_or_finder
    end

    if !Keyword.has_key?(params, :headers) && !Keyword.has_key?(params, :header_groups) do
      raise AppIdentityError, :plug_headers_required
    end

    if Keyword.has_key?(params, :headers) && Keyword.has_key?(params, :header_groups) do
      raise AppIdentityError, :plug_excess_headers
    end

    %__MODULE__{
      apps: apps,
      finder: finder,
      disallowed: get_disallowed(params),
      headers: get_headers(params),
      header_groups: get_header_groups(params),
      name: get_name(params),
      on_failure: get_on_failure(params),
      on_success: get_on_success(params),
      on_resolution: get_on_resolution(params)
    }
  end

  @doc """
  Returns the plug configuration as data for Telemetry context consumption.
  """
  @spec telemetry_context(t) :: map()
  def telemetry_context(%__MODULE__{} = config) do
    apps =
      config.apps
      |> Map.values()
      |> Enum.sort_by(& &1.id)
      |> AppIdentity.Telemetry.telemetry_apps()

    on_failure = callback_telemetry_context(config.on_failure)
    on_success = callback_telemetry_context(config.on_success)
    on_resolution = callback_telemetry_context(config.on_resolution)

    [
      {:apps, apps},
      {:name, config.name},
      {:finder, callback_telemetry_context(config.finder)},
      {:headers, config.headers},
      {:header_groups, config.header_groups},
      {:on_failure, on_failure},
      {:on_success, on_success},
      {:on_resolution, on_resolution},
      {:disallowed, config.disallowed}
    ]
    |> Enum.reject(&match?({_, nil}, &1))
    |> Map.new()
  end

  defp get_apps(options) do
    options
    |> Keyword.get(:apps, [])
    |> Enum.reduce(%{}, fn input, map ->
      {id, app} = parse_option_app(input)
      Map.put_new(map, id, app)
    end)
  end

  defp get_finder(options) do
    case Keyword.get(options, :finder, nil) do
      nil ->
        nil

      function when is_function(function, 1) ->
        {:fn, function}

      {module, function} when is_atom(module) and is_atom(function) ->
        if function_exported?(module, function, 1) do
          {:fn, {module, function}}
        else
          raise AppIdentityError, :plug_finder_invalid
        end

      _ ->
        raise AppIdentityError, :plug_finder_invalid
    end
  end

  defp get_disallowed(options) do
    case Keyword.get(options, :disallowed) do
      nil ->
        []

      list when is_list(list) ->
        if Enum.all?(list, &(&1 in AppIdentity.Versions.supported())) do
          list
        else
          raise AppIdentityError, :plug_disallowed_invalid
        end

      _ ->
        raise AppIdentityError, :plug_disallowed_invalid
    end
  end

  defp get_name(options) do
    case Keyword.get(options, :name, :app_identity) do
      value when is_atom(value) -> value
      _ -> raise AppIdentityError, :plug_name_invalid
    end
  end

  defp get_headers(options) do
    case Keyword.get(options, :headers) do
      nil ->
        nil

      [] ->
        raise AppIdentityError, :plug_header_invalid

      headers when not is_list(headers) ->
        raise AppIdentityError, :plug_header_invalid

      headers ->
        if duplicate_headers?(headers) do
          raise AppIdentityError, :plug_header_invalid
        end

        Enum.map(headers, &parse_option_header/1)
    end
  end

  defp get_header_groups(options) do
    case Keyword.get(options, :header_groups) do
      nil ->
        nil

      groups when not is_map(groups) ->
        raise AppIdentityError, :plug_header_groups_invalid

      groups ->
        if Enum.empty?(groups) do
          raise AppIdentityError, :plug_header_groups_invalid
        end

        invalid_names? =
          groups
          |> Map.keys()
          |> Enum.any?(fn v -> !is_binary(v) end)

        empty_groups? = Enum.any?(groups, &match?({_, []}, &1))

        if invalid_names? || empty_groups? || duplicate_headers?(Map.values(groups)) do
          raise AppIdentityError, :plug_header_groups_invalid
        end

        Map.new(groups, fn {name, headers} ->
          {name, Enum.map(headers, &parse_option_header(&1, :plug_header_groups_invalid))}
        end)
    end
  end

  defp duplicate_headers?(headers) do
    headers
    |> List.flatten()
    |> Enum.frequencies()
    |> Enum.any?(fn {_header, count} -> count > 1 end)
  end

  defp get_on_failure(options) do
    options
    |> Keyword.get(:on_failure)
    |> resolve_on_failure_option()
  end

  defp resolve_on_failure_option(value) when value in [:forbidden, :continue, nil], do: value || :forbidden

  defp resolve_on_failure_option(value) when is_function(value, 1), do: {:fn, value}

  defp resolve_on_failure_option(value) when is_function(value),
    do: raise(AppIdentityError, :plug_on_failure_callback_invalid)

  defp resolve_on_failure_option({:halt, status} = value) when is_integer(status) or is_atom(status) do
    if status_valid?(status) do
      value
    else
      raise AppIdentityError, :plug_on_failure_invalid
    end
  end

  defp resolve_on_failure_option({:halt, status, _body} = value) when is_integer(status) or is_atom(status) do
    if status_valid?(status) do
      value
    else
      raise AppIdentityError, :plug_on_failure_invalid
    end
  end

  defp resolve_on_failure_option({:halt, _status}) do
    raise AppIdentityError, :plug_on_failure_invalid
  end

  defp resolve_on_failure_option({module, function} = value) do
    if function_exported?(module, function, 1) do
      {:fn, value}
    else
      raise AppIdentityError, :plug_on_failure_callback_invalid
    end
  end

  defp resolve_on_failure_option(_), do: raise(AppIdentityError, :plug_on_failure_invalid)

  defp status_valid?(code) when is_integer(code) do
    Status.reason_atom(code)
    true
  rescue
    _ -> false
  end

  defp status_valid?(code) when is_atom(code) do
    Status.code(code)
    true
  rescue
    _ -> false
  end

  defp get_on_success(options) do
    options
    |> Keyword.get(:on_success)
    |> resolve_on_success_option()
  end

  defp resolve_on_success_option(nil), do: nil

  defp resolve_on_success_option(value) when is_function(value, 1), do: {:fn, value}

  defp resolve_on_success_option({module, function} = value) do
    if function_exported?(module, function, 1) do
      {:fn, value}
    else
      raise AppIdentityError, :plug_on_success_invalid
    end
  end

  defp resolve_on_success_option(_), do: raise(AppIdentityError, :plug_on_success_invalid)

  defp get_on_resolution(options) do
    options
    |> Keyword.get(:on_resolution)
    |> resolve_on_resolution_option()
  end

  defp resolve_on_resolution_option(nil), do: nil

  defp resolve_on_resolution_option(value) when is_function(value, 1), do: {:fn, value}

  defp resolve_on_resolution_option({module, function} = value) do
    if function_exported?(module, function, 1) do
      {:fn, value}
    else
      raise AppIdentityError, :plug_on_resolution_invalid
    end
  end

  defp resolve_on_resolution_option(_), do: raise(AppIdentityError, :plug_on_resolution_invalid)

  defp parse_option_app(input) do
    case App.new(input) do
      {:ok, app} ->
        {app.id, app}

      {:error, message} ->
        raise AppIdentityError,
              "AppIdentity.Plug configuration error: `apps` includes an invalid app: #{message}"
    end
  end

  defp parse_option_header(value, exception \\ :plug_header_invalid)

  defp parse_option_header(value, exception) when not is_binary(value), do: raise(AppIdentityError, exception)

  defp parse_option_header("", exception), do: raise(AppIdentityError, exception)
  defp parse_option_header(header, _exception), do: String.downcase(header)

  defp callback_telemetry_context({:fn, value}) when is_function(value, 1), do: "function (anonymous)"

  defp callback_telemetry_context({:fn, {module, function}}),
    do: "function (#{String.replace_prefix(to_string(module), "Elixir.", "")}.#{function}/1)"

  defp callback_telemetry_context(value), do: value
end
