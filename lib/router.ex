defmodule Heimdall.Router do
  @moduledoc """
  The applications router plug. 

  Forwards Marathon callback events coming in from /marathon-callback
  to `Heimdall.Marathon.BingeWatch` which will update the dynamic routes.

  All other traffic gets handled by `Heimdall.DynamicRoutes`.
  """

  use Plug.Router
  alias Heimdall.Marathon.BingeWatch
  alias Heimdall.DynamicRoutes

  plug :match
  plug :dispatch


  forward "/marathon-callback", to: BingeWatch

  forward "/", to: DynamicRoutes, tab: :heimdall_routes

end
