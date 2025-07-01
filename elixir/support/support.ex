defmodule AppIdentity.Support do
  @moduledoc false

  def make_app(version, fuzz \\ nil) do
    version_fn =
      case version do
        1 -> :v1
        2 -> :v2
        3 -> :v3
        4 -> :v4
      end

    input = apply(__MODULE__, version_fn, [fuzz])

    AppIdentity.App.new(input)
  end

  def verified(%AppIdentity.App{} = app) do
    %{app | verified: true}
  end

  def verified(%{} = app) do
    verified(AppIdentity.App.new!(app))
  end

  def v1(fuzz \\ nil) do
    secret = random_hex(32)

    output = %{
      version: 1,
      id: uuidv4(),
      secret: fn -> secret end
    }

    if fuzz && is_integer(fuzz) && fuzz > 0 do
      Map.put_new(output, :config, %{"fuzz" => fuzz})
    else
      output
    end
  end

  def v2(fuzz \\ nil) do
    %{v1(fuzz) | version: 2}
  end

  def v3(fuzz \\ nil) do
    %{v1(fuzz) | version: 3}
  end

  def v4(fuzz \\ nil) do
    %{v1(fuzz) | version: 4}
  end

  def decode_to_parts(header) do
    header
    |> Base.url_decode64!(padding: false)
    |> String.split(":")
  end

  def build_padlock(app, options \\ []) do
    raw =
      Enum.join(
        [
          Keyword.get(options, :id) || app.id,
          Keyword.get(options, :nonce) || "nonce",
          padlock_secret(app, options)
        ],
        ":"
      )

    app
    |> padlock_algorithm(options)
    |> :crypto.hash(raw)
    |> Base.encode16(case: padlock_case(options))
  end

  def build_proof(app, padlock, options \\ []) do
    app_id = Keyword.get(options, :id) || app.id
    nonce = Keyword.get(options, :nonce) || "nonce"

    proof =
      case Keyword.get(options, :version, 1) do
        1 -> "#{app_id}:#{nonce}:#{padlock}"
        version -> "#{version}:#{app_id}:#{nonce}:#{padlock}"
      end

    Base.url_encode64(proof)
  end

  def timestamp_nonce(diff \\ nil, scale \\ :minutes) do
    "Etc/UTC"
    |> DateTime.now!()
    |> adjust_timestamp(diff, scale)
    |> DateTime.to_iso8601(:basic)
  end

  def adjust_timestamp(timestamp, nil, _) do
    timestamp
  end

  def adjust_timestamp(timestamp, diff, :seconds) do
    DateTime.add(timestamp, diff, :second)
  end

  def adjust_timestamp(timestamp, diff, :minutes) do
    DateTime.add(timestamp, diff * 60, :second)
  end

  def adjust_timestamp(timestamp, diff, :hours) do
    DateTime.add(timestamp, diff * 24 * 60, :second)
  end

  # The following code is adapted from https://hex.pm/packages/secure_random,
  # released under the Apache 2.0 license, copyright 2017 Patrick Robertson and
  # contributors.

  defp uuidv4 do
    <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)
    <<g0::32, g1::16, g2::16, g3::16, g4::48>> = <<u0::48, 4::4, u1::12, 2::2, u2::62>>

    hex_pad(g0, 8) <>
      "-" <>
      hex_pad(g1, 4) <>
      "-" <>
      hex_pad(g2, 4) <>
      "-" <>
      hex_pad(g3, 4) <>
      "-" <>
      hex_pad(g4, 12)
  end

  defp random_hex(length) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  defp hex_pad(hex, count) do
    hex = Integer.to_string(hex, 16)
    lower(hex, :binary.copy("0", count - byte_size(hex)))
  end

  defp lower(<<h, t::binary>>, acc) when h in ?A..?F, do: lower(t, acc <> <<h + 32>>)
  defp lower(<<h, t::binary>>, acc), do: lower(t, acc <> <<h>>)
  defp lower(<<>>, acc), do: acc

  defp padlock_secret(app, options) do
    secret = Keyword.get(options, :secret) || app.secret

    if is_function(secret, 0) do
      secret.()
    else
      secret
    end
  end

  defp padlock_algorithm(app, options) do
    case Keyword.get(options, :version) || app.version do
      1 -> :sha256
      2 -> :sha256
      3 -> :sha384
      4 -> :sha512
    end
  end

  defp padlock_case(options) do
    case Keyword.get(options, :case) || :random do
      :upper -> :upper
      :lower -> :lower
      :random -> if :rand.uniform(10) <= 5, do: :upper, else: :lower
    end
  end
end
