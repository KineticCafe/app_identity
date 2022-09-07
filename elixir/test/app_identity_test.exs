defmodule AppIdentityTest do
  use AppIdentity.Case
  doctest AppIdentity

  alias AppIdentity.Internal, as: Subject

  test "generate v1 proof", %{v1: v1} do
    assert {:ok, proof} = Subject.generate_proof(v1)
    assert [_, _, _] = decode_to_parts(proof)
  end

  test "generate valid v1 proof", %{v1: v1, v1_app: v1_app} do
    assert {:ok, proof} = Subject.generate_proof(v1)
    assert {:ok, verified(v1_app)} == Subject.verify_proof(proof, v1)
  end

  test "generate v2 proof", %{v2: v2} do
    assert {:ok, proof} = Subject.generate_proof(v2)
    assert [_, _, _, _] = decode_to_parts(proof)
  end

  test "generate valid v2 proof", %{v2: v2, v2_app: v2_app} do
    assert {:ok, proof} = Subject.generate_proof(v2)
    assert {:ok, verified(v2_app)} == Subject.verify_proof(proof, v2)
  end

  test "generate valid v3 proof", %{v3: v3, v3_app: v3_app} do
    assert {:ok, proof} = Subject.generate_proof(v3)
    assert {:ok, verified(v3_app)} == Subject.verify_proof(proof, v3)
  end

  test "generate valid v4 proof", %{v4: v4, v4_app: v4_app} do
    assert {:ok, proof} = Subject.generate_proof(v4)
    assert {:ok, verified(v4_app)} == Subject.verify_proof(proof, v4)
  end

  test "verify fails if not base64", %{v1: v1} do
    assert {:error, "cannot decode proof string"} == Subject.verify_proof("not base64", v1)
  end

  test "verify fail on insufficent parts", %{v1: v1} do
    assert {:error, "proof must have 3 parts (version 1) or 4 parts (any version)"} ==
             "a:b"
             |> Base.url_encode64()
             |> Subject.verify_proof(v1)
  end

  test "verify fail on bad v1 nonce", %{v1: v1, v1_app: v1_app} do
    padlock = build_padlock(v1_app, nonce: "n:once")
    proof = build_proof(v1_app, padlock, nonce: "n:once")

    assert {:error, "version cannot be converted to a positive integer"} ==
             Subject.verify_proof(proof, v1)
  end

  test "verify fail on bad v2 nonce format", %{v1: v1, v1_app: v1_app} do
    padlock = build_padlock(v1_app)
    proof = build_proof(v1_app, padlock, version: 2)

    assert {:error, "nonce does not look like a timestamp"} == Subject.verify_proof(proof, v1)
  end

  test "verify fail on v2 nonce out of fuzz", %{v1: v1, v1_app: v1_app} do
    nonce = timestamp_nonce(-11, :minutes)
    padlock = build_padlock(v1_app, nonce: nonce)
    proof = build_proof(v1_app, padlock, version: 2, nonce: nonce)

    assert {:error, "nonce is invalid"} == Subject.verify_proof(proof, v1)
  end

  test "verify fail on v1 nonce for v2 app", %{v2: v2, v2_app: v2_app} do
    padlock = build_padlock(v2_app, version: 1)
    proof = build_proof(v2_app, padlock, version: 1)

    assert {:error, "proof and app version mismatch"} == Subject.verify_proof(proof, v2)
  end

  test "verify success v1", %{v1: v1, v1_app: v1_app} do
    padlock = build_padlock(v1_app)
    proof = build_proof(v1_app, padlock)

    assert {:ok, verified(v1_app)} == Subject.verify_proof(proof, v1)
  end

  test "verify success v2 default fuzz", %{v2: v2, v2_app: v2_app} do
    nonce = timestamp_nonce(-6, :minutes)
    padlock = build_padlock(v2_app, nonce: nonce)
    proof = build_proof(v2_app, padlock, version: 2, nonce: nonce)

    assert {:ok, verified(v2_app)} == Subject.verify_proof(proof, v2)
  end

  test "verify success v2 custom fuzz" do
    v2 = v2(fuzz: 300)
    {:ok, v2_app} = AppIdentity.App.new(v2)

    nonce = timestamp_nonce(-2, :minutes)
    padlock = build_padlock(v2_app, nonce: nonce)
    proof = build_proof(v2_app, padlock, version: 2, nonce: nonce)

    assert {:ok, verified(v2_app)} == Subject.verify_proof(proof, v2)
  end

  test "verify fail on different app ids", %{v1: v1, v1_app: v1_app} do
    padlock = build_padlock(v1_app, id: "00000000-0000-0000-0000-000000000000")
    proof = build_proof(v1_app, padlock, id: "00000000-0000-0000-0000-000000000000")

    assert {:error, "proof and app do not match"} == Subject.verify_proof(proof, v1)
  end

  test "verify fail on bad padlock", %{v1: v1, v1_app: v1_app} do
    padlock = build_padlock(v1_app, nonce: "foo")
    proof = build_proof(v1_app, padlock)

    assert {:ok, nil} == Subject.verify_proof(proof, v1)
  end
end
