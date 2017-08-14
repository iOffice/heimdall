defmodule Heimdall.Router do
  @moduledoc """
  The applications router plug.

  Forwards Marathon callback events coming in from /marathon-callback
  to `Heimdall.Marathon.BingeWatch` which will update the dynamic routes.

  All other traffic gets handled by `Heimdall.DynamicRoutes`.
  """

  use Plug.Router
  alias Heimdall.DynamicRoutes
  import Plug.Conn
  import Rackla

  plug :match
  plug :dispatch

  get "/heimdall-health-check" do
    resp = 
      Application.fetch_env!(:heimdall, :marathon_url) <> "/ping"
      |> request(full: true)
      |> collect
    case resp do
      %Rackla.Response{status: 200} ->
        conn
        |> resp(200, "ok")
      _other ->
        conn
        |> resp(500, "not ok")
    end
  end

  forward "/", to: DynamicRoutes, tab: :heimdall_routes

end
