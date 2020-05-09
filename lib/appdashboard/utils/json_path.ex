defmodule AppDashboard.Utils.JSONPath do

  def compile(path), do: {:ok, {:json_path, path}}

  def query(map, {:json_path, path}) do
    try do
      Warpath.query(map, path)
    rescue
      ex -> {:error, ex}
    end
  end

end
