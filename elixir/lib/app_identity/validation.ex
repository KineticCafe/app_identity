defmodule AppIdentity.Validation do
  @moduledoc false

  @supported_versions AppIdentity.Versions.supported()

  @type validation_types :: :id | :secret | :version | :config | :padlock | :nonce

  @doc """
  AppIdentity value shape validation:

  - `config` may be `nil` or a map optionally containing `fuzz` (either atom or
    string), which must be a positive integer.

  - `id` must not be nil, must be convertable to a string, and must not contain
    a colon (`:`) character. The output value *will always* be a string.

  - `nonce` must not be nil, must be a string, must not be empty, and must not
    contain a colon (`:`) character. Specific algorithm versions may impose
    additional constraints on the value of the nonce.

  - `padlock` must not be nil, must be a string, must not be empty, and must not
    contain a colon (`:`) character.

  - `secret` must not be nil, must be a valid binary string (a `binary` value,
    which may or may not be UTF-8 safe). It may contain *any* character.

  - `version` must be a convertable positive integer with a permitted value of
    #{inspect(@supported_versions)}. Specific operations may be configured to
    exclude otherwise supported versions.

  ### Examples

      iex> AppIdentity.Validation.validate(:config, nil)
      {:ok, nil}

      iex> AppIdentity.Validation.validate(:config, %{fuzz: -3})
      {:error, "config.fuzz must be a positive integer or nil"}

      iex> AppIdentity.Validation.validate(:id, 8675309)
      {:ok, "8675309"}

      iex> AppIdentity.Validation.validate(:id, "1:2")
      {:error, "id must not contain colon characters"}

      iex> AppIdentity.Validation.validate(:nonce, nil)
      {:error, "nonce must not be nil"}

      iex> AppIdentity.Validation.validate(:padlock, "")
      {:error, "padlock must not be an empty string"}

      iex> AppIdentity.Validation.validate(:secret, "")
      {:error, "secret must not be an empty binary string"}

      iex> AppIdentity.Validation.validate(:secret, 3)
      {:error, "secret must be a binary string value"}

      iex> AppIdentity.Validation.validate(:version, "3")
      {:ok, 3}

      iex> AppIdentity.Validation.validate(:version, "3.5")
      {:error, "version cannot be converted to a positive integer"}

      iex> AppIdentity.Validation.validate(:version, 5)
      {:error, "unsupported version 5"}
  """
  @spec validate(type :: validation_types, value :: term) ::
          {:ok, value :: term} | {:error, reason :: String.t()}
  def validate(:config, nil) do
    {:ok, nil}
  end

  def validate(:config, value) when is_map(value) do
    case value[:fuzz] || value["fuzz"] do
      nil -> {:ok, value}
      fuzz when is_integer(fuzz) and fuzz > 0 -> {:ok, value}
      _ -> {:error, "config.fuzz must be a positive integer or nil"}
    end
  end

  def validate(:config, _) do
    {:error, "config must be nil or a map"}
  end

  def validate(type, nil) do
    {:error, "#{type} must not be nil"}
  end

  def validate(:secret, value) when is_function(value, 0) do
    case validate(:secret, value.()) do
      {:ok, _} -> {:ok, value}
      {:error, _} -> {:error, "secret function must produce a binary string value"}
    end
  end

  def validate(:secret, value) when not is_binary(value) do
    {:error, "secret must be a binary string value"}
  end

  def validate(:secret, value) when is_binary(value) and byte_size(value) === 0 do
    {:error, "secret must not be an empty binary string"}
  end

  def validate(:secret, value) when is_binary(value) do
    {:ok, value}
  end

  def validate(:padlock, value) when not is_binary(value) do
    {:error, "padlock must be a string value"}
  end

  def validate(:nonce, value) when not is_binary(value) do
    {:error, "nonce must be a string value"}
  end

  def validate(:version, value) when is_binary(value) do
    case Integer.parse(value) do
      {version, ""} -> validate(:version, version)
      _ -> {:error, "version cannot be converted to a positive integer"}
    end
  end

  def validate(:version, value) when is_integer(value) and value > 0 do
    if value in @supported_versions do
      {:ok, value}
    else
      {:error, "unsupported version #{inspect(value)}"}
    end
  end

  def validate(:version, value) when is_integer(value) do
    {:error, "version must be a positive integer"}
  end

  def validate(:version, value) when not is_integer(value) do
    {:error, "version must be a positive integer"}
  end

  def validate(type, "") do
    {:error, "#{type} must not be an empty string"}
  end

  def validate(:id, value) when not is_binary(value) do
    validate(:id, to_string(value))
  end

  def validate(:secret, value) when is_binary(value) do
    {:ok, value}
  end

  def validate(type, value) when is_binary(value) do
    if String.contains?(value, ":") do
      {:error, "#{type} must not contain colon characters"}
    else
      {:ok, value}
    end
  end
end
