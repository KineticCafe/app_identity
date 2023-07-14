# App Identity for Elixir Changelog

## 1.3.0 / 2023-07-20

- Rename all spec uses of `String.t()` to `binary()` as

- Extensive reorganization of the `AppIdentity.Plug` documentation to improve
  the readability of the configuration.

- Refactored configuration into `AppIdentity.Plug.Config` from the plug itself.
  This was done in part to resolve a Dialyzer issue.

- Add `on_resolution` and `on_success` callbacks in `AppIdentity.Plug.Config` to
  better support various workflows (such as adding proof validation results to
  `Logger.metadata/1`).

- Extended the `AppIdentity.Plug.Config.finder` callback to accept a tuple
  `{module, function}`.

- Improved `AppIdentity.Plug.Config` telemetry context formatting to include the
  plug `name`.

## 1.2.0 / 2023-07-07

- Add support for header groups in `AppIdentity.Plug` to better handle fallback
  headers. Kinetic’s original Elixir implementation always verified only the
  _first_ value from a _list_ of headers, like so:

  ```elixir
  with [] <- Conn.get_req_header(conn, "header-1"),
       [] <- Conn.get_req_header(conn, "header-2"),
       [] <- Conn.get_req_header(conn, "header-3") do
    :error
  else
    [value | _] -> {:ok, value}
  end
  ```

  AppIdentity.Plug always processes all values of a header and puts the result
  in a map with the header name as the key, it meant that each header result
  would need to be checked individually. Instead, the `header_groups` option
  collects _related_ headers into a single result key:

  ```elixir
  plug AppIdentity.Plug, header_groups: %{
    "app" => ["header-1", "header-2", "header-3"]
  }, ...
  ```

- Add support for alternate names so that `AppIdentity.Plug` can be specified
  multiple times in a pipeline and will store its data separately.

## 1.1.0 / 2023-03-28

- Add optional Telemetry support. If `:telemetry` is in your application's
  dependencies, and Telemetry support is not explicitly disabled, events will be
  emitted for `AppIdentity.generate_proof/2`, `AppIdentity.verify_proof/3`, and
  `AppIdentity.Plug`.

  Disable by adding this line to your application's configuration:'

  ```elixir
  config :app_identity, AppIdentity.Telemetry, enabled: false
  ```

- Fixed various issues on Elixir 1.10.

## 1.0.0 / 2022-09-07

- Initial release.
