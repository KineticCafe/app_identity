defmodule AppIdentityPlugConfigTest do
  use AppIdentity.PlugCase, async: true

  alias AppIdentity.Plug.Config, as: Subject
  alias AppIdentity.PlugCallbacks

  @default_header "application-identity"

  def invalid_callback, do: true

  describe "new!/1" do
    test "fails without `headers` or `header_groups`", %{v1: v1} do
      assert_error_reason(
        "AppIdentity.Plug configuration error: one of `headers` or `header_groups` is required",
        fn ->
          Subject.new!(apps: [v1])
        end
      )
    end

    test "fails with both `headers` and `header_groups`", %{v1: v1} do
      assert_error_reason(
        "AppIdentity.Plug configuration error: only one `headers` or `header_groups` option may be specified",
        fn ->
          Subject.new!(apps: [v1], headers: ["v1"], header_groups: %{"a" => ["b"]})
        end
      )
    end

    invalid_headers = %{
      "`headers`: invalid header name (empty string)" => [""],
      "`headers`: invalid header name (non-binary)" => [3],
      "`headers`: empty list" => [],
      "`headers`: duplicate headers" => ["v1", "v1"],
      "`headers`: not a list" => "v1"
    }

    for {name, value} <- invalid_headers do
      test "fails with #{name}", %{v1: v1} do
        assert_error_reason(
          "AppIdentity.Plug configuration error: `headers` value is invalid",
          fn ->
            Subject.new!(apps: [v1], headers: unquote(value))
          end
        )
      end
    end

    invalid_header_groups = %{
      "`header_groups`: not a map" => "v1",
      "`header_groups`: empty map" => %{},
      "`header_groups`: contains an empty group list" => %{"a" => []},
      "`header_groups`: contains an invalid header name (empty string)" => %{"a" => [""]},
      "`header_groups`: contains an invalid header name (non-binary)" => %{"a" => [3]},
      "`header_groups`: has duplicate headers (one list)" => %{"a" => ["v1", "v1"]},
      "`header_groups`: has duplicate headers (multiple lists)" => %{"a" => ["v1"], "b" => ["v1"]}
    }

    for {name, value} <- invalid_header_groups do
      value = Macro.escape(value)

      test "fails with #{name}", %{v1: v1} do
        assert_error_reason(
          "AppIdentity.Plug configuration error: `header_groups` value is invalid",
          fn ->
            Subject.new!(apps: [v1], header_groups: unquote(value))
          end
        )
      end
    end

    test "fails without `apps` or `finder`" do
      assert_error_reason(
        "AppIdentity.Plug configuration error: one of `apps` or `finder` is required",
        fn ->
          Subject.new!(headers: @default_header)
        end
      )
    end

    test "fails if `apps` is an empty list and `finder` is not provided" do
      assert_error_reason(
        "AppIdentity.Plug configuration error: one of `apps` or `finder` is required",
        fn ->
          Subject.new!(apps: [], headers: [@default_header])
        end
      )
    end

    test "fails if `apps` values are not valid input" do
      assert_error_reason(
        "AppIdentity.Plug configuration error: `apps` includes an invalid app: app can only be created from a map or struct",
        fn ->
          Subject.new!(apps: [3], headers: [@default_header])
        end
      )
    end

    test "fails if an anonymous `finder` is not arity 1" do
      finder = fn -> true end

      assert_error_reason(
        "AppIdentity.Plug configuration error: `finder` callback is invalid",
        fn ->
          Subject.new!(finder: finder, headers: [@default_header])
        end
      )
    end

    test "fails if a `finder` reference is not arity 1" do
      assert_error_reason(
        "AppIdentity.Plug configuration error: `finder` callback is invalid",
        fn ->
          Subject.new!(finder: {__MODULE__, :invalid_callback}, headers: [@default_header])
        end
      )
    end

    test "fails if `finder` is not a function or reference" do
      assert_error_reason(
        "AppIdentity.Plug configuration error: `finder` callback is invalid",
        fn ->
          Subject.new!(finder: 3, headers: [@default_header])
        end
      )
    end

    test "fails with a non-atom plug `name`", %{v1: v1} do
      assert_error_reason(
        "AppIdentity.Plug configuration error: `name` value is invalid",
        fn ->
          Subject.new!(apps: [v1], headers: [@default_header], name: "invalid")
        end
      )
    end

    invalid_disallowed = %{
      "a non-list `disallowed` value" => 3,
      "non-numeric `disallowed` value in list" => ["3"],
      "non-integer `disallowed` value in list" => [3.0],
      "negative `disallowed` value in list" => [-3],
      "unsupported `disallowed` value in list" => [999_999]
    }

    for {name, value} <- invalid_disallowed do
      test "fails with #{name}", %{v1: v1} do
        assert_error_reason(
          "AppIdentity.Plug configuration error: `disallowed` value is invalid",
          fn ->
            Subject.new!(apps: [v1], headers: [@default_header], disallowed: unquote(value))
          end
        )
      end
    end

    invalid_on_failure = %{
      "an invalid `on_failure` atom value" => :invalid,
      "an invalid `on_failure` halt status code integer" => {:halt, 999},
      "an invalid `on_failure` halt status code atom" => {:halt, :invalid},
      "an invalid `on_failure` halt status value" => {:halt, "invalid"},
      "an invalid `on_failure` value type" => "invalid"
    }

    for {name, value} <- invalid_on_failure do
      test "fails with #{name}", %{v1: v1} do
        assert_error_reason(
          "AppIdentity.Plug configuration error: `on_failure` value is invalid",
          fn ->
            Subject.new!(apps: [v1], headers: [@default_header], on_failure: unquote(value))
          end
        )
      end
    end

    test "fails with an invalid `on_failure` anonymous callback", %{v1: v1} do
      assert_error_reason(
        "AppIdentity.Plug configuration error: `on_failure` callback is invalid",
        fn ->
          Subject.new!(
            apps: [v1],
            headers: [@default_header],
            on_failure: fn ->
              nil
            end
          )
        end
      )
    end

    test "fails with an invalid `on_failure` named callback", %{v1: v1} do
      assert_error_reason(
        "AppIdentity.Plug configuration error: `on_failure` callback is invalid",
        fn ->
          Subject.new!(
            apps: [v1],
            headers: [@default_header],
            on_failure: {__MODULE__, :invalid_callback}
          )
        end
      )
    end

    test "fails with an invalid `on_success` anonymous callback", %{v1: v1} do
      assert_error_reason(
        "AppIdentity.Plug configuration error: `on_success` callback is invalid",
        fn ->
          Subject.new!(
            apps: [v1],
            headers: [@default_header],
            on_success: fn ->
              nil
            end
          )
        end
      )
    end

    test "fails with an invalid `on_success` named callback", %{v1: v1} do
      assert_error_reason(
        "AppIdentity.Plug configuration error: `on_success` callback is invalid",
        fn ->
          Subject.new!(
            apps: [v1],
            headers: [@default_header],
            on_success: {__MODULE__, :invalid_callback}
          )
        end
      )
    end

    test "fails with an invalid `on_resolution` anonymous callback", %{v1: v1} do
      assert_error_reason(
        "AppIdentity.Plug configuration error: `on_resolution` callback is invalid",
        fn ->
          Subject.new!(
            apps: [v1],
            headers: [@default_header],
            on_resolution: fn ->
              nil
            end
          )
        end
      )
    end

    test "fails with an invalid `on_resolution` named callback", %{v1: v1} do
      assert_error_reason(
        "AppIdentity.Plug configuration error: `on_resolution` callback is invalid",
        fn ->
          Subject.new!(
            apps: [v1],
            headers: [@default_header],
            on_resolution: {__MODULE__, :invalid_callback}
          )
        end
      )
    end

    test "provides only `headers` list for `headers`", %{v1: v1} do
      assert %{headers: [@default_header], header_groups: nil} =
               Subject.new!(apps: [v1], headers: [@default_header])
    end

    test "provides only `headers_groups` for a `header_groups` map", %{v1: v1} do
      assert %{headers: nil, header_groups: %{"a" => ~w[b c], "c" => ["a"]}} =
               Subject.new!(apps: [v1], header_groups: %{"a" => ~w[b c], "c" => ["a"]})
    end

    test "transforms `headers`", %{v1: v1} do
      assert %{headers: ["test-header"]} = Subject.new!(apps: [v1], headers: ["Test-Header"])
    end

    test "ignores duplicate `apps` entries" do
      assert %{apps: %{"1" => %{id: "1", version: 1}}} =
               Subject.new!(
                 apps: [
                   %{id: "1", secret: "hello", version: 1},
                   %{id: "1", secret: "goodbye", version: 2}
                 ],
                 headers: [@default_header]
               )
    end

    test "succeeds if provided an anonymous `finder`", context do
      assert %{finder: {:fn, finder}, apps: %{}, headers: _} =
               Subject.new!(finder: make_finder(context), headers: [@default_header])

      assert is_function(finder, 1)
    end

    test "succeeds if provided a `finder` reference" do
      assert %{finder: {:fn, {PlugCallbacks, :finder}}, apps: %{}, headers: _} =
               Subject.new!(finder: {PlugCallbacks, :finder}, headers: [@default_header])
    end
  end

  describe "telemetry_context/1" do
    def apps(values) do
      values
      |> Enum.sort_by(& &1.id)
      |> Enum.map(fn app ->
        Map.merge(
          %{config: nil, verified: false},
          Map.take(app, [:config, :id, :verified, :version])
        )
      end)
    end

    test "one `apps` entry and `headers`", %{v1: v1} do
      assert %{
               apps: apps([v1]),
               headers: [@default_header],
               on_failure: :forbidden,
               name: :app_identity,
               disallowed: []
             } ==
               Subject.new!(apps: [v1], headers: [@default_header])
               |> Subject.telemetry_context()
    end

    test "multiple `apps` entries and `header_groups`", %{v1: v1, v2: v2} do
      assert %{
               apps: apps([v1, v2]),
               header_groups: %{"a" => ~w[b c], "c" => ["a"]},
               on_failure: :forbidden,
               name: :app_identity,
               disallowed: []
             } ==
               Subject.new!(apps: [v2, v1], header_groups: %{"a" => ~w[b c], "c" => ["a"]})
               |> Subject.telemetry_context()
    end

    test "transforms `headers`", %{v1: v1} do
      assert %{
               apps: apps([v1]),
               headers: ["test-header"],
               on_failure: :forbidden,
               name: :app_identity,
               disallowed: []
             } ==
               Subject.new!(apps: [v1], headers: ["Test-Header"])
               |> Subject.telemetry_context()
    end

    test "ignores duplicate `apps` entries" do
      assert %{
               apps: apps([%{id: "1", secret: "hello", version: 1}]),
               headers: [@default_header],
               on_failure: :forbidden,
               name: :app_identity,
               disallowed: []
             } ==
               Subject.new!(
                 apps: [
                   %{id: "1", secret: "hello", version: 1},
                   %{id: "1", secret: "goodbye", version: 2}
                 ],
                 headers: [@default_header]
               )
               |> Subject.telemetry_context()
    end

    test "reports an anonymous `finder`", context do
      assert %{
               finder: "function (anonymous)",
               apps: [],
               headers: [@default_header],
               name: :app_identity,
               disallowed: [],
               on_failure: :forbidden
             } ==
               Subject.new!(finder: make_finder(context), headers: [@default_header])
               |> Subject.telemetry_context()
    end

    test "reports a `finder` reference" do
      assert %{
               finder: "function (AppIdentity.PlugCallbacks.finder/1)",
               apps: [],
               headers: [@default_header],
               name: :app_identity,
               disallowed: [],
               on_failure: :forbidden
             } ==
               Subject.new!(finder: {PlugCallbacks, :finder}, headers: [@default_header])
               |> Subject.telemetry_context()
    end

    test "custom `name`", %{v1: v1} do
      assert %{
               apps: apps([v1]),
               headers: [@default_header],
               name: :alternate_name,
               disallowed: [],
               on_failure: :forbidden
             } ==
               Subject.new!(
                 apps: [v1],
                 headers: [@default_header],
                 name: :alternate_name
               )
               |> Subject.telemetry_context()
    end

    test "`on_failure` specific value", %{v1: v1} do
      assert %{
               apps: apps([v1]),
               headers: [@default_header],
               name: :app_identity,
               disallowed: [],
               on_failure: {:halt, 418, "Teapot"}
             } ==
               Subject.new!(
                 apps: [v1],
                 headers: [@default_header],
                 on_failure: {:halt, 418, "Teapot"}
               )
               |> Subject.telemetry_context()
    end

    test "`on_failure` anonymous callback", %{v1: v1} do
      assert %{
               apps: apps([v1]),
               headers: [@default_header],
               name: :app_identity,
               disallowed: [],
               on_failure: "function (anonymous)"
             } ==
               Subject.new!(
                 apps: [v1],
                 headers: [@default_header],
                 on_failure: &PlugCallbacks.on_failure/1
               )
               |> Subject.telemetry_context()
    end

    test "`on_failure` named callback", %{v1: v1} do
      assert %{
               apps: apps([v1]),
               headers: [@default_header],
               name: :app_identity,
               disallowed: [],
               on_failure: "function (AppIdentity.PlugCallbacks.on_failure/1)"
             } ==
               Subject.new!(
                 apps: [v1],
                 headers: [@default_header],
                 on_failure: {PlugCallbacks, :on_failure}
               )
               |> Subject.telemetry_context()
    end

    test "`on_success` anonymous callback", %{v1: v1} do
      assert %{
               apps: apps([v1]),
               headers: [@default_header],
               name: :app_identity,
               disallowed: [],
               on_failure: :forbidden,
               on_success: "function (anonymous)"
             } ==
               Subject.new!(
                 apps: [v1],
                 headers: [@default_header],
                 on_success: &PlugCallbacks.on_success/1
               )
               |> Subject.telemetry_context()
    end

    test "`on_success` named callback", %{v1: v1} do
      assert %{
               apps: apps([v1]),
               headers: [@default_header],
               name: :app_identity,
               disallowed: [],
               on_failure: :forbidden,
               on_success: "function (AppIdentity.PlugCallbacks.on_success/1)"
             } ==
               Subject.new!(
                 apps: [v1],
                 headers: [@default_header],
                 on_success: {PlugCallbacks, :on_success}
               )
               |> Subject.telemetry_context()
    end

    test "`on_resolution` anonymous callback", %{v1: v1} do
      assert %{
               apps: apps([v1]),
               headers: [@default_header],
               name: :app_identity,
               disallowed: [],
               on_failure: :forbidden,
               on_resolution: "function (anonymous)"
             } ==
               Subject.new!(
                 apps: [v1],
                 headers: [@default_header],
                 on_resolution: &PlugCallbacks.on_resolution/1
               )
               |> Subject.telemetry_context()
    end

    test "`on_resolution` named callback", %{v1: v1} do
      assert %{
               apps: apps([v1]),
               headers: [@default_header],
               name: :app_identity,
               disallowed: [],
               on_failure: :forbidden,
               on_resolution: "function (AppIdentity.PlugCallbacks.on_resolution/1)"
             } ==
               Subject.new!(
                 apps: [v1],
                 headers: [@default_header],
                 on_resolution: {PlugCallbacks, :on_resolution}
               )
               |> Subject.telemetry_context()
    end
  end
end
