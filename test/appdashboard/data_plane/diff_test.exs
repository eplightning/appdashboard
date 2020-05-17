defmodule AppDashboard.DataPlane.DiffTest do

  use ExUnit.Case, async: true

  alias AppDashboard.DataPlane.Diff

  test "detects data snapshot differences" do
    old = %{
      {"old_env", "old_app"} => %{"var" => "val"},
      {"common_env", "common_app"} => %{"var" => "val"}
    }

    new = %{
      {"new_env", "new_app"} => %{"var" => "val2"},
      {"common_env", "common_app"} => %{"var" => "val2"}
    }

    diff = Diff.calculate_data_diff(old, new)

    assert length(diff) == 4
    assert :data_snapshot_changed in diff
    assert {:data_removed, {"old_env", "old_app"}} in diff
    assert {:data_added, {"new_env", "new_app"}} in diff
    assert {:data_changed, {"common_env", "common_app"}} in diff
  end

  test "skips unchanged data" do
    old = %{
      {"common_env", "common_app"} => %{"var" => "val"}
    }

    new = %{
      {"common_env", "common_app"} => %{"var" => "val"}
    }

    diff = Diff.calculate_data_diff(old, new)

    assert length(diff) == 0
  end

end
