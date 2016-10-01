defmodule Heimdall.Router do
  @moduledoc false

  use Plug.Router
  alias Heimdall.BingeWatch
  alias Heimdall.DynamicRoutes
  import Rackla

  plug :match
  plug :dispatch


  forward "/marathon-callback", to: BingeWatch

  forward "/", to: DynamicRoutes, tab: :heimdall_routes

end
