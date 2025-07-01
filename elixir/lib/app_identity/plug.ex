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
    [configuration](#module-configuration).

    ## Checking Results

    The results of AppIdentity.Plug are stored in Plug.Conn private storage as
    a map under the `:app_identity` key (this can be changed through the `name`
    option), keyed by the header group name. When using the `headers` option,
    each header is its own group. The `header_groups` option explicitly defines
    headers that will be treated as belonging to the same group.

    Header results only appear in the result map if they are present in the
    request. If AppIdentity.Plug is configured for `app1` and `app2` headers,
    but there are only values in `app1`, the resulting output will not include
    `app2`.

    ### Results Partitioning: Header Groups or Multiple Configurations?

    AppIdentity.Plug provides two main ways to partition processed results:
    `name` or header groups (either automatic grouping via `headers` or explicit
    grouping via `header_groups`).

    Most applications that require result partitioning will use header groups,
    because there's only one pool of applications defined. In this case, use the
    following configuration as a guide.

    ```elixir
    plug AppIdentity.Plug, finder: &MyApp.Application.get/1,
                           on_failure: :continue,
                           header_groups: %{
                              "application" => ["application-identity"],
                              "service" => ["service-identity"]
                           }
    ```

    Later in request processing, a controller or a route-specific Phoenix
    pipeline could call a `require_application` function which pulls from
    `conn.private[:app_identity]` with the appropriate header group name for
    verification.

    If there are _separate_ pools of applications defined, or there is a need to
    have different `on_failure` conditions, then configure two
    `AppIdentity.Plug`s with different `name`s . The following example
    configuration would allow `application-identity` headers to fail without
    halting (even if _omitted_), but a missing or incorrect `service-identity`
    header would cause failures immediately.

    ```elixir
    plug AppIdentity.Plug, finder: &MyApp.Application.get/1,
                           on_failure: :continue,
                           headers: ["application-identity"]

    plug AppIdentity.Plug, name: :service_app_identity,
                           finder: {MyApp.ServiceApplication, :get},
                           header: ["service-identity"]
    ```

    > #### Multiple Plugs Warning {: .warning }
    >
    > If multiple AppIdentity.Plug configurations _are_ used, different `name`
    > values must be specified or the later plug will overwrite the results from
    > the earlier plug.

    ## Configuration

    AppIdentity.Plug requires configuration for app discovery and identity
    headers and offers further configuration. Static configuration is strongly
    recommended.

    ### App Discovery

    So that AppIdentity.Plug can find apps used in identity validation, at least
    one of `apps` or `finder` **must** be supplied. If both are present, the
    `apps` configuration is consulted before calling the `finder` function.

    - `apps`: A list of `t:AppIdentity.App.t/0` or `t:AppIdentity.App.input/0`
    values to be used for proof validation. Duplicate apps will be ignored.

      ```elixir
      plug AppIdentity.Plug, apps: [app1, app2], ...
      ```

    - `finder`: A callback function conforming to `t:AppIdentity.App.finder/0`
      that loads an `t:AppIdentity.App.input/0` from an external source given
      a parsed proof. This may also be specified as a `{module, function}`
      tuple.

      ```elixir
      plug AppIdentity.Plug, finder: &ApplicationModel.get/1
      plug AppIdentity.Plug, finder: {ApplicationModel, :get}
      ```

      AppIdentity.Plug does not cache the results of the `finder` function. Any
      caching should be implemented in your application.

    ### Identity Headers

    AppIdentity.Plug does not have any default headers to search for app
    identity validation, requiring one of `headers` or `header_groups` to be
    configured. If both are present, an exception will be raised during
    configuration.

    - `headers`: A list of valid HTTP header names, which will be normalized on
      initialization.

      ```elixir
      plug AppIdentity.Plug, headers: ["application-identity"], ...
      ```

      The result output uses each header name as the key for the related proof
      results. A configuration of `headers: ["app1", "app2"]` can produce
      a result map like `%{"app1" => [...], "app2" => [...]}`.

      Duplicate header names will result in an error. This option must be
      omitted if `header_groups` is used.

    - `header_groups`: A map of header group names to valid HTTP header names.

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

    > #### `headers` or `header_groups`? {: .info}
    >
    > The correct choice between `headers` and `header_groups` depends on your
    > application's requirements, but `headers` can be expressed as
    > `header_groups` for ease of changing later.
    >
    > That is, the following configurations are equivalent:
    >
    >   ```elixir
    >   plug AppIdentity.Plug, headers: ["application-identity"], ...
    >   plug AppIdentity.Plug,
    >     headers_groups: %{"application-identity" => ["application-identity"]}, ...
    >   ```
    >
    > If your requirements treat each header uniquely, `headers` is a useful
    > shorthand configuration.

    ### Callbacks

    There are three configuration options that can be implemented as callbacks:
    `on_failure`, `on_success`, and `on_resolution`.

    - `on_failure`: The behaviour of the AppIdentity.Plug when proof validation
      fails. If not provided, this defaults to `:forbidden`. When provided, it
      must be one of the following values:

      - `:forbidden`: Halt request processing and respond with a `403`
        (forbidden) status. This is the same as `{:halt, :forbidden}`.

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

      - A 1-arity callback function (or a `{module, function}` tuple) that
        accepts a `Plug.Conn` and returns one of the above values. `on_failure`
        callbacks **must not** modify the passed `conn` value.

        ```elixir
        plug AppIdentity.Plug, on_failure: {ApplicationModel, :resolve_proof_failure}
        plug AppIdentity.Plug, on_failure: &ApplicationModel.resolve_proof_failure/1
        ```

    - `on_success`: A 1-arity callback function (or a `{module, function}`
      tuple) that accepts a `Plug.Conn` when proof validation succeeds. The
      `on_success` callback **may** modify the passed `conn` value and must
      return the modified `conn` value.

    - `on_resolution`: An 1-arity callback function (or a `{module, function}`
      tuple) that accepts a `Plug.Conn` after proof validation completes,
      regardless of success or failure. If present, this will be run as the last
      step (after `on_failure` and `on_success`). Because `on_failure` may halt
      pipeline processing, it may be necessary to check `conn.halted`. The
      `on_resolution` callback **may** modify the passed `conn` value and must
      return the modified `conn` value.

    The `on_success` and `on_resolution` callbacks are optional.

    ### Optional Configuration

    - `name`: An atom which will be used to store the `AppIdentity.Plug` results
      in Plug.Conn private storage. If not provided, defaults to
      `:app_identity`. Required if `AppIdentity.Plug` will be specified more
      than once as results are not merged.

      ```elixir
      plug AppIdentity.Plug, name: :service_app, ...
      ```

    - `disallowed`: A list of algorithm versions that are not allowed when
      processing received identity proofs. See `t:AppIdentity.disallowed/0`.

      ```elixir
      plug AppIdentity.Plug, disallowed: [1], ...
      ```
    ## Telemetry

    When telemetry is enabled, this plug will emit `[:app_identity, :plug,
    :start]` and `[:app_identity, :plug, :stop]` events.
    """

    @behaviour Plug

    import AppIdentity.Telemetry
    import Plug.Conn

    alias AppIdentity.App
    alias AppIdentity.Plug.Config

    defstruct apps: %{},
              disallowed: [],
              finder: nil,
              headers: nil,
              header_groups: nil,
              name: :app_identity,
              on_failure: :forbidden,
              on_success: nil,
              on_resolution: nil

    @impl Plug
    @spec init(params :: [Config.param()] | Config.t()) :: Config.t()
    def init(%Config{} = config), do: config

    def init(params) do
      Config.new!(params)
    end

    @impl Plug
    @spec call(conn :: Plug.Conn.t(), params :: [Config.param()] | Config.t()) :: Plug.Conn.t()
    def call(%{halted: true} = conn, _params), do: conn

    def call(conn, params) when is_list(params), do: call(conn, init(params))

    def call(conn, %Config{} = config) do
      {metadata, span_context} =
        start_span(:plug, %{conn: conn, options: Config.telemetry_context(config)})

      conn =
        register_before_send(conn, fn conn ->
          stop_span(span_context, Map.put(metadata, :conn, conn))
          conn
        end)

      results =
        conn
        |> verify_request_headers(config)
        |> Map.new()

      conn
      |> put_private(config.name, results)
      |> dispatch_results(config)
      |> dispatch_on_resolution(config.on_resolution)
    end

    defp dispatch_results(conn, config) do
      if has_errors?(conn.private[config.name]) do
        dispatch_on_failure(conn, config.on_failure)
      else
        dispatch_on_success(conn, config.on_success)
      end
    end

    # Returns `true` if any of the AppIdentity.Plug proof result maps contain
    # errors.
    #
    # An error is defined as:
    #
    # - a `nil` or empty header group
    # - any value in a header group list where the value is `nil` or is an
    # `t:AppIdentity.App.t/0` value with `verified: false`.
    defp has_errors?(results) when is_map(results) do
      Enum.empty?(results) ||
        Enum.any?(results, fn
          {_, nil} -> true
          {_, []} -> true
          {_, values} -> Enum.any?(values, &(match?(nil, &1) || match?(%{verified: false}, &1)))
        end)
    end

    defp dispatch_on_failure(conn, :forbidden), do: dispatch_halt(conn)
    defp dispatch_on_failure(conn, {:halt, status}), do: dispatch_halt(conn, status)
    defp dispatch_on_failure(conn, {:halt, status, body}), do: dispatch_halt(conn, status, body)
    defp dispatch_on_failure(conn, :continue), do: conn

    defp dispatch_on_failure(conn, {:fn, {module, function}}),
      do: dispatch_on_failure(conn, apply(module, function, [conn]))

    defp dispatch_on_failure(conn, {:fn, function}), do: dispatch_on_failure(conn, function.(conn))

    defp dispatch_on_success(conn, nil), do: conn
    defp dispatch_on_success(conn, {:fn, {module, function}}), do: apply(module, function, [conn])
    defp dispatch_on_success(conn, {:fn, on_success}), do: on_success.(conn)

    defp dispatch_on_resolution(conn, nil), do: conn

    defp dispatch_on_resolution(conn, {:fn, {module, function}}), do: apply(module, function, [conn])

    defp dispatch_on_resolution(conn, {:fn, function}), do: function.(conn)

    defp verify_request_headers(conn, %{headers: headers, header_groups: nil} = config),
      do: parse_and_verify_headers(conn, headers, config)

    defp verify_request_headers(conn, %{headers: nil, header_groups: groups} = config) do
      groups
      |> Enum.map(fn {group, headers} ->
        {
          group,
          conn
          |> parse_and_verify_headers(headers, config)
          |> Enum.map(fn {_, v} -> v end)
          |> List.flatten()
        }
      end)
      |> Enum.reject(&(match?({_, []}, &1) || match?({_, nil}, &1)))
    end

    defp parse_and_verify_headers(conn, headers, config) do
      headers
      |> Enum.map(&parse_request_header(conn, &1))
      |> Enum.reject(&(match?({_, nil}, &1) || match?({_, []}, &1)))
      |> verify_headers(config)
    end

    defp parse_request_header(conn, header), do: {header, get_req_header(conn, header)}

    defp verify_headers(headers, config), do: Enum.map(headers, &verify_header(&1, config))

    defp verify_header({header, values}, config),
      do: {header, Enum.reduce_while(values, [], &verify_header_value(&1, &2, config))}

    defp verify_header_value(value, result, config) do
      with {:ok, proof} <- AppIdentity.parse_proof(value),
           {:ok, app} <- get_verification_app(proof, config) do
        verify_header_proof(proof, app, result, config)
      else
        _ -> handle_proof_error(config.on_failure, result, nil)
      end
    end

    defp verify_header_proof(proof, app, result, config) do
      case AppIdentity.verify_proof(proof, app, disallowed: config.disallowed) do
        {:ok, verified_app} when not is_nil(verified_app) -> {:cont, [verified_app | result]}
        _ -> handle_proof_error(config.on_failure, result, app)
      end
    end

    defp handle_proof_error(:continue, result, value), do: {:cont, [value | result]}
    defp handle_proof_error(:forbidden, _values, _value), do: {:halt, nil}
    defp handle_proof_error({:halt, _}, _values, _value), do: {:halt, nil}
    defp handle_proof_error({:halt, _, _}, _values, _value), do: {:halt, nil}
    defp handle_proof_error({:fn, _}, result, value), do: {:cont, [value | result]}

    defp dispatch_halt(conn, status \\ :forbidden, body \\ []) do
      conn
      |> put_resp_header("content-type", "text/plain")
      |> send_resp(status, body)
      |> halt()
    end

    defp get_verification_app(proof, %{apps: apps, finder: nil}), do: Map.fetch(apps, proof.id)

    defp get_verification_app(proof, %{apps: apps, finder: {:fn, finder}}) do
      case Map.fetch(apps, proof.id) do
        :error ->
          app =
            case finder do
              function when is_function(function, 1) -> function.(proof)
              {module, function} -> apply(module, function, [proof])
            end

          App.new(app)

        {:ok, _} = ok ->
          ok
      end
    end
  end
end
