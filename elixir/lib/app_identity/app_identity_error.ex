defmodule AppIdentity.AppIdentityError do
  @moduledoc """
  An exception that will be raised by `AppIdentity.generate_proof!/2`,
  `AppIdentity.parse_proof!/1`, or `AppIdentity.verify_proof!/3` when those
  functions fail. The error message reported here is *always* generic.

  This can also be raised by `AppIdentity.Plug` on configuration failure.
  """

  defexception [:message]

  @exception_messages %{
    verify_proof: "Error verifying proof",
    generate_proof: "Error generating proof",
    parse_proof: "Error parsing proof",
    disallowed_configuration_error: "Error in disallowed version configuration",
    plug_missing_apps_or_finder:
      "AppIdentity.Plug configuration error: one of `apps` or `finder` is required",
    plug_headers_required:
      "AppIdentity.Plug configuration error: one of `headers` or `header_groups` is required",
    plug_excess_headers:
      "AppIdentity.Plug configuration error: only one `headers` or `header_groups` option may be specified",
    plug_header_invalid: "AppIdentity.Plug configuration error: `headers` value is invalid",
    plug_header_groups_invalid:
      "AppIdentity.Plug configuration error: `header_groups` value is invalid",
    plug_finder_invalid: "AppIdentity.Plug configuration error: `finder` callback is invalid",
    plug_on_failure_invalid:
      "AppIdentity.Plug configuration error: `on_failure` value is invalid",
    plug_on_failure_callback_invalid:
      "AppIdentity.Plug configuration error: `on_failure` callback is invalid",
    plug_on_success_invalid:
      "AppIdentity.Plug configuration error: `on_success` callback is invalid",
    plug_on_resolution_invalid:
      "AppIdentity.Plug configuration error: `on_resolution` callback is invalid",
    plug_disallowed_invalid:
      "AppIdentity.Plug configuration error: `disallowed` value is invalid",
    plug_name_invalid: "AppIdentity.Plug configuration error: `name` value is invalid"
  }
  @known_exceptions Map.keys(@exception_messages)

  @impl true
  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end

  def exception(key) when key in @known_exceptions do
    exception(@exception_messages[key])
  end

  @impl true
  def message(%__MODULE__{message: message}) do
    message
  end
end
