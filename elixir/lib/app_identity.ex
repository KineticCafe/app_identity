defmodule AppIdentity do
  @moduledoc """
  `AppIdentity` is an Elixir implementation of the Kinetic Commerce application
  [identity proof algorithm](spec.md).

  It implements identity proof generation and validation functions. These
  functions expect to work with an application structure
  (`t:AppIdentity.App.t/0`).
  """

  alias AppIdentity.{App, AppIdentityError, Proof}

  @typedoc """
  The App Identity app unique identifier. Validation of the `id` value will
  convert non-string IDs using Kernel.to_string/1.

  If using integer IDs, it is recommended that the `id` value be provided as
  some form of extended string value, such as that provided by Rails [global
  ID](https://github.com/rails/globalid) or the `absinthe_relay`
  [Node.IDTranslator](https://hexdocs.pm/absinthe_relay/Absinthe.Relay.Node.IDTranslator.html).
  Such representations are _also_ recommended if the ID is a compound value.

  `t:id/0` values _must not_ contain a colon (`:`) character.
  """
  @type id :: binary()

  @typedoc """
  The App Identity app secret value. This value is used _as provided_ with no
  encoding or decoding. Because this is a sensitive value, it may be provided as
  a closure in line with the EEF Security Working Group sensitive data
  [recommendation](https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/sensitive_data#wrapping).

  `AppIdentity.App` always stores this value as a closure.
  """
  @type secret :: binary()

  @typedoc """
  The positive integer version of the App Identity algorithm to use. Will be
  validated to be a supported version for app creation, and not an explicitly
  disallowed version during proof validation.

  If provided as a string value, it must convert cleanly to an integer value,
  which means that a version of `"3.5"` is not a valid value.

  App Identity algorithm versions are strictly upgradeable. That is, a version
  1 app can verify version 1, 2, 3, or 4 proofs. However, a version 2 app will
  _never_ validate a version 1 proof.

  <table>
    <thead>
      <tr>
        <th rowspan=2>Version</th>
        <th rowspan=2>Nonce</th>
        <th rowspan=2>Digest Algorithm</th>
        <th colspan=4>Can Verify</th>
      </tr>
      <tr><th>1</th><th>2</th><th>3</th><th>4</th></tr>
    </thead>
    <tbody>
      <tr><th>1</th><td>random</td><td>SHA 256</td><td>✅</td><td>✅</td><td>✅</td><td>✅</td></tr>
      <tr><th>2</th><td>timestamp ± fuzz</td><td>SHA 256</td><td>⛔️</td><td>✅</td><td>✅</td><td>✅</td></tr>
      <tr><th>3</th><td>timestamp ± fuzz</td><td>SHA 384</td><td>⛔️</td><td>⛔️</td><td>✅</td><td>✅</td></tr>
      <tr><th>4</th><td>timestamp ± fuzz</td><td>SHA 512</td><td>⛔️</td><td>⛔️</td><td>⛔️</td><td>✅</td></tr>
    </tbody>
  </table>
  """
  @type version :: pos_integer()

  @typedoc """
  A nonce value used in the algorithm proof. The shape of the nonce depends on
  the algorithm `t:version/0`.

  Version 1 `t:nonce/0` values should be cryptographically secure and
  non-sequential, but sufficiently fine-grained timestamps (those including
  microseconds, as `yyyymmddHHMMSS.sss`) _may_ be used. Version 1 proofs verify
  that the nonce is at least one byte long and do not contain a colon (`:`).

  Version 2, 3, and 4 `t:nonce/0` values only permit fine-grained timestamps
  that should be generated from a clock in sync with Network Time Protocol
  servers. The timestamp will be parsed and compared to the server time (also in
  sync with an NTP server).
  """
  @type nonce :: String.t()

  @typedoc """
  A list of algorithm versions that are not allowed.

  The presence of an app in this list will prevent the generation or
  verification of proofs for the specified version.

  If `nil`, an empty list, or missing, all versions are allowed.
  """
  @type disallowed :: {:disallowed, list(version())}

  @typedoc """
  Options for generating or verifying proofs.

  - `nonce` can specify a precomputed nonce for proof generation. It will be
    verified by the algorithm version for correctness and compatibility, but
    will otherwise be used unmodified. This option is ignored for proof
    verification.

  - `version` can specify the generation of a proof compatible with, but
    different than, the application version. This option is ignored for proof
    verification.
  """
  @type option ::
          disallowed
          | {:nonce, nonce()}
          | {:version, version()}

  @doc """
  Generate an identity proof string for the given application. Returns `{:ok,
  proof}` or `:error`.

  If `nonce` is provided, it must conform to the shape expected by the proof
  version. If not provided, it will be generated.

  If `version` is provided, it will be used to generate the nonce and the proof.
  This will allow a lower level application to raise its version level.

  ### Examples

  A version 1 app can have a fixed nonce, which will always produce the same
  value.

      iex> {:ok, app} = AppIdentity.App.new(%{version: 1, id: "decaf", secret: "bad"})
      iex> AppIdentity.generate_proof(app, nonce: "hello")
      {:ok, "ZGVjYWY6aGVsbG86RDNGNjJCQTYyOEIyMzhEOTgwM0MyNEU4NkNCOTY3M0ZEOTVCNTdBNkJGOTRFMkQ2NTMxQTRBODg1OTlCMzgzNQ=="}

  A version 2 app fails when given a non-timestamp nonce.

      iex> AppIdentity.generate_proof(v1(), version: 2, nonce: "hello")
      :error

  A version 2 app _cannot_ generate a version 1 nonce.

      iex> AppIdentity.generate_proof(v2(), version: 1)
      :error

  A version 2 app will be rejected if the version has been disallowed.

      iex> AppIdentity.generate_proof(v2(), disallowed: [1, 2])
      :error
  """
  @spec generate_proof(App.t() | App.loader() | App.t(), [option()]) ::
          {:ok, String.t()} | :error
  def generate_proof(app, options \\ []) do
    case AppIdentity.Internal.generate_proof(app, options) do
      {:ok, _} = ok -> ok
      _ -> :error
    end
  end

  @doc """
  Generate an identity proof string for the given application. Returns the proof
  string or raises an exception on error.

  If `nonce` is provided, it must conform to the shape expected by the proof
  version. If not provided, it will be generated.

  If `version` is provided, it will be used to generate the nonce and the proof.
  This will allow a lower level application to raise its version level.

  ### Examples

  A version 1 app can have a fixed nonce, which will always produce the same
  value.

      iex> {:ok, app} = AppIdentity.App.new(%{version: 1, id: "decaf", secret: "bad"})
      iex> AppIdentity.generate_proof!(app, nonce: "hello")
      "ZGVjYWY6aGVsbG86RDNGNjJCQTYyOEIyMzhEOTgwM0MyNEU4NkNCOTY3M0ZEOTVCNTdBNkJGOTRFMkQ2NTMxQTRBODg1OTlCMzgzNQ=="

  A version 2 app fails when given a non-timestamp nonce.

      iex> AppIdentity.generate_proof!(v1(), version: 2, nonce: "hello")
      ** (AppIdentity.AppIdentityError) Error generating proof

  A version 2 app _cannot_ generate a version 1 nonce.

      iex> AppIdentity.generate_proof!(v2(), version: 1)
      ** (AppIdentity.AppIdentityError) Error generating proof

  A version 2 app will be rejected if the version has been disallowed.

      iex> AppIdentity.generate_proof!(v2(), disallowed: [1, 2])
      ** (AppIdentity.AppIdentityError) Error generating proof
  """
  @spec generate_proof!(App.t() | App.loader() | App.t(), [option()]) :: String.t()
  def generate_proof!(app, options \\ []) do
    case AppIdentity.Internal.generate_proof(app, options) do
      {:ok, value} -> value
      _ -> raise AppIdentityError, :generate_proof
    end
  end

  @doc """
  Parses a proof string into an AppIdentity.Proof struct. Returns `{:ok, proof}`
  or `:error`.
  """
  @spec parse_proof(Proof.t() | String.t()) :: {:ok, Proof.t()} | :error
  def parse_proof(proof) do
    case AppIdentity.Internal.parse_proof(proof) do
      {:ok, _} = ok -> ok
      _ -> :error
    end
  end

  @doc """
  Parses a proof string into an AppIdentity.Proof struct. Returns the parsed
  proof or raises an exception.
  """
  @spec parse_proof!(Proof.t() | String.t()) :: Proof.t()
  def parse_proof!(proof) do
    case AppIdentity.Internal.parse_proof(proof) do
      {:ok, value} -> value
      _ -> raise AppIdentityError, :parse_proof
    end
  end

  @doc """
  Verify a `AppIdentity` proof value using a a provided `app`. Returns `{:ok,
  app}`, `{:ok, nil}`, or `:error`.

  The `proof` may be provided either as a string or a parsed
  `t:AppIdentity.Proof.t/0` (from `parse_proof/1`). String proof values are
  usually obtained from HTTP headers. At Kinetic Commerce, this has generally
  jeen `KCS-Application` or `KCS-Service`.

  The `app` can be provided as one of `t:AppIdentity.App.input/0`,
  `t:AppIdentity.App.t/0`, or `t:AppIdentity.App.finder/0`. If provided
  a finder, it will be called with the `proof` value.

  `verify_proof/3` has three possible return values:

  - `{:ok, AppIdentity.App}` when the proof is validated against the provided or
    located application;
  - `{:ok, nil}` when the proof matches the provided or located application, but
    it does not validate.
  - `:error` when there is any error during proof validation.

  ```elixir
  AppIdentity.verify_proof(proof, &IdentityApplications.get!(&1.id))
  ```
  """
  @spec verify_proof(Proof.t() | String.t(), App.finder() | App.input() | App.t(), [
          option()
        ]) ::
          {:ok, App.t() | nil} | :error
  def verify_proof(proof, app, options \\ []) do
    case AppIdentity.Internal.verify_proof(proof, app, options) do
      {:ok, _} = ok -> ok
      _ -> :error
    end
  end

  @doc """
  Verify a `AppIdentity` proof value using a a provided `app`. Returns the app,
  nil, or raises an exception on error.

  The `proof` may be provided either as a string or a parsed
  `t:AppIdentity.Proof.t/0` (from `parse_proof/1`). String proof values are
  usually obtained from HTTP headers. At Kinetic Commerce, this has generally
  jeen `KCS-Application` or `KCS-Service`.

  The `app` can be provided as one of `t:AppIdentity.App.input/0`,
  `t:AppIdentity.App.t/0`, or `t:AppIdentity.App.finder/0`. If provided
  a finder, it will be called with the `proof` value.

  `verify_proof/3` has two possible return values:

  - `AppIdentity.App` when the proof is validated against the provided or
    located application;
  - `nil` when the proof matches the provided or located application, but it
    does not validate.

  It raises an exception on any error during proof validation.

  ```elixir
  AppIdentity.verify_proof(proof, &IdentityApplications.get!(&1.id))
  ```
  """
  @spec verify_proof!(Proof.t() | String.t(), App.finder() | App.t(), [option()]) ::
          App.t() | nil
  def verify_proof!(proof, app, options \\ []) do
    case AppIdentity.Internal.verify_proof(proof, app, options) do
      {:ok, value} -> value
      _ -> raise AppIdentityError, :verify_proof
    end
  end

  @info %{
    name: AppIdentity.MixProject.project()[:name],
    version: AppIdentity.MixProject.project()[:version],
    spec_version: 4
  }

  @doc """
  The name, version, and supported specification version of this App Identity
  package for Elixir.
  """
  @spec info :: %{name: String.t(), version: String.t(), spec_version: pos_integer()}
  def info do
    @info
  end

  @doc """
  The name, version, or supported specification version of this App Identity
  package for Elixir.
  """
  @spec info(:name | :spec_version | :version) :: String.t() | pos_integer()
  def info(key) when key in [:name, :spec_version, :version] do
    @info[key]
  end
end
