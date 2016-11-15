defmodule Heimdall.Test.TestRouter do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/forward-test" do
    conn
    |> resp(200, "forwarded")
  end

  get "/forward-test/with/more" do
    conn
    |> resp(200, "forwarded")
  end

  get "/test" do
    conn
    |> resp(200, "ok")
  end

  get "/test1" do
    conn
    |> resp(200, "ok")
  end

  get "/test2" do
    conn
    |> resp(200, "ok")
  end
end
