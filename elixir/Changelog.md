# App Identity for Elixir Changelog

## 1.1.0 / 2023-03-28

- Add optional Telemetry support. If `:telemetry` is in your application's
  dependencies, and Telemetry support is not explicitly disabled, events
  will be emitted for `AppIdentity.generate_proof/2`,
  `AppIdentity.verify_proof/3`, and `AppIdentity.Plug`.

  Disable by adding this line to your application's configuration:'

  ```elixir
  config :app_identity, AppIdentity.Telemetry, enabled: false
  ```

- Fixed various issues on Elixir 1.10.

## 1.0.0 / 2022-09-07

- Initial release.
