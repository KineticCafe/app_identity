defmodule AppIdentity.Case do
  @moduledoc """
  App Identity test cases.
  """

  use ExUnit.CaseTemplate

  import AppIdentity.Support

  using do
    quote do
      import AppIdentity.Case
      import AppIdentity.Support
    end
  end

  setup do
    v1 = v1()
    v2 = v2()
    v3 = v3()
    v4 = v4()

    %{
      1 => v1,
      2 => v2,
      3 => v3,
      4 => v4,
      :v1 => v1,
      :v1_app => elem(AppIdentity.App.new(v1), 1),
      :v2 => v2,
      :v2_app => elem(AppIdentity.App.new(v2), 1),
      :v3 => v3,
      :v3_app => elem(AppIdentity.App.new(v3), 1),
      :v4 => v4,
      :v4_app => elem(AppIdentity.App.new(v4), 1)
    }
  end

  def assert_error_reason(reason, fun) do
    assert_raise AppIdentity.AppIdentityError, reason, fun
  end
end
