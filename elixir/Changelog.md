# App Identity for Elixir Changelog

## 1.1.0 / 2022-MM-DD

- Add optional Telemetry support. If telemetry is in your application's
  dependencies, and telemetry is not explicitly disabled, telemetry events will
  be emitted for `AppIdentity.generate_proof/2`, `AppIdentity.verify_proof/3`,
  and `AppIdentity.Plug`.

- Fixed various issues on Elixir 1.10.

## 1.0.0 / 2022-09-07

- Initial release.
