# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../support", __FILE__))

gem "minitest"

require "minitest/autorun"

require "app_identity"
require "app_identity/support"

module Minitest::AppIdentityExtensions
  def assert_exception_message(message, *types, &block)
    msg = types.last if types.last.is_a?(String)

    types = [AppIdentity::Error] if types.empty?

    result = assert_raises(*types, &block)
    assert_equal message, result.message, msg
  end

  Minitest::Test.send(:include, self)
  Minitest::Test.send(:include, AppIdentity::Support)
end
