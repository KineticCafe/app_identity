if Code.ensure_loaded?(Plug.Conn) do
  defmodule AppIdentity.Plug do
    @moduledoc """
    A Plug that verifies App Identity proofs provided via one or more HTTP
    headers.

    When multiple proof values are provided in the request, all must be
    successfully verified. If any of the proof values cannot be verified,
    request processing halts with `403 Forbidden`. Should no proof headers be
    included, the request is considered invalid.

    All of the above behaviours can be modified through
    [configuration](`t:option/0`).

    ## Checking AppIdentity.Plug Results

    The results of AppIdentity.Plug are stored in Plug.Conn private storage as
    a map under the `:app_identity` key (this can be changed through the `name`
    option), keyed by the header group name. When using the `headers` option,
    each header is its own group. The `header_groups` option explicitly defines
    headers that will be treated as belonging to the same group.

    Header results only appear in the result map if they are present in the
    request. If AppIdentity.Plug is configured for `app1` and `app2` headers,
    but there are only values in `app1`, the resulting output will not include
    `app2`.

    ### Results Partitioning: `name` or Header Groups?

    AppIdentity.Plug provides two main ways to partition processed results:
    `name` or header groups (either automatic grouping via `headers` or explicit
    grouping via `header_groups`).

    Most applications that require result partitioning will use header groups,
    because there's only one pool of applications defined. In this case,
    use the following configuration as a guide.

    ```elixir
    plug AppIdentity.Plug, finder: &MyApp.Application.get/1,
                           on_failure: :continue,
                           header_groups: %{
                              "application" => ["application-identity"],
                              "service" => ["service-identity"]
                           }
    ```

    Later in request processsing, a controller or a route-specific Phoenix
    pipeline coud call a `require_application` function which pulls from
    `conn.private.app_identity` with the appropriate header group name for
    verification.

    If there are _separate_ pools of applications defined, or there is a need to
    have different `on_failure` conditions, then configure two AppIdentity.Plugs
    with different `name`s . The following example configuration would allow
    `application-identity` headers to fail without halting (even if _omitted_),
    but a missing or incorrect `service-identity` header would cause failures
    immediately.

    ```elixir
    plug AppIdentity.Plug, finder: &MyApp.Application.get/1,
                           on_failure: :continue,
                           headers: ["application-identity"]

    plug AppIdentity.Plug, name: :service_app_identity,
                           finder: &MyApp.ServiceApplication.get/1,
                           header: ["service-identity"]
    ```

    If multiple AppIdentity.Plug configurations _are_ used, different `name`
    values must be specified or the later plug will overwrite the results from
    the earlier plug.

    ## Telemetry

    When telemetry is enabled, this plug will emit `[:app_identity, :plug,
    :start]` and `[:app_identity, :plug, :stop]` events.
    """

    alias AppIdentity.App
    alias AppIdentity.AppIdentityError

    import Plug.Conn
    import AppIdentity.Telemetry

    @behaviour Plug

    @typedoc """
    AppIdentity.Plug configuration options prior to validation.

    - `apps`: A list of `AppIdentity.App` or `t:AppIdentity.App.input/0` values
      to be used for proof validation. Duplicate values will be ignored.

      ```elixir
      plug AppIdentity.Plug, apps: [app1, app2], ...
      ```

    - `disallowed`: A list of algorithm versions that are not allowed when
      processing received identity proofs. See `t:AppIdentity.disallowed/0`.

      ```elixir
      plug AppIdentity.Plug, disallowed: [1], ...
      ```

    - `finder`: An `t:AppIdentity.App.finder/0` function to load an
      `t:AppIdentity.App.input/0` from an external source given a parsed proof.

      ```elixir
      plug AppIdentity.Plug, finder: &ApplicationModel.get/1
      ```

    - `headers`: A list of HTTP header names, which will be normalized on
      initialization.

      ```elixir
      plug AppIdentity.Plug, headers: ["application-identity"], ...
      ```

      The result output uses each header name as the key for the related proof
      results. A configuration of `headers: ["app1", "app2"]` can produce
      a result map like `%{"app1" => [...], "app2" => [...]}`.

      Duplicate header names will result in an error. This option must be
      omitted if `header_groups` is used.

    - `header_groups`: A map of header group names to HTTP header names.
      Both header group names and HTTP header names must be binary strings.

      When using `header_groups`, there is no guaranteed order for processing
      groups, but the each headers within a group will be processed *in the
      order provided*.

      ```elixir
      plug AppIdentity.Plug,
        header_groups: %{
                          "application" => ["application", "my-application"],
                          "service" => ["service", "my-service"],
                          },
        ...
      ```

      The result output uses each header group name as the key for the related
      proof results from any header in that group. A configuration of
      `header_groups: %{"app" => ["app1", "app2"], "svc" => ["svc1"]}` can
      produce a result map like `%{"app" => [...], "svc" => [...]}`.

      Duplicate header names across any header groups will result in an error.
      This option must be omitted if `headers` is used.

    - `name`: An atom which will be used to store the `AppIdentity.Plug` results
      in Plug.Conn private storage. If not provided, defaults to
      `:app_identity`. Required if `AppIdentity.Plug` will be specified more
      than once as results are not merged.

      ```elixir
      plug AppIdentity.Plug, name: :service_app, ...
      ```

    - `on_failure`: The behaviour of the AppIdentity.Plug when proof validation
      fails. Must be one of the following values:

      - `:forbidden`: Halt request processing and respond with a `403`
        (forbidden) status. This is the same as `{:halt, :forbidden}`. This is
        the default `on_failure` behaviour.

        ```elixir
        plug AppIdentity.Plug, on_failure: :forbidden
        ```

      - `{:halt, Plug.Conn.status()}`: Halt request processing and return the
        specified status code. An empty body is emitted.

        ```elixir
        plug AppIdentity.Plug, on_failure: {:halt, :forbidden}
        ```

      - `{:halt, Plug.Conn.status(), Plug.Conn.body()}`: Halt request processing
        and return the specified status code. The body value is included in the
        response.

        ```elixir
        plug AppIdentity.Plug, on_failure: {:halt, :forbidden, ["Evicted"]}
        ```

      - `:continue`: Continue processing, ensuring that failure states are
        recorded for the application to act on at a later point. This could be
        used to implement a distinction between *validating* a proof and
        *requiring* that the proof is valid.

        ```elixir
        plug AppIdentity.Plug, on_failure: :continue
        ```

      - A 1-arity anonymous function or a {module, function} tuple accepting
        `Plug.Conn` that returns one of the above values.

        ```elixir
        plug AppIdentity.Plug, on_failure: {ApplicationModel, :resolve_proof_failure}
        plug AppIdentity.Plug, on_failure: &ApplicationModel.resolve_proof_failure/1
        ```

    At least one of `apps` or `finder` **must** be supplied. If both are
    present, apps are looked up in the `apps` list first.

    Only one of `headers` or `header_groups` may be supplied. If both are
    present, an exception will be raised.
    """
    @type option ::
            AppIdentity.disallowed()
            | {:headers, list(binary())}
            | {:header_groups, %{required(binary()) => list(binary())}}
            | {:apps, list(App.input() | App.t())}
            | {:finder, App.finder()}
            | {:name, atom}
            | {:on_failure, on_failure | on_failure_fn}

    @type on_failure ::
            :forbidden
            | :continue
            | {:halt, Plug.Conn.status()}
            | {:halt, Plug.Conn.status(), Plug.Conn.body()}

    @type on_failure_fn :: (Plug.Conn.t() -> on_failure) | {module(), function :: atom()}

    defstruct apps: %{},
              disallowed: [],
              finder: nil,
              headers: nil,
              header_groups: nil,
              name: :app_identity,
              on_failure: :forbidden

    @typedoc """
    Normalized options for AppIdentity.Plug.
    """
    @type t :: %__MODULE__{
            apps: %{optional(AppIdentity.id()) => App.t()},
            disallowed: list(AppIdentity.version()),
            finder: nil | App.finder(),
            headers: nil | list(binary()),
            header_groups: nil | %{required(binary()) => binary()},
            name: atom(),
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

      if !Keyword.has_key?(options, :headers) && !Keyword.has_key?(options, :header_groups) do
        raise AppIdentityError, :plug_headers_required
      end

      if Keyword.has_key?(options, :headers) && Keyword.has_key?(options, :header_groups) do
        raise AppIdentityError, :plug_excess_headers
      end

      %__MODULE__{
        apps: apps,
        finder: finder,
        disallowed: get_disallowed(options),
        headers: get_headers(options),
        header_groups: get_header_groups(options),
        name: get_name(options),
        on_failure: get_on_failure(options)
      }
    end

    @impl Plug
    @spec call(conn :: Plug.Conn.t(), options :: [option()] | t) :: Plug.Conn.t()
    def call(%{halted: true} = conn, _options) do
      conn
    end

    def call(conn, options) when is_list(options) do
      call(conn, init(options))
    end

    def call(conn, %__MODULE__{} = options) do
      {metadata, span_context} =
        start_span(:plug, %{conn: conn, options: telemetry_options(options)})

      conn =
        register_before_send(conn, fn conn ->
          stop_span(span_context, Map.put(metadata, :conn, conn))
          conn
        end)

      results =
        conn
        |> verify_request_headers(options)
        |> Map.new()

      conn = put_private(conn, options.name, results)

      if has_errors?(results) do
        dispatch_on_failure(options.on_failure, conn)
      else
        conn
      end
    end

    defp has_errors?(results) when is_map(results) do
      Enum.empty?(results) ||
        Enum.any?(results, fn
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
      dispatch_halt(conn)
    end

    defp dispatch_on_failure({:halt, status}, conn) do
      dispatch_halt(conn, status)
    end

    defp dispatch_on_failure({:halt, status, body}, conn) do
      dispatch_halt(conn, status, body)
    end

    defp dispatch_on_failure(:continue, conn) do
      conn
    end

    defp verify_request_headers(conn, %{headers: headers, header_groups: nil} = options) do
      parse_and_verify_headers(conn, headers, options)
    end

    defp verify_request_headers(conn, %{headers: nil, header_groups: groups} = options) do
      groups
      |> Enum.map(fn {group, headers} ->
        {
          group,
          conn
          |> parse_and_verify_headers(headers, options)
          |> Enum.map(fn {_, v} -> v end)
          |> List.flatten()
        }
      end)
      |> Enum.reject(&(match?({_, []}, &1) || match?({_, nil}, &1)))
    end

    defp parse_and_verify_headers(conn, headers, options) do
      headers
      |> Enum.map(&parse_request_header(conn, &1))
      |> Enum.reject(&(match?({_, nil}, &1) || match?({_, []}, &1)))
      |> verify_headers(options)
    end

    defp parse_request_header(conn, header) do
      {header, get_req_header(conn, header)}
    end

    defp verify_headers(headers, options) do
      Enum.map(headers, &verify_header(&1, options))
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

    defp dispatch_halt(conn, status \\ :forbidden, body \\ []) do
      conn
      |> put_resp_header("content-type", "text/plain")
      |> send_resp(status, body)
      |> halt()
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
            {name, Enum.map(headers, &parse_option_header/1)}
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

    defp telemetry_options(%__MODULE__{} = options) do
      apps =
        options.apps
        |> Map.values()
        |> telemetry_apps()

      on_failure =
        if is_function(options.on_failure, 1) do
          "function"
        else
          options.on_failure
        end

      [
        {:apps, apps},
        {:disallowed, options.disallowed},
        {:finder, telemetry_app(options.finder)},
        {:headers, options.headers},
        {:on_failure, on_failure}
      ]
      |> Enum.reject(&match?({_, nil}, &1))
      |> Map.new()
    end
  end
end
