defmodule Heimdall.Test.Plug.ForwardRequestTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Plug.Test

  alias Heimdall.Plug.ForwardRequest

  setup_all do
    {:ok, _pid} = Plug.Adapters.Cowboy.http(Heimdall.Test.TestRouter, [], port: 8088)

    on_exit fn ->
      :ok = Plug.Adapters.Cowboy.shutdown(Heimdall.Test.TestRouter.HTTP)
    end

    :ok
  end

  test "call sends request to configured forward location" do
    forward_url = %{"forward_url" => "http://localhost:8088"}
    conn =
      :get
      |> conn("http://localhost/forward-test")
      |> ForwardRequest.call(ForwardRequest.init(forward_url))

    assert conn.status == 200
    assert conn.resp_body == "forwarded"
  end

  test "call with opts sends request to passed forward location" do
    forward_url = %{"forward_url" => "http://localhost:8088"}
    conn =
      :get
      |> conn("http://wrong-place.com/forward-test")
      |> ForwardRequest.call(ForwardRequest.init(forward_url))

    assert conn.status == 200
    assert conn.resp_body == "forwarded"
  end

  test "changing the path info changes the request path" do
    forward_url = %{"forward_url" => "http://localhost:8088"}
    base_conn = conn(:get, "http://some-place.com/change/path/info/test")
    path_conn = %{ base_conn | path_info: ["forward-test"] }
    conn = path_conn |> ForwardRequest.call(ForwardRequest.init(forward_url))

    assert conn.status == 200
    assert conn.resp_body == "forwarded"
  end
end
