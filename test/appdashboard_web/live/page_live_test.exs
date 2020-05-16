defmodule AppDashboardWeb.PageLiveTest do
  use AppDashboardWeb.ConnCase

  import Phoenix.LiveViewTest

  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "Dashboard"
    assert render(page_live) =~ "Dashboard"
  end
end
