defmodule AppIdentity.Telemetry do
  @moduledoc """
  If [telemetry](https://hexdocs.pm/telemetry) is a dependency in your
  application, and the telemetry is not explicitly disabled, telemetry events
  will be emitted for `AppIdentity.generate_proof/2`,
  `AppIdentity.verify_proof/3`, and `AppIdentity.Plug`. See
  `AppIdentity.Telemetry` for more information.

  ## Telemetry Events

  All of `AppIdentity`'s telemetry events are spans, consisting of `:start` and
  `:stop` events. These are always in the form `[:app_identity,
  <telemetry_type>, <event>]`.

  The events are:

  - `[:app_identity, :generate_proof, :start]` emitted when
    `AppIdentity.generate_proof/2` or `AppIdentity.generate_proof!/2` is called.
  - `[:app_identity, :generate_proof, :stop]` emitted when
    `AppIdentity.generate_proof/2` or `AppIdentity.generate_proof!/2` finishes,
    either on success or failure. Telemetry is generated *prior* to the raising
    of any exceptions for `AppIdentity.generate_proof/2`.
  - `[:app_identity, :plug, :start]` emitted when `AppIdentity.Plug` is
    called. If `AppIdentity.Plug` is called in-line, exceptions may be thrown
    if there are configuration issues and telemetry will not be emitted.
  - `[:app_identity, :plug, :stop]` emitted when the response is sent after
    `AppIdentity.Plug` completes.
  - `[:app_identity, :verify_proof, :start]` emitted when
    `AppIdentity.verify_proof/3` or `AppIdentity.verify_proof!/3` is called.
  - `[:app_identity, :verify_proof, :stop]` emitted when
    `AppIdentity.verify_proof/3` or `AppIdentity.verify_proof!/3` finishes,
    either on success or failure. Telemetry is verified *prior* to the raising
    of any exceptions for `AppIdentity.verify_proof/3`.

  ### Measurements

  All `AppIdentity` telemetry events measure one of two things:

  - `:start` events always measure `monotonic_time` (`:erlang.monotonic_time/0`)
    and `system_time` (`:erlang.system_time/0`).

  - `:stop` events always measure `monotonic_time` (`:erlang.monotonic_time/0`)
    and `duration` (the difference between the start time and stop time).

  ### Metadata

  All `AppIdentity` telemetry includes a `telemetry_span_context` key which is
  a `t::erlang.reference/0`. In this version, this value will be generated with
  the `:start` event and reused for the `:stop` event.

  When a measurement type is given as `t:telemetry_app`, this will be one of the
  following values:

  #### `[:app_identity, :generate_proof, :start]` Metadata

  - `app`: `t:telemetry_app/0`
  - `options`: a list of `t:AppIdentity.option/0`

  #### `[:app_identity, :generate_proof, :stop]` Metadata

  - `app`: `t:telemetry_app/0`
  - `options`: a list of `t:AppIdentity.option/0`
  - One of:
    - `proof`: The generated proof string
    - `error`: A descriptive error

  #### `[:app_identity, :plug, :start]` Metadata

  - `conn`: `t:Plug.Conn.t/0`
  - `options`: A map that may have the following keys (derived from
    `t:AppIdentity.Plug.Config.param/0`):
    - `apps`: a list of `t:telemetry_app/0` values
    - `finder`: if present, the string `"function (anonymous)"` for an anonymous
      finder function or `"function (module.function/1)"` for a finder function
      specified by name.
    - `headers`: a list of identity header names
    - `header_groups`: a map of header groups to lists of header names
    - `on_failure`: the atom value of `t:AppIdentity.Plug.Config.on_failure/0`
      or if the `on_failure` configuration is
      `t:AppIdentity.Plug.Config.on_failure_callback/0`, it will be either the
      string `"function (anonymous)"` for an anonymous callback or `"function
      (module.function/1)"` for a named callback.
    - `on_success`: if present, either the string `"function (anonymous)"` for
      an anonymous callback or `"function (module.function/1)"` for a named
      callback.
    - `on_resolution`: if present, either the string `"function (anonymous)"`
      for an anonymous callback or `"function (module.function/1)"` for a named
      callback.
    - `disallowed`: a `t:AppIdentity.disallowed/0` value.

  #### `[:app_identity, :plug, :stop]` Metadata

  - `conn`: `t:Plug.Conn.t/0`, updated after processing
  - `options`: A map with the following keys (derived from
    `t:AppIdentity.Plug.Config.param/0`):
    - `apps`: a list of `t:telemetry_app/0` values
    - `finder`: if present, the string `"function (anonymous)"` for an anonymous
      finder function or `"function (module.function/1)"` for a finder function
      specified by name.
    - `headers`: a list of identity header names
    - `header_groups`: a map of header groups to lists of header names
    - `on_failure`: the atom value of `t:AppIdentity.Plug.Config.on_failure/0`
      or if the `on_failure` configuration is
      `t:AppIdentity.Plug.Config.on_failure_callback/0`, it will be either the
      string `"function (anonymous)"` for an anonymous callback or `"function
      (module.function/1)"` for a named callback.
    - `on_success`: if present, either the string `"function (anonymous)"` for
      an anonymous callback or `"function (module.function/1)"` for a named
      callback.
    - `on_resolution`: if present, either the string `"function (anonymous)"`
      for an anonymous callback or `"function (module.function/1)"` for a named
      callback.
    - `disallowed`: a `t:AppIdentity.disallowed/0` value.

  #### `[:app_identity, :verify_proof, :start]` Metadata

  - `app`: `t:telemetry_app/0`
  - `options`: a list of `t:AppIdentity.option/0`
  - One of:
    - `candidate`: The candidate proof string
    - `proof`: The parsed proof

  #### `[:app_identity, :verify_proof, :stop]` Metadata

  - `app`: `t:telemetry_app/0`. In the case of an error, this will be the same
    `app` value as was reported in the `:start` event. If not, this value will
    be the post-verification version of the `app`.
  - `options`: a list of `t:AppIdentity.option/0`
  - One of:
    - `candidate`: The candidate proof string
    - `proof`: The parsed proof
  - In case of an error:
    - `error`: A descriptive error

  ## Disabling Telemetry

  Telemetry may be disabled by setting this for your configuration:

      config :app_identity, AppIdentity.Telemetry, enabled: false

  Recompile `app_identity` if this setting is changed:

  ```console
  $ mix deps.compile --force app_identity
  ```
  """

  alias AppIdentity.App

  @enabled Code.ensure_loaded?(:telemetry) &&
             Application.compile_env(:app_identity, [AppIdentity.Telemetry, :enabled], true)

  @doc false
  def enabled? do
    @enabled
  end

  @typep telemetry_type :: :generate_proof | :verify_proof | :plug
  @typep input :: nil | App.input() | App.loader() | App.finder() | App.t()
  @typedoc """
  A telemetry-safe version of an input or verified app.

  May be one of the following values:

  - `nil`: the app is not found or does not verify correctly.
  - `"loader"`: the app provided is a `t:AppIdentity.App.loader/0` function.
  - `"finder"`: the app provided is a `t:AppIdentity.App.finder/0` function.
  - Otherwise, a map is returned with required `:id` and `:version` keys and
    optional `:config` and `:verified` keys.
  """
  @opaque telemetry_app ::
            nil
            | String.t()
            | %{
                required(:id) => term(),
                required(:version) => term(),
                optional(:config) => term(),
                optional(:verified) => term()
              }

  # Span context returned from `start_span/2` and should be passed to
  # `stop_span/2`.
  @typep span_context :: {telemetry_type, start_time :: term()}

  # Start a telemetry span.
  @doc false
  @spec start_span(telemetry_type, metadata :: map()) :: {metadata :: map(), span_context}
  if @enabled do
    def start_span(telemetry_type, metadata) do
      metadata = span_metadata(metadata)
      start_time = :erlang.monotonic_time()

      :ok =
        :telemetry.execute(
          [:app_identity, telemetry_type, :start],
          %{monotonic_time: start_time, system_time: :erlang.system_time()},
          metadata
        )

      {metadata, {telemetry_type, start_time}}
    end
  else
    def start_span(telemetry_type, _) do
      {%{}, {telemetry_type, nil}}
    end
  end

  # Stop a started telemetry span.
  @doc false
  @spec stop_span(span_context, metadata :: map()) :: :ok
  if @enabled do
    def stop_span({telemetry_type, start_time}, metadata) do
      stop_time = :erlang.monotonic_time()

      :telemetry.execute(
        [:app_identity, telemetry_type, :stop],
        %{duration: stop_time - start_time, monotonic_time: stop_time},
        span_metadata(metadata)
      )
    end
  else
    def stop_span(_, _) do
      :ok
    end
  end

  # Ensures that the telemetry metadata have a span context.
  @doc false
  if @enabled do
    def span_metadata(metadata) do
      Map.put_new(metadata, :telemetry_span_context, :erlang.make_ref())
    end
  else
    def span_metadata(_) do
      %{}
    end
  end

  # Turns the provided input into something telemetry friendly. either `nil`,
  # `"loader"`, `"finder (anonymous)"`, `"finder (module.function/1)"` or
  # a partial `t:App.input/0` map (`secret` is excluded).
  @doc false
  @spec telemetry_app(input) :: telemetry_app
  if @enabled do
    def telemetry_app(nil) do
      nil
    end

    def telemetry_app(app) when is_function(app, 0) do
      "loader"
    end

    def telemetry_app(app) when is_function(app, 1) do
      "finder (anonymous)"
    end

    def telemetry_app({module, finder}) when is_atom(module) and is_atom(finder) do
      "finder (#{String.replace_prefix(to_string(module), "Elixir.", "")}.#{finder}/1)"
    end

    def telemetry_app(%{"id" => _} = app) do
      [
        {:id, app["id"]},
        {:config, app["config"]},
        {:version, app["version"]},
        {:verified, app["verified"]}
      ]
      |> Enum.reject(&match?({_, nil}, &1))
      |> Map.new()
    end

    def telemetry_app(app) when is_map(app) do
      Map.take(app, [:id, :config, :version, :verified])
    end
  else
    def telemetry_app(_) do
      nil
    end
  end

  # Turns the provided app list into values that are telemetry friendly. See
  # `telemetry_app/1`.
  @doc false
  @spec telemetry_apps(nil | list(input)) :: nil | list(telemetry_app)
  if @enabled do
    def telemetry_apps(nil) do
      nil
    end

    def telemetry_apps([]) do
      []
    end

    def telemetry_apps(apps) when is_list(apps) do
      Enum.map(apps, &telemetry_app/1)
    end
  else
    def telemetry_apps(_) do
      nil
    end
  end
end
