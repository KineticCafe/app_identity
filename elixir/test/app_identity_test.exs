defmodule AppIdentityTest do
  use AppIdentity.Case, async: true
  doctest AppIdentity

  for version <- AppIdentity.Versions.supported() do
    test "generate v#{version} proof", context do
      app_config = context[unquote(version)]

      assert {:ok, proof} = AppIdentity.generate_proof(app_config)

      assert_generate_proof_telemetry_span(app_config, proof: proof)

      case unquote(version) do
        1 -> assert [_, _, _] = decode_to_parts(proof)
        _ -> assert [_, _, _, _] = decode_to_parts(proof)
      end
    end

    test "generate valid v#{version} proof", context do
      app_config = context[unquote(version)]
      app = AppIdentity.App.new!(app_config)

      assert {:ok, proof} = AppIdentity.generate_proof(app_config)

      assert_generate_proof_telemetry_span(app_config, proof: proof)

      assert {:ok, verified(app)} == AppIdentity.verify_proof(proof, app_config)

      assert_verify_proof_telemetry_span(app, proof)
    end
  end

  test "verify fails if not base64", %{v1: v1} do
    assert :error == AppIdentity.verify_proof("not base64", v1)
    assert_verify_proof_telemetry_span(v1, "not base64", error: "cannot decode proof string")
  end

  test "verify fail on insufficent parts", %{v1: v1} do
    proof = Base.url_encode64("a:b")

    assert :error == AppIdentity.verify_proof(proof, v1)

    assert_verify_proof_telemetry_span(v1, proof,
      error: "proof must have 3 parts (version 1) or 4 parts (any version)"
    )
  end

  test "verify fail on bad v1 nonce", %{v1: v1, v1_app: v1_app} do
    padlock = build_padlock(v1_app, nonce: "n:once")
    proof = build_proof(v1_app, padlock, nonce: "n:once")

    assert :error == AppIdentity.verify_proof(proof, v1)

    assert_verify_proof_telemetry_span(v1, proof,
      error: "version cannot be converted to a positive integer"
    )
  end

  test "verify fail on bad v2 nonce format", %{v1: v1, v1_app: v1_app} do
    padlock = build_padlock(v1_app)
    proof = build_proof(v1_app, padlock, version: 2)

    assert :error == AppIdentity.verify_proof(proof, v1)
    assert_verify_proof_telemetry_span(v1, proof, error: "nonce does not look like a timestamp")
  end

  test "verify fail on v2 nonce out of fuzz", %{v1: v1, v1_app: v1_app} do
    nonce = timestamp_nonce(-11, :minutes)
    padlock = build_padlock(v1_app, nonce: nonce)
    proof = build_proof(v1_app, padlock, version: 2, nonce: nonce)

    assert :error == AppIdentity.verify_proof(proof, v1)
    assert_verify_proof_telemetry_span(v1, proof, error: "nonce is invalid")
  end

  test "verify fail on v1 nonce for v2 app", %{v2: v2, v2_app: v2_app} do
    padlock = build_padlock(v2_app, version: 1)
    proof = build_proof(v2_app, padlock, version: 1)

    assert :error == AppIdentity.verify_proof(proof, v2)
    assert_verify_proof_telemetry_span(v2, proof, error: "proof and app version mismatch")
  end

  for padlock_case <- [:upper, :lower] do
    test "verify success v1 (padlock case #{padlock_case})", %{v1: v1, v1_app: v1_app} do
      padlock = build_padlock(v1_app, case: unquote(padlock_case))

      proof = build_proof(v1_app, padlock)

      assert {:ok, verified(v1_app)} == AppIdentity.verify_proof(proof, v1)
      assert_verify_proof_telemetry_span(v1, proof)
    end

    test "verify success v2 default fuzz (padlock case #{padlock_case})", %{
      v2: v2,
      v2_app: v2_app
    } do
      nonce = timestamp_nonce(-6, :minutes)

      padlock = build_padlock(v2_app, nonce: nonce, case: unquote(padlock_case))

      proof = build_proof(v2_app, padlock, version: 2, nonce: nonce)

      assert {:ok, verified(v2_app)} == AppIdentity.verify_proof(proof, v2)
      assert_verify_proof_telemetry_span(v2, proof)
    end

    test "verify success v2 custom fuzz (padlock case #{padlock_case})" do
      v2 = v2(fuzz: 300)
      {:ok, v2_app} = AppIdentity.App.new(v2)

      nonce = timestamp_nonce(-2, :minutes)
      padlock = build_padlock(v2_app, nonce: nonce, case: unquote(padlock_case))
      proof = build_proof(v2_app, padlock, version: 2, nonce: nonce)

      assert verified(v2_app) == AppIdentity.verify_proof!(proof, v2)

      assert_verify_proof_telemetry_span(v2, proof)
    end
  end

  test "verify fail on different app ids", %{v1: v1, v1_app: v1_app} do
    padlock = build_padlock(v1_app, id: "00000000-0000-0000-0000-000000000000")
    proof = build_proof(v1_app, padlock, id: "00000000-0000-0000-0000-000000000000")

    assert :error == AppIdentity.verify_proof(proof, v1)
    assert_verify_proof_telemetry_span(v1, proof, error: "proof and app do not match")
  end

  test "verify fail on bad padlock", %{v1: v1, v1_app: v1_app} do
    padlock = build_padlock(v1_app, nonce: "foo")
    proof = build_proof(v1_app, padlock)

    assert {:ok, nil} == AppIdentity.verify_proof(proof, v1)

    assert_verify_proof_telemetry_span(v1, proof, app: :none)
  end

  test "verify fail on non-hex padlock", %{v1: v1, v1_app: v1_app} do
    padlock =
      v1_app
      |> build_padlock()
      |> String.replace(~r/[A-F]/i, "z")

    proof = build_proof(v1_app, padlock)

    assert :error == AppIdentity.verify_proof(proof, v1)

    assert_verify_proof_telemetry_span(v1, proof, error: "padlock must be a hex string value")
  end
end
