defmodule AppIdentityTeslaMiddlewareTest do
  use AppIdentity.Case

  alias AppIdentity.TeslaMiddleware, as: Subject

  defmodule OnFailure do
    def fail(_env, _app, _header) do
      :fail
    end

    def pass(_env, _app, _header) do
      :pass
    end

    def skip(_env, _app, _header) do
      :skip
    end
  end

  def call(options) do
    Subject.call(%Tesla.Env{}, [], options)
  end

  test "middleware errors on configuration without `app` option" do
    assert {:error, :config} = call([])
  end

  test "middleware errors on configuration without `header` option", %{v1: v1} do
    assert {:error, :config} = call(app: v1)
  end

  for version <- AppIdentity.Versions.supported() do
    test "middleware generates a valid v#{version} proof", context do
      app = context[unquote(version)]

      assert {:ok, env} = call(app: app, header: "app-identity")
      assert {"app-identity", proof} = Enum.find(env.headers, &match?({"app-identity", _}, &1))
      assert {:ok, verified(app)} == AppIdentity.verify_proof(proof, app)
    end
  end

  test "middleware fails on disallowed when on_failure is :fail (default)", %{v1: v1} do
    assert {:error, "unable to generate proof for app #{v1.id}"} ==
             call(app: v1, header: "app-identity", disallowed: [1], on_failure: :fail)
  end

  test "middleware skips the header when on_failure is :skip", %{v1: v1} do
    assert {:ok, env} = call(app: v1, header: "app-identity", disallowed: [1], on_failure: :skip)
    assert Enum.empty?(env.headers)
  end

  test "middleware passes along an empty header when on_failure is :pass", %{v1: v1} do
    assert {:ok, env} = call(app: v1, header: "app-identity", disallowed: [1], on_failure: :pass)
    assert [{"app-identity", ""}] == env.headers
  end

  test "middleware fails on disallowed when on_failure function returns :fail", %{v1: v1} do
    assert {:error, "unable to generate proof for app #{v1.id}"} ==
             call(
               app: v1,
               header: "app-identity",
               disallowed: [1],
               on_failure: fn _, _, _ -> :fail end
             )
  end

  test "middleware skips the header when on_failure function returns :skip", %{v1: v1} do
    assert {:ok, env} =
             call(
               app: v1,
               header: "app-identity",
               disallowed: [1],
               on_failure: fn _, _, _ -> :skip end
             )

    assert Enum.empty?(env.headers)
  end

  test "middleware passes along an empty header when on_failure function returns :pass", %{v1: v1} do
    assert {:ok, env} =
             call(
               app: v1,
               header: "app-identity",
               disallowed: [1],
               on_failure: fn _, _, _ -> :pass end
             )

    assert [{"app-identity", ""}] == env.headers
  end

  test "middleware fails on disallowed when on_failure {module, function} returns :fail", %{
    v1: v1
  } do
    assert {:error, "unable to generate proof for app #{v1.id}"} ==
             call(
               app: v1,
               header: "app-identity",
               disallowed: [1],
               on_failure: {OnFailure, :fail}
             )
  end

  test "middleware skips the header when on_failure {module, function} returns :skip", %{v1: v1} do
    assert {:ok, env} =
             call(
               app: v1,
               header: "app-identity",
               disallowed: [1],
               on_failure: {OnFailure, :skip}
             )

    assert Enum.empty?(env.headers)
  end

  test "middleware passes along an empty header when on_failure {module, function} returns :pass",
       %{v1: v1} do
    assert {:ok, env} =
             call(
               app: v1,
               header: "app-identity",
               disallowed: [1],
               on_failure: {OnFailure, :pass}
             )

    assert [{"app-identity", ""}] == env.headers
  end
end
