defmodule AppIdentity.AppIdentityError do
  @moduledoc """
  An exception that will be raised by `AppIdentity.generate_proof!/2`,
  `AppIdentity.parse_proof!/1`, or `AppIdentity.verify_proof!/3` when those
  functions fail. The error message reported here is *always* generic.

  This can also be raised by `AppIdentity.Plug` on configuration failure.
  """

  defexception [:message]

  @impl true
  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end

  def exception(:verify_proof) do
    exception("Error verifying proof")
  end

  def exception(:generate_proof) do
    exception("Error generating proof")
  end

  def exception(:parse_proof) do
    exception("Error parsing proof")
  end

  def exception(:disallowed_configuration_error) do
    exception("Error in disallowed version configuration")
  end

  def exception(:plug_missing_apps_or_finder) do
    exception(
      "AppIdentity.Plug configuration error: one of `apps` or `finder` options is required"
    )
  end

  def exception(:plug_headers_required) do
    exception("AppIdentity.Plug configuration error: `headers` option is required")
  end

  def exception(:plug_header_invalid) do
    exception("AppIdentity.Plug configuration error: `headers` value is invalid")
  end

  def exception(:plug_on_failure_invalid) do
    exception("AppIdentity.Plug configuration error: `on_failure` value is invalid")
  end

  def exception(:plug_disallowed_invalid) do
    exception("AppIdentity.Plug configuration error: `disallowed` value is invalid")
  end

  @impl true
  def message(%__MODULE__{message: message}) do
    message
  end
end
