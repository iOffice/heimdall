defmodule Heimdall.Router do
  @moduledoc false

  use Plug.Router
  import Rackla

  plug :match
  plug :dispatch

  get "/proxy" do
    conn.query_string
    |> request
    |> response
  end

  match _ do
    conn
    |> send_resp(404, "Endpoint not found")
  end
end
