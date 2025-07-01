defmodule AppIdentityPlugTest do
  use AppIdentity.PlugCase, async: true

  import Plug.Conn
  import Plug.Test

  alias AppIdentity.Plug, as: Subject
  alias AppIdentity.PlugCallbacks

  doctest Subject

  @default_header "application-identity"

  def call(conn, opts) do
    conn = Subject.call(conn, opts)

    if conn.halted || Keyword.get(opts, :skip_send) do
      conn
    else
      conn
      |> put_resp_header("content-type", "text/plain")
      |> send_resp(200, "OK")
    end
  end

  describe "call/2" do
    def assert_failed_request(conn, options \\ []) do
      status = Keyword.get(options, :status, 403)
      body = Keyword.get(options, :body, "")

      assert conn.halted
      assert status == conn.status
      assert body == conn.resp_body
    end

    def assert_successful_request(conn) do
      assert 200 == conn.status
      assert "OK" == conn.resp_body
    end

    def assert_private_app_identity(conn, apps, name \\ :app_identity) do
      assert apps == conn.private[name]
    end

    test "fails with no headers provided", %{v1: v1} do
      conn =
        "get"
        |> conn("/")
        |> call(headers: [@default_header], apps: [v1])

      assert_failed_request(conn)
      assert_plug_telemetry_span(403)
    end

    test "fails with an invalid proof", %{v1: v1} do
      conn =
        "get"
        |> conn("/")
        |> put_req_header(@default_header, "invalid proof")
        |> call(headers: [@default_header], apps: [v1])

      assert_failed_request(conn)
      assert_plug_telemetry_span(403)
    end

    test "fails with an invalid app proof", %{v1: v1, v2: v2} do
      conn =
        "get"
        |> conn("/")
        |> put_req_header(@default_header, AppIdentity.generate_proof!(v2))
        |> call(headers: [@default_header], apps: [v1])

      apps = %{@default_header => nil}

      assert_private_app_identity(conn, apps)
      assert_plug_telemetry_span(403, apps: apps, clients: v2)
    end

    test "fails with an invalid app proof with a custom name", %{v1: v1, v2: v2} do
      conn =
        "get"
        |> conn("/")
        |> put_req_header(@default_header, AppIdentity.generate_proof!(v2))
        |> call(headers: [@default_header], apps: [v1], name: :name)

      apps = %{@default_header => nil}

      assert_private_app_identity(conn, apps, :name)
      assert_plug_telemetry_span(403, apps: apps, clients: v2, name: :name)
    end

    for version <- AppIdentity.Versions.supported() do
      test "succeeds with a valid v#{version} app header", context do
        app = context[unquote(version)]

        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, AppIdentity.generate_proof!(app))
          |> call(headers: [@default_header], apps: [app])

        apps = %{@default_header => [verified(app)]}

        assert_successful_request(conn)
        assert_private_app_identity(conn, apps)

        assert_plug_telemetry_span(200, apps: apps, clients: app)
      end
    end

    test "succeeds with an app from a list", %{v1: v1, v2: v2} do
      conn =
        "get"
        |> conn("/")
        |> put_req_header(@default_header, AppIdentity.generate_proof!(v2))
        |> call(headers: [@default_header], apps: [v1, v2])

      apps = %{@default_header => [verified(v2)]}

      assert_successful_request(conn)
      assert_private_app_identity(conn, apps)

      assert_plug_telemetry_span(200, apps: apps, clients: v2)
    end

    test "succeeds with multiple apps and multiple headers", %{v1: v1, v2: v2} do
      extra_header = "x-app-identity"

      conn =
        "get"
        |> conn("/")
        |> put_req_header(@default_header, AppIdentity.generate_proof!(v1))
        |> put_req_header(extra_header, AppIdentity.generate_proof!(v2))
        |> call(headers: [@default_header, extra_header], apps: [v1, v2])

      apps = %{
        @default_header => [verified(v1)],
        extra_header => [verified(v2)]
      }

      assert_successful_request(conn)
      assert_private_app_identity(conn, apps)
      assert_plug_telemetry_span(200, apps: apps, clients: [v1, v2])
    end

    test "succeeds with multiple apps and multiple headers in a single header group", %{
      v1: v1,
      v2: v2
    } do
      extra_header = "x-app-identity"

      conn =
        "get"
        |> conn("/")
        |> put_req_header(@default_header, AppIdentity.generate_proof!(v1))
        |> put_req_header(extra_header, AppIdentity.generate_proof!(v2))
        |> call(header_groups: %{"group" => [@default_header, extra_header]}, apps: [v1, v2])

      apps = %{"group" => [verified(v1), verified(v2)]}

      assert_successful_request(conn)
      assert_private_app_identity(conn, apps)
      assert_plug_telemetry_span(200, apps: apps, clients: [v1, v2])
    end

    test "succeeds with multiple apps and multiple headers in multiple header groups", %{
      v1: v1,
      v2: v2
    } do
      extra_header = "x-app-identity"

      conn =
        "get"
        |> conn("/")
        |> put_req_header(@default_header, AppIdentity.generate_proof!(v1))
        |> put_req_header(extra_header, AppIdentity.generate_proof!(v2))
        |> call(
          header_groups: %{"default" => [@default_header], "extra" => [extra_header]},
          apps: [v1, v2]
        )

      apps = %{
        "default" => [verified(v1)],
        "extra" => [verified(v2)]
      }

      assert_successful_request(conn)
      assert_private_app_identity(conn, apps)
      assert_plug_telemetry_span(200, apps: apps, clients: [v1, v2])
    end

    test "only includes header groups with results present", %{v1: v1} do
      conn =
        "get"
        |> conn("/")
        |> put_req_header(@default_header, AppIdentity.generate_proof!(v1))
        |> call(
          header_groups: %{"default" => [@default_header], "extra" => ["excluded"]},
          apps: [v1]
        )

      apps = %{"default" => [verified(v1)]}

      assert_successful_request(conn)
      assert_private_app_identity(conn, apps)
      assert_plug_telemetry_span(200, apps: apps, clients: [v1])
    end

    @plugged EEx.compile_string("""
             defmodule <%= mod %> do
               use Plug.Builder

               alias AppIdentity.{
                 App,
                 Support
               }

               @v1 App.__to_map(App.new!(Support.v1()))
               def v1, do: @v1
               def v1(_), do: @v1

               @v2 App.__to_map(App.new!(Support.v2()))
               def v2, do: @v2
               def v2(_), do: @v2

               @default_header "application-identity"
               def default_header, do: @default_header
               @extra_header "x-application-identity"
               def extra_header, do: @extra_header

               plug(AppIdentity.Plug, headers: [@default_header], finder: &<%= mod %>.v1/1)
               plug(AppIdentity.Plug, headers: [@extra_header], name: :extra, finder: &<%= mod %>.v2/1)

               def call(conn, opts) do
                 conn
                 |> super(opts)
                 |> put_resp_header("content-type", "text/plain")
                 |> send_resp(200, "OK")
               end
             end
             """)

    test "succeeds with plug builder plugs" do
      {code, _bindings} = Code.eval_quoted(@plugged, mod: MultipleAppIdentityPlugs)
      [{mod, _bytecode}] = Code.compile_string(code)

      v1 = mod.v1()
      v2 = mod.v2()
      default_header = mod.default_header()
      extra_header = mod.extra_header()

      conn =
        "get"
        |> conn("/")
        |> put_req_header(default_header, AppIdentity.generate_proof!(v1))
        |> put_req_header(extra_header, AppIdentity.generate_proof!(v2))
        |> mod.call([])

      apps = %{default_header => [verified(v1)]}
      extra = %{extra_header => [verified(v2)]}

      assert_successful_request(conn)
      assert_private_app_identity(conn, apps)
      assert_private_app_identity(conn, extra, :extra)
      assert_plug_telemetry_span(200, apps: apps, clients: [v1, v2])
    end

    test "succeeds with multiple plugs", %{v1: v1, v2: v2} do
      extra_header = "x-app-identity"

      conn =
        "get"
        |> conn("/")
        |> put_req_header(@default_header, AppIdentity.generate_proof!(v1))
        |> put_req_header(extra_header, AppIdentity.generate_proof!(v2))
        |> call(headers: [@default_header], apps: [v1], skip_send: true)
        |> call(headers: [extra_header], apps: [v2], name: :extra)

      apps = %{@default_header => [verified(v1)]}
      extra = %{extra_header => [verified(v2)]}

      assert_successful_request(conn)
      assert_private_app_identity(conn, apps)
      assert_private_app_identity(conn, extra, :extra)
      assert_plug_telemetry_span(200, apps: apps, clients: [v1, v2])
    end

    test "succeeds with multiple apps in multiple instances of the same header", %{v1: v1, v2: v2} do
      conn =
        "get"
        |> conn("/")
        |> add_req_header(@default_header, AppIdentity.generate_proof!(v2))
        |> add_req_header(@default_header, AppIdentity.generate_proof!(v1))
        |> call(headers: [@default_header], apps: [v1, v2])

      apps = %{@default_header => [verified(v2), verified(v1)]}

      assert_successful_request(conn)
      assert_private_app_identity(conn, apps)
      assert_plug_telemetry_span(200, apps: apps, clients: [v2, v1])
    end

    test "succeeds with one apps in multiple instances of the same header", %{v1: v1} do
      conn =
        "get"
        |> conn("/")
        |> add_req_header(@default_header, AppIdentity.generate_proof!(v1))
        |> add_req_header(@default_header, AppIdentity.generate_proof!(v1))
        |> call(headers: [@default_header], apps: [v1])

      apps = %{@default_header => [verified(v1), verified(v1)]}

      assert_successful_request(conn)
      assert_private_app_identity(conn, apps)
      assert_plug_telemetry_span(200, apps: apps, clients: [v1, v1])
    end

    for {desc, value} <- %{
          ":forbidden" => :forbidden,
          "function returns :forbidden" => quote(do: fn _ -> :forbidden end),
          "{module, function} returns :forbidden" => {PlugCallbacks, :forbidden}
        } do
      test "halts with 403 (no body) with options.on_failure #{desc}", %{v1: v1} do
        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, "invalid proof")
          |> call(headers: [@default_header], apps: [v1], on_failure: unquote(value))

        assert_failed_request(conn)
        assert_plug_telemetry_span(403)
      end
    end

    for {desc, value} <- %{
          "{:halt, 401}" => {:halt, 401},
          "function returns {:halt, 401}" => quote(do: fn _ -> {:halt, 401} end),
          "{module, function} returns {:halt, 401}" => {PlugCallbacks, :halt_401}
        } do
      test "halts with 401 (no body) with options.on_failure #{desc}", %{v1: v1} do
        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, "invalid proof")
          |> call(headers: [@default_header], apps: [v1], on_failure: unquote(value))

        assert_failed_request(conn, status: 401)
        assert_plug_telemetry_span(401)
      end
    end

    for {desc, value} <- %{
          "{:halt, 418, Teapot}" => quote(do: {:halt, 418, "Teapot"}),
          "function returns {:halt, 418, Teapot}" => quote(do: fn _ -> {:halt, 418, "Teapot"} end),
          "{module, function} returns {:halt, 418, Teapot}" => {PlugCallbacks, :halt_teapot}
        } do
      test "halts with 418 Teapot with options.on_failure #{desc}", %{v1: v1} do
        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, "invalid proof")
          |> call(headers: [@default_header], apps: [v1], on_failure: unquote(value))

        assert_failed_request(conn, status: 418, body: "Teapot")
        assert_plug_telemetry_span(418)
      end
    end

    for {desc, value} <- %{
          ":continue" => :continue,
          "function returns :continue" => quote(do: fn _ -> :continue end),
          "{module, function} returns :continue" => {PlugCallbacks, :continue}
        } do
      test "continues on app finder failure when options.on_failure #{desc}", context do
        {:ok, alt} = AppIdentity.App.new(v1())

        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, AppIdentity.generate_proof!(alt))
          |> call(
            headers: [@default_header],
            on_failure: unquote(value),
            finder: make_finder(context)
          )

        apps = %{@default_header => [nil]}

        assert_successful_request(conn)
        assert_private_app_identity(conn, apps)
        assert_plug_telemetry_span(200, apps: apps, clients: alt)
      end

      test "continues on app finder module failure when options.on_failure #{desc}" do
        {:ok, alt} = AppIdentity.App.new(v1())

        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, AppIdentity.generate_proof!(alt))
          |> call(
            headers: [@default_header],
            on_failure: unquote(value),
            finder: {PlugCallbacks, :finder}
          )

        apps = %{@default_header => [nil]}

        assert_successful_request(conn)
        assert_private_app_identity(conn, apps)
        assert_plug_telemetry_span(200, apps: apps, clients: alt)
      end

      test "continues on proof validation failure when options.on_failure #{desc}", %{v1: v1} do
        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, "invalid proof")
          |> call(headers: [@default_header], apps: [v1], on_failure: unquote(value))

        apps = %{@default_header => [nil]}

        assert_successful_request(conn)
        assert_private_app_identity(conn, apps)
        assert_plug_telemetry_span(200, apps: apps)
      end

      test "continues on proof app location failure when options.on_failure #{desc}", %{
        v1: v1,
        v2: v2
      } do
        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, AppIdentity.generate_proof!(v2))
          |> call(headers: [@default_header], apps: [v1], on_failure: unquote(value))

        apps = %{@default_header => [nil]}

        assert_successful_request(conn)
        assert_private_app_identity(conn, apps)
        assert_plug_telemetry_span(200, apps: apps, clients: v2)
      end

      test "continues on proof app validation failure when options.on_failure #{desc}", %{v1: v1} do
        alt = %{v1 | secret: fn -> "a different secret" end}

        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, AppIdentity.generate_proof!(alt))
          |> call(headers: [@default_header], apps: [v1], on_failure: unquote(value))

        apps = %{@default_header => [AppIdentity.App.new!(v1)]}

        assert_successful_request(conn)
        assert_private_app_identity(conn, apps)
        assert_plug_telemetry_span(200, apps: apps, clients: alt)
      end
    end

    for {desc, value} <- %{
          "anonymous function" => quote(do: fn conn -> PlugCallbacks.on_resolution(conn) end),
          "{module, function}" => {PlugCallbacks, :on_resolution}
        } do
      test "options.on_resolution #{desc} is called on successful validation", %{v1: v1} do
        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, AppIdentity.generate_proof!(v1))
          |> call(headers: [@default_header], apps: [v1], on_resolution: unquote(value))

        apps = %{@default_header => [verified(v1)]}

        assert_successful_request(conn)
        assert_private_app_identity(conn, apps)
        assert_plug_telemetry_span(200, apps: apps, clients: v1)

        assert %{errors?: false} == conn.private[:on_resolution]
      end

      test "options.on_resolution #{desc} is called on failed validation", %{v1: v1} do
        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, "invalid proof")
          |> call(headers: [@default_header], apps: [v1], on_resolution: unquote(value))

        assert_failed_request(conn)
        assert_plug_telemetry_span(403)

        assert %{errors?: true} == conn.private[:on_resolution]
      end
    end

    for {desc, value} <- %{
          "anonymous function" => quote(do: fn conn -> PlugCallbacks.on_success(conn) end),
          "{module, function}" => {PlugCallbacks, :on_success}
        } do
      test "options.on_success #{desc} is called on successful validation", %{v1: v1} do
        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, AppIdentity.generate_proof!(v1))
          |> call(headers: [@default_header], apps: [v1], on_success: unquote(value))

        apps = %{@default_header => [verified(v1)]}

        assert_successful_request(conn)
        assert_private_app_identity(conn, apps)
        assert_plug_telemetry_span(200, apps: apps, clients: v1)

        assert %{errors?: false} == conn.private[:on_success]
      end

      test "options.on_success #{desc} is not called on failed validation", %{v1: v1} do
        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, "invalid proof")
          |> call(headers: [@default_header], apps: [v1], on_success: unquote(value))

        assert_failed_request(conn)
        assert_plug_telemetry_span(403)

        refute Map.has_key?(conn.private, :on_success)
      end
    end
  end
end
