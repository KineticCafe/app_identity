if Code.ensure_loaded?(Tesla.Middleware) do
  defmodule AppIdentity.TeslaMiddleware do
    @moduledoc """
    A Tesla middleware that generates an app identity proof header for
    a request.

    The `options` provided has the following parameters:

    - `app`: (required) A value that can be passed to AppIdentity.App.new/1.

    - `disallowed`: A list of algorithm versions that are not allowed when
      processing received identity proofs. See `t:AppIdentity.disallowed/0`.

    - `header`: (required) The header to use for sending the app identity proof.

    - `on_failure`: (optional) The action to take when an app identity proof
      cannot be generated for any reason *except* configuration errors. May be
      one of the following values:

      - `:fail`: Fails the request with an error tuple. This is the default if
        `on_failure` is not specified.

      - `:pass`: Sets the header to the empty value returned. The request will
        probably fail on the receiving server side.

      - `:skip`: Does not add the header, as if the request were not made using
        an application.

    `on_failure` may also be provided an arity 3 function or `{module,
    function}` tuple that expects three parameters:

    - `env`: The Tesla middleware `env` value;
    - `app`: The identity app value provided to the middleware; and
    - `header`: The header name provided to the middleware.

    The function may return either the `env`, `:fail`, `:skip`, or `:pass`. Any
    other value will be treated as `:fail`.
    """

    alias AppIdentity.App

    @behaviour Tesla.Middleware

    @type option ::
            AppIdentity.disallowed()
            | {:app, App.input() | App.loader() | App.t()}
            | {:header, String.t()}
            | {:on_failure, on_failure | on_failure_fn}

    @type on_failure ::
            :fail | :pass | :skip

    @type on_failure_fn ::
            (Tesla.Env.t(), App.t(), header :: String.t() -> on_failure | Tesla.Env.t())
            | {module(), function :: atom()}

    @impl Tesla.Middleware
    @spec call(env :: Tesla.Env.t(), next :: Tesla.Env.stack(), options :: any()) ::
            Tesla.Env.result()
    def call(env, next, options) do
      with {:ok, candidate_app} <- Keyword.fetch(options, :app),
           {:ok, app} <- AppIdentity.App.new(candidate_app),
           {:ok, header} <- Keyword.fetch(options, :header) do
        call_with_app(env, next, app, header, options)
      else
        :error -> {:error, :config}
        error -> error
      end
    end

    defp call_with_app(env, next, app, header, options) do
      case AppIdentity.generate_proof(app, disallowed: Keyword.get(options, :disallowed)) do
        {:ok, proof} ->
          call_with_proof(env, next, header, proof)

        :error ->
          options
          |> Keyword.get(:on_failure, :fail)
          |> handle_proof_error(env, next, app, header)
      end
    end

    defp call_with_proof(env, next, header, proof) do
      env
      |> Tesla.put_headers([{header, proof}])
      |> Tesla.run(next)
    end

    defp handle_proof_error(:fail, _env, _next, app, _header) do
      {:error, "unable to generate proof for app #{app.id}"}
    end

    defp handle_proof_error(:skip, env, next, _app, _header) do
      Tesla.run(env, next)
    end

    defp handle_proof_error(:pass, env, next, _app, header) do
      call_with_proof(env, next, header, "")
    end

    defp handle_proof_error(fun, env, next, app, header) when is_function(fun, 3) do
      env
      |> fun.(app, header)
      |> handle_proof_error(env, next, app, header)
    end

    defp handle_proof_error({mod, fun}, env, next, app, header) do
      handle_proof_error(apply(mod, fun, [env, app, header]), env, next, app, header)
    end

    defp handle_proof_error(%Tesla.Env{} = env, _env, next, _app, _header) do
      Tesla.run(env, next)
    end
  end
end
