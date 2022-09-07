defmodule AppIdentityPlugTest do
  use AppIdentity.PlugCase
  use Plug.Test

  alias AppIdentity.Plug, as: Subject

  doctest Subject

  @default_header "application-identity"

  defmodule OnFailure do
    def forbidden(_) do
      :forbidden
    end

    def halt_401(_) do
      {:halt, 401}
    end

    def halt_teapot(_) do
      {:halt, 418, "Teapot"}
    end

    def continue(_) do
      :continue
    end
  end

  def call(conn, opts) do
    conn = Subject.call(conn, opts)

    if conn.halted do
      conn
    else
      conn
      |> put_resp_header("content-type", "text/plain")
      |> send_resp(200, "OK")
    end
  end

  def add_req_header(%{req_headers: headers} = conn, key, value) do
    %{conn | req_headers: [{key, value} | headers]}
  end

  def make_finder(context) do
    fn proof ->
      context
      |> Map.values()
      |> Enum.filter(&match?(%AppIdentity.App{}, &1))
      |> Enum.find(fn %{id: id} -> id == proof.id end)
    end
  end

  describe "init/1" do
    test "fails without headers", %{v1: v1} do
      assert_error_reason(
        "AppIdentity.Plug configuration error: `headers` option is required",
        fn ->
          Subject.init(apps: [v1])
        end
      )
    end

    test "fails with invalid header name", %{v1: v1} do
      assert_error_reason(
        "AppIdentity.Plug configuration error: `headers` value is invalid",
        fn ->
          Subject.init(apps: [v1], headers: [""])
        end
      )
    end

    test "fails with empty list of headers", %{v1: v1} do
      assert_error_reason(
        "AppIdentity.Plug configuration error: `headers` option is required",
        fn ->
          Subject.init(apps: [v1], headers: [])
        end
      )
    end

    test "fails without apps or finder" do
      assert_error_reason(
        "AppIdentity.Plug configuration error: one of `apps` or `finder` options is required",
        fn ->
          Subject.init(headers: @default_header)
        end
      )
    end

    test "fails if apps do not create correctly" do
      assert_error_reason(
        "AppIdentity.Plug configuration error: one of `apps` or `finder` options is required",
        fn ->
          Subject.init(apps: [], headers: [@default_header])
        end
      )

      assert_error_reason(
        "app can only be created from a map or struct",
        fn ->
          Subject.init(apps: [3], headers: [@default_header])
        end
      )
    end

    test "succeeds if provided a finder", context do
      assert %{finder: finder, apps: %{}, headers: _} =
               Subject.init(finder: make_finder(context), headers: [@default_header])

      assert is_function(finder, 1)
    end
  end

  describe "call/2" do
    def assert_failed_request(conn, status \\ 403, body \\ "") do
      assert conn.halted
      assert status == conn.status
      assert body == conn.resp_body
    end

    def assert_successful_request(conn) do
      assert 200 == conn.status
      assert "OK" == conn.resp_body
    end

    def assert_private_app_identity(conn, apps) do
      assert apps == conn.private[:app_identity]
    end

    test "fails with no headers provided", %{v1: v1} do
      conn =
        "get"
        |> conn("/")
        |> call(headers: [@default_header], apps: [v1])

      assert_failed_request(conn)
    end

    test "fails with an invalid proof", %{v1: v1} do
      conn =
        "get"
        |> conn("/")
        |> put_req_header(@default_header, "invalid proof")
        |> call(headers: [@default_header], apps: [v1])

      assert_failed_request(conn)
    end

    test "fails with an invalid app proof", %{v1: v1, v2: v2} do
      conn =
        "get"
        |> conn("/")
        |> put_req_header(@default_header, AppIdentity.generate_proof!(v2))
        |> call(headers: [@default_header], apps: [v1])

      assert_failed_request(conn)
    end

    for version <- AppIdentity.Versions.supported() do
      test "succeeds with a valid v#{version} app header", context do
        app = context[unquote(version)]

        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, AppIdentity.generate_proof!(app))
          |> call(headers: [@default_header], apps: [app])

        assert_successful_request(conn)
        assert_private_app_identity(conn, %{@default_header => [verified(app)]})
      end
    end

    test "succeeds with an app from a list", %{v1: v1, v2: v2} do
      conn =
        "get"
        |> conn("/")
        |> put_req_header(@default_header, AppIdentity.generate_proof!(v2))
        |> call(headers: [@default_header], apps: [v1, v2])

      assert_successful_request(conn)
      assert_private_app_identity(conn, %{@default_header => [verified(v2)]})
    end

    test "succeeds with multiple apps and multiple headers", %{v1: v1, v2: v2} do
      extra_header = "x-app-identity"

      conn =
        "get"
        |> conn("/")
        |> put_req_header(@default_header, AppIdentity.generate_proof!(v1))
        |> put_req_header(extra_header, AppIdentity.generate_proof!(v2))
        |> call(headers: [@default_header, extra_header], apps: [v1, v2])

      assert_successful_request(conn)

      assert_private_app_identity(conn, %{
        @default_header => [verified(v1)],
        extra_header => [verified(v2)]
      })
    end

    test "succeeds with multiple apps in multiple instances of the same header", %{v1: v1, v2: v2} do
      conn =
        "get"
        |> conn("/")
        |> add_req_header(@default_header, AppIdentity.generate_proof!(v2))
        |> add_req_header(@default_header, AppIdentity.generate_proof!(v1))
        |> call(headers: [@default_header], apps: [v1, v2])

      assert_successful_request(conn)
      assert_private_app_identity(conn, %{@default_header => [verified(v2), verified(v1)]})
    end

    test "succeeds with one apps in multiple instances of the same header", %{v1: v1} do
      conn =
        "get"
        |> conn("/")
        |> add_req_header(@default_header, AppIdentity.generate_proof!(v1))
        |> add_req_header(@default_header, AppIdentity.generate_proof!(v1))
        |> call(headers: [@default_header], apps: [v1])

      assert_successful_request(conn)
      assert_private_app_identity(conn, %{@default_header => [verified(v1), verified(v1)]})
    end

    for {desc, value} <- %{
          ":forbidden" => :forbidden,
          "function returns :forbidden" => quote(do: fn _ -> :forbidden end),
          "{module, function} returns :forbidden" => {OnFailure, :forbidden}
        } do
      test "halts with 403 (no body) with on_failure #{desc}", %{v1: v1} do
        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, "invalid proof")
          |> call(headers: [@default_header], apps: [v1], on_failure: unquote(value))

        assert_failed_request(conn)
      end
    end

    for {desc, value} <- %{
          "{:halt, 401}" => {:halt, 401},
          "function returns {:halt, 401}" => quote(do: fn _ -> {:halt, 401} end),
          "{module, function} returns {:halt, 401}" => {OnFailure, :halt_401}
        } do
      test "halts with 401 (no body) with on_failure #{desc}", %{v1: v1} do
        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, "invalid proof")
          |> call(headers: [@default_header], apps: [v1], on_failure: unquote(value))

        assert_failed_request(conn, 401)
      end
    end

    for {desc, value} <- %{
          "{:halt, 418, Teapot}" => quote(do: {:halt, 418, "Teapot"}),
          "function returns {:halt, 418, Teapot}" =>
            quote(do: fn _ -> {:halt, 418, "Teapot"} end),
          "{module, function} returns {:halt, 418, Teapot}" => {OnFailure, :halt_teapot}
        } do
      test "halts with 418 Teapot with on_failure #{desc}", %{v1: v1} do
        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, "invalid proof")
          |> call(headers: [@default_header], apps: [v1], on_failure: unquote(value))

        assert_failed_request(conn, 418, "Teapot")
      end
    end

    for {desc, value} <- %{
          ":continue" => :continue,
          "function returns :continue" => quote(do: fn _ -> :continue end),
          "{module, function} returns :continue" => {OnFailure, :continue}
        } do
      test "continues on proof validation failure when on_failure #{desc}", %{v1: v1} do
        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, "invalid proof")
          |> call(headers: [@default_header], apps: [v1], on_failure: unquote(value))

        assert_successful_request(conn)
        assert_private_app_identity(conn, %{@default_header => [nil]})
      end

      test "continues on proof app location failure when on_failure #{desc}", %{v1: v1, v2: v2} do
        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, AppIdentity.generate_proof!(v2))
          |> call(headers: [@default_header], apps: [v1], on_failure: unquote(value))

        assert_successful_request(conn)
        assert_private_app_identity(conn, %{@default_header => [nil]})
      end

      test "continues on proof app validation failure when on_failure #{desc}", %{v1: v1} do
        alt = %{v1 | secret: fn -> "a different secret" end}

        conn =
          "get"
          |> conn("/")
          |> put_req_header(@default_header, AppIdentity.generate_proof!(alt))
          |> call(headers: [@default_header], apps: [v1], on_failure: unquote(value))

        assert_successful_request(conn)
        assert_private_app_identity(conn, %{@default_header => [AppIdentity.App.new!(v1)]})
      end
    end
  end
end
