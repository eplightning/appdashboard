defmodule AppDashboard.Utils.JSONPath do

  def compile(path) when is_binary(path) and path != "", do: {:ok, {:json_path, path}}
  def compile(_), do: {:error, :not_non_empty_string}

  def query(map, {:json_path, path}) do
    try do
      Warpath.query(map, path)
    rescue
      ex -> {:error, ex}
    end
  end

end
