# frozen_string_literal: true

# An exception that will be raised by AppIdentity.generate_proof!,
# AppIdentity.parse_proof!, or AppIdentity.verify_proof! when those functions
# fail. The error message reported here is *always* generic.
#
# This can also be raised by AppIdentity::RackMiddleware on configuration
# failure.
class AppIdentity::Error < ::StandardError
  attr_reader :message # :nodoc:

  def initialize(type) # :nodoc:
    @message = resolve(type)
  end

  private

  def resolve(type)
    case type
    when String
      type
    when :verify_proof
      "Error verifying proof"
    when :generate_proof
      "Error generating proof"
    when :parse_proof
      "Error parsing proof"
    when :disallowed_configuration_error
      "error in disallowed version configuration"
    when :plug_missing_apps_or_finder
      "AppIdentity::RackMiddleware configuration error: one of `apps` or `finder` options is required"
    when :plug_headers_required
      "AppIdentity::RackMiddleware configuration error: `headers` option is required"
    when :plug_header_invalid
      "AppIdentity::RackMiddleware configuration error: `headers` value is invalid"
    when :plug_on_failure_invalid
      "AppIdentity::RackMiddleware configuration error: `on_failure` value is invalid"
    when :plug_disallowed_invalid
      "AppIdentity::RackMiddleware configuration error: `disallowed` value is invalid"
    end
  end
end
