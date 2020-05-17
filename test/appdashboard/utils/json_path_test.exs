defmodule AppDashboard.Utils.JsonPathTest do
  use ExUnit.Case, async: true

  alias AppDashboard.Utils.JSONPath

  test "empty jsonpath" do
    assert match?({:error, _}, JSONPath.compile(""))
  end

  test "full object access" do
    {:ok, path} = JSONPath.compile("$")

    map = %{"elem" => "test"}

    assert JSONPath.query(map, path) == {:ok, map}
    assert JSONPath.query(5, path) == {:ok, 5}
    assert JSONPath.query("string", path) == {:ok, "string"}
  end

  test "existing element access" do
    {:ok, path} = JSONPath.compile("$.elem")

    map = %{"elem" => "test"}

    assert JSONPath.query(map, path) == {:ok, "test"}
  end

  test "unknown element access" do
    {:ok, path} = JSONPath.compile("$.elem")

    map = %{"elem2" => "test"}

    assert JSONPath.query(map, path) == {:ok, nil}
  end
end
