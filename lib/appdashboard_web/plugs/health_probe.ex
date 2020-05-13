defmodule AppDashboardWeb.Plugs.HealthProbe do

  import Plug.Conn

  def init(path \\ "/_healthz") do
    # initialize options
    {path}
  end

  def call(%Plug.Conn{request_path: path} = conn, {endpoint_path}) do
    case path do
      ^endpoint_path ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, "OK")
        |> halt
      _ -> conn
    end
  end

end
