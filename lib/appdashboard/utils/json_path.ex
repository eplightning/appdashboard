defmodule AppDashboard.Utils.JSONPath do

  def compile(path) when is_binary(path) and path == "$", do: {:ok, {:json_path, "$"}}
  def compile(path) when is_binary(path) and path != "" do
    case Warpath.Expression.compile(path) do
      {:ok, expr} -> {:ok, {:warpath, expr}}
      {:error, err} -> {:error, err}
    end
  end
  def compile(_), do: {:error, :not_non_empty_string}

  def query(map, {:json_path, "$"}) do
    {:ok, map}
  end

  def query(map, {:warpath, expr}) do
    try do
      Warpath.query(map, expr)
    rescue
      ex -> {:error, ex}
    end
  end

end
