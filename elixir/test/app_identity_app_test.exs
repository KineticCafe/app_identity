defmodule AppIdentityAppTest do
  use AppIdentity.Case

  alias AppIdentity.App

  doctest App

  test "id validation" do
    assert {:error, "id must not be nil"} = App.new(%{id: nil})
    assert {:error, "id must not be an empty string"} = App.new(%{id: ""})
    assert {:error, "id must not contain colon characters"} = App.new(%{id: "1:1"})
  end

  test "secret validation" do
    assert {:error, "secret must not be nil"} = App.new(%{id: 1, secret: nil})
    assert {:error, "secret must not be an empty binary string"} = App.new(%{id: 1, secret: ""})
    assert {:error, "secret must be a binary string value"} = App.new(%{id: 1, secret: 3})
  end

  test "version validation" do
    assert {:error, "version must not be nil"} = App.new(%{id: 1, secret: "a", version: nil})

    assert {:error, "version must be a positive integer"} =
             App.new(%{id: 1, secret: "a", version: 3.5})

    assert {:error, "version cannot be converted to a positive integer"} =
             App.new(%{id: 1, secret: "a", version: ""})

    assert {:error, "version cannot be converted to a positive integer"} =
             App.new(%{id: 1, secret: "a", version: "3.5"})
  end

  test "config validation" do
    assert {:error, "config must be nil or a map"} =
             App.new(%{id: 1, secret: "a", version: 1, config: 3})
  end
end
