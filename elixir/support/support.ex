defmodule AppIdentity.Support do
  @moduledoc false

  def make_app(version, fuzz \\ nil) do
    case version do
      1 -> AppIdentity.App.new(v1(fuzz))
      2 -> AppIdentity.App.new(v2(fuzz))
      3 -> AppIdentity.App.new(v3(fuzz))
      4 -> AppIdentity.App.new(v4(fuzz))
    end
  end

  def verified(%AppIdentity.App{} = app) do
    %{app | verified: true}
  end

  def verified(%{} = app) do
    verified(AppIdentity.App.new!(app))
  end

  def v1(fuzz \\ nil) do
    secret = SecureRandom.hex(32)

    output = %{
      version: 1,
      id: SecureRandom.uuid(),
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
    String.split(Base.url_decode64!(header, padding: false), ":")
  end

  def build_padlock(app, options \\ []) do
    secret = Keyword.get(options, :secret, app.secret)

    secret =
      if is_function(secret, 0) do
        secret.()
      else
        secret
      end

    raw =
      Enum.join(
        [
          Keyword.get(options, :id, app.id),
          Keyword.get(options, :nonce, "nonce"),
          secret
        ],
        ":"
      )

    hash =
      case Keyword.get(options, :version, app.version) do
        1 -> :sha256
        2 -> :sha256
        3 -> :sha384
        4 -> :sha512
      end

    hash
    |> :crypto.hash(raw)
    |> Base.encode16(case: :upper)
  end

  def build_proof(app, padlock, options \\ []) do
    app_id = Keyword.get(options, :id, app.id)
    nonce = Keyword.get(options, :nonce, "nonce")

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
end
