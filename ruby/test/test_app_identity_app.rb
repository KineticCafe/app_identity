# frozen_string_literal: true

require "minitest_helper"

class TestAppIdentityApp < Minitest::Test
  def subject
    AppIdentity::App
  end

  def test_fails_with_no_app_and_no_block
    assert_exception_message("app cannot be created from input (missing value :id)") {
      subject.new(Object.new)
    }
  end

  def test_id_validation
    assert_exception_message("id must not be nil") {
      subject.new({id: nil})
    }
    assert_exception_message("id must not be an empty string") {
      subject.new({id: ""})
    }
    assert_exception_message("id must not contain colons") {
      subject.new({id: "1:1"})
    }
  end

  def test_secret_validation
    assert_exception_message("secret must not be nil") {
      subject.new({id: 1, secret: nil})
    }
    assert_exception_message("secret must not be an empty string") {
      subject.new({id: 1, secret: ""})
    }
    assert_exception_message("secret must be a binary string value") {
      subject.new({id: 1, secret: 3})
    }
  end

  def test_version_validation
    assert_exception_message("version must not be nil") {
      subject.new({id: 1, secret: "a", version: nil})
    }
    assert_exception_message("version cannot be converted to an integer") {
      subject.new({id: 1, secret: "a", version: ""})
    }
    assert_exception_message("version cannot be converted to an integer") {
      subject.new({id: 1, secret: "a", version: "3.5"})
    }
    assert_exception_message("version must be a positive integer") {
      subject.new({id: 1, secret: "a", version: 3.5})
    }
  end

  def test_config_validation
    assert_exception_message("config must be nil or a map") {
      subject.new({id: 1, secret: "a", version: 1, config: 3})
    }
  end

  def test_create_from_block
    assert subject.new(-> { {id: 1, secret: "a", version: 1} }).frozen?
  end
end
