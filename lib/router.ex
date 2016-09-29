defmodule Heimdall.Router do
  @moduledoc false

  use Plug.Router
  import Rackla
  alias Heimdall.DynamicRoutes

  plug :match
  plug :dispatch

  defmodule ProxyPlug do
    def init(opts), do: opts

    def call(conn, opts) do
      conn.query_string
      |> request
      |> response
    end
  end


  forward "/", to: DynamicRoutes, tab: :heimdall_routes

  match _ do
    conn
    |> send_resp(404, "Endpoint not found")
  end
end
