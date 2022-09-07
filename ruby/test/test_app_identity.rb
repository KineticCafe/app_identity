# frozen_string_literal: true

require "minitest_helper"

class TestAppIdentity < Minitest::Test
  def subject
    @subject ||= AppIdentity::Internal.send(:new)
  end

  def test_generate_v1_proof
    proof = subject.generate_proof!(v1)
    refute_nil proof
    assert_equal 3, decode_to_parts(proof).length
  end

  def test_generate_valid_v1_proof
    proof = subject.generate_proof!(v1)
    assert_equal v1_app.verify, subject.verify_proof!(proof, v1)
  end

  def test_generate_v2_proof
    proof = subject.generate_proof!(v2_app)
    refute_nil proof
    assert_equal 4, decode_to_parts(proof).length
  end

  def test_generate_valid_v2_proof
    proof = subject.generate_proof!(v2)
    assert_equal v2_app.verify, subject.verify_proof!(proof, v2)
  end

  def test_generate_valid_v3_proof
    proof = subject.generate_proof!(v3)
    assert_equal v3_app.verify, subject.verify_proof!(proof, v3)
  end

  def test_verify_fails_if_not_base64
    assert_exception_message("proof must have 3 parts (version 1) or 4 parts (any version)") {
      subject.verify_proof!("not base64", v1)
    }
  end

  def test_verify_fail_on_insufficent_parts
    assert_exception_message("proof must have 3 parts (version 1) or 4 parts (any version)") {
      subject.verify_proof!(Base64.urlsafe_encode64("a:b"), v1)
    }
  end

  def test_verify_fail_on_bad_v1_nonce
    padlock = build_padlock(v1_app, nonce: "n:once")
    proof = build_proof(v1_app, padlock, nonce: "n:once")

    assert_exception_message("version cannot be converted to an integer") {
      subject.verify_proof!(proof, v1)
    }
  end

  def test_verify_fail_on_bad_v2_nonce_format
    padlock = build_padlock(v1_app)
    proof = build_proof(v1_app, padlock, version: 2)

    assert_exception_message("nonce does not look like a timestamp") {
      subject.verify_proof!(proof, v1)
    }
  end

  def test_verify_fail_on_v2_nonce_out_of_fuzz
    nonce = timestamp_nonce(-11, :minutes)
    padlock = build_padlock(v1_app, nonce: nonce, version: 2)
    proof = build_proof(v1_app, padlock, version: 2, nonce: nonce)

    assert_exception_message("nonce is invalid") {
      subject.verify_proof!(proof, v1)
    }
  end

  def test_verify_fail_on_v1_nonce_for_v2_app
    padlock = build_padlock(v2_app, version: 1)
    proof = build_proof(v2_app, padlock, version: 1)

    assert_exception_message("proof and app version mismatch") {
      subject.verify_proof!(proof, v2)
    }
  end

  def test_verify_success_v1
    padlock = build_padlock(v1_app)
    proof = build_proof(v1_app, padlock)

    assert_equal v1_app.verify, subject.verify_proof!(proof, v1)
  end

  def test_verify_success_v2_default_fuzz
    nonce = timestamp_nonce(-6, :minutes)
    padlock = build_padlock(v2_app, nonce: nonce)
    proof = build_proof(v2_app, padlock, version: 2, nonce: nonce)

    assert_equal v2_app.verify, subject.verify_proof!(proof, v2)
  end

  def test_verify_success_v2_custom_fuzz
    nonce = timestamp_nonce(-2, :minutes)
    padlock = build_padlock(v2_app(300), nonce: nonce)
    proof = build_proof(v2_app, padlock, version: 2, nonce: nonce)

    assert_equal v2_app.verify, subject.verify_proof!(proof, v2)
  end

  def test_verify_fail_on_different_app_ids
    padlock = build_padlock(v1_app, id: "00000000-0000-0000-0000-000000000000")
    proof = build_proof(v1_app, padlock, id: "00000000-0000-0000-0000-000000000000")

    assert_exception_message("proof and app do not match") {
      subject.verify_proof!(proof, v1)
    }
  end

  def test_verify_fail_on_bad_padlock
    padlock = build_padlock(v1_app, nonce: "foo")
    proof = build_proof(v1_app, padlock)

    assert_nil subject.verify_proof!(proof, v1)
  end
end
