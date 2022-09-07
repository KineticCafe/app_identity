if Code.ensure_loaded?(Plug.Conn) do
  defmodule AppIdentity.Plug do
    @moduledoc """
    A Plug that verifies App Identity proofs provided via one or more HTTP
    headers.

    When multiple proof values are provided in the request, all must be
    successfully verified. If any of the proof values cannot be verified,
    request processing halts with `403 Forbidden`. Should no proof headers are
    included, the request is considered invalid.

    All of the above behaviours can be modified through
    [configuration](`t:option/0`).

    The results of completed proof validations can be found at
    `%Plug.Conn{private: %{app_identity: %{}}}`, regardless of the success or
    failure state.
    """

    alias AppIdentity.{App, AppIdentityError}
    alias Plug.Conn

    @behaviour Plug

    @typedoc """
    AppIdentity.Plug configuration options prior to validation.

    - `apps`: A list of `AppIdentity.App` or `t:AppIdentity.App.input/0` values
      to be used for proof validation. Duplicate values will be ignored.

    - `disallowed`: A list of algorithm versions that are not allowed when
      processing received identity proofs. See `t:AppIdentity.disallowed/0`.

    - `finder`: An `t:AppIdentity.App.finder/0` function to load an
      `t:AppIdentity.App.input/0` from an external source given a parsed proof.

    - `headers`: A list of HTTP header names.

    - `on_failure`: The behaviour of the AppIdentity.Plug when proof validation
      fails. Must be one of the following values:

      - `:forbidden`: Halt request processing and respond with a `403`
        (forbidden) status. This is the same as `{:halt, :forbidden}`. This is
        the default `on_failure` behaviour.

      - `{:halt, Plug.Conn.status()}`: Halt request processing and return the
        specified status code. An empty body is emitted.

      - `{:halt, Plug.Conn.status(), Plug.Conn.body()}`: Halt request processing
        and return the specified status code. The body value is included in the
        response.

      - `:continue`: Continue processing, ensuring that failure states are
        recorded for the application to act on at a later point. This could be
        used to implement a distinction between *validating* a proof and
        *requiring* that the proof is valid.

      - A 1-arity anonymous function or a {module, function} tuple accepting
        `Plug.Conn` that returns one of the above values.

    At least one of `apps` or `finder` **must** be supplied. If both are
    present, apps are looked up in the `apps` list first.

    ```elixir
    plug AppIdentity.Plug, header: "application-identity",
      finder: fn proof -> ApplicationModel.get!(proof.id) end
    ```
    """
    @type option ::
            AppIdentity.disallowed()
            | {:headers, list(binary())}
            | {:apps, list(App.input() | App.t())}
            | {:finder, App.finder()}
            | {:on_failure, on_failure | on_failure_fn}

    @type on_failure ::
            :forbidden
            | :continue
            | {:halt, Conn.status()}
            | {:halt, Conn.status(), Conn.body()}

    @type on_failure_fn :: (Conn.t() -> on_failure) | {module(), function :: atom()}

    @enforce_keys [:headers]
    defstruct apps: %{}, disallowed: [], finder: nil, headers: [], on_failure: :forbidden

    @typedoc """
    Normalized options for AppIdentity.Plug.
    """
    @type t :: %__MODULE__{
            apps: %{optional(AppIdentity.id()) => App.t()},
            disallowed: list(AppIdentity.version()),
            finder: nil | App.finder(),
            headers: list(binary()),
            on_failure: on_failure | {:fn, on_failure}
          }

    @impl Plug
    @spec init(options :: [option()] | t) :: t
    def init(%__MODULE__{} = options) do
      options
    end

    def init(options) do
      if !Keyword.has_key?(options, :apps) && !Keyword.has_key?(options, :finder) do
        raise AppIdentityError, :plug_missing_apps_or_finder
      end

      apps = get_apps(options)
      finder = Keyword.get(options, :finder)

      if Enum.empty?(apps) && is_nil(finder) do
        raise AppIdentityError, :plug_missing_apps_or_finder
      end

      %__MODULE__{
        apps: apps,
        finder: finder,
        disallowed: get_disallowed(options),
        headers: get_headers(options),
        on_failure: get_on_failure(options)
      }
    end

    @impl Plug
    @spec call(conn :: Conn.t(), options :: [option()] | t) :: Conn.t()
    def call(conn, options) when is_list(options) do
      call(conn, init(options))
    end

    def call(conn, %__MODULE__{} = options) do
      headers =
        conn
        |> get_request_headers(options)
        |> verify_headers(options)

      conn = Conn.put_private(conn, :app_identity, headers)

      if has_errors?(headers) do
        dispatch_on_failure(options.on_failure, conn)
      else
        conn
      end
    end

    defp has_errors?(headers) when is_map(headers) do
      Enum.empty?(headers) ||
        Enum.any?(headers, fn
          {_, nil} -> true
          {_, []} -> true
          {_, values} -> Enum.any?(values, &(match?(nil, &1) || match?(%{verified: false}, &1)))
        end)
    end

    defp dispatch_on_failure({:fn, {module, function}}, conn) do
      dispatch_on_failure(apply(module, function, [conn]), conn)
    end

    defp dispatch_on_failure({:fn, on_failure}, conn) do
      conn
      |> on_failure.()
      |> dispatch_on_failure(conn)
    end

    defp dispatch_on_failure(:forbidden, conn) do
      halt(conn)
    end

    defp dispatch_on_failure({:halt, status}, conn) do
      halt(conn, status)
    end

    defp dispatch_on_failure({:halt, status, body}, conn) do
      halt(conn, status, body)
    end

    defp dispatch_on_failure(:continue, conn) do
      conn
    end

    defp get_request_headers(conn, options) do
      options.headers
      |> Enum.map(&parse_request_header(conn, &1))
      |> Enum.reject(&(match?({_, nil}, &1) || match?({_, []}, &1)))
      |> Map.new()
    end

    defp parse_request_header(conn, header) do
      {header, Conn.get_req_header(conn, header)}
    end

    defp verify_headers(headers, options) do
      Map.new(headers, &verify_header(&1, options))
    end

    defp verify_header({header, values}, options) do
      {header, Enum.reduce_while(values, [], &verify_header_value(&1, &2, options))}
    end

    defp verify_header_value(value, result, options) do
      with {:ok, proof} <- AppIdentity.parse_proof(value),
           {:ok, app} <- get_verification_app(proof, options) do
        verify_header_proof(proof, app, result, options)
      else
        _ -> handle_proof_error(options.on_failure, result, nil)
      end
    end

    defp verify_header_proof(proof, app, result, options) do
      case AppIdentity.verify_proof(proof, app, disallowed: options.disallowed) do
        {:ok, verified_app} when not is_nil(verified_app) -> {:cont, [verified_app | result]}
        _ -> handle_proof_error(options.on_failure, result, app)
      end
    end

    defp handle_proof_error(:continue, result, value) do
      {:cont, [value | result]}
    end

    defp handle_proof_error(:forbidden, _values, _value) do
      {:halt, nil}
    end

    defp handle_proof_error({:halt, _}, _values, _value) do
      {:halt, nil}
    end

    defp handle_proof_error({:halt, _, _}, _values, _value) do
      {:halt, nil}
    end

    defp handle_proof_error({:fn, _}, result, value) do
      {:cont, [value | result]}
    end

    defp halt(conn, status \\ :forbidden, body \\ []) do
      conn
      |> Conn.put_resp_header("content-type", "text/plain")
      |> Conn.send_resp(status, body)
      |> Conn.halt()
    end

    defp get_verification_app(proof, %{apps: apps, finder: nil}) do
      Map.fetch(apps, proof.id)
    end

    defp get_verification_app(proof, %{apps: apps, finder: finder}) do
      case Map.fetch(apps, proof.id) do
        :error -> App.new(finder.(proof))
        {:ok, _} = ok -> ok
      end
    end

    defp get_apps(options) do
      options
      |> Keyword.get(:apps, [])
      |> Enum.reduce(%{}, fn input, map ->
        {id, app} = parse_option_app(input)
        Map.put_new(map, id, app)
      end)
    end

    defp get_disallowed(options) do
      case Keyword.get(options, :disallowed) do
        nil -> []
        value when is_list(value) -> value
        _ -> raise AppIdentityError, :plug_disallowed_invalid
      end
    end

    defp get_headers(options) do
      headers = Keyword.get(options, :headers)

      if !is_list(headers) || Enum.empty?(headers) do
        raise AppIdentityError, :plug_headers_required
      end

      Enum.map(headers, &parse_option_header/1)
    end

    defp get_on_failure(options) do
      options
      |> Keyword.get(:on_failure)
      |> resolve_on_failure_option()
    end

    defp resolve_on_failure_option(value) when value in [:forbidden, :continue, nil] do
      value || :forbidden
    end

    defp resolve_on_failure_option(value) when is_function(value, 1) do
      {:fn, value}
    end

    defp resolve_on_failure_option({:halt, status} = value)
         when is_integer(status) or is_atom(status) do
      value
    end

    defp resolve_on_failure_option({:halt, status, _body} = value)
         when is_integer(status) or is_atom(status) do
      value
    end

    defp resolve_on_failure_option({module, function} = value) do
      if function_exported?(module, function, 1) do
        {:fn, value}
      else
        raise AppIdentityError, :plug_on_failure_invalid
      end
    end

    defp resolve_on_failure_option(_) do
      raise AppIdentityError, :plug_on_failure_invalid
    end

    defp parse_option_app(input) do
      case App.new(input) do
        {:ok, app} -> {app.id, app}
        {:error, message} -> raise AppIdentityError, message
      end
    end

    defp parse_option_header("") do
      raise AppIdentityError, :plug_header_invalid
    end

    defp parse_option_header(header) do
      String.downcase(header)
    end
  end
end
