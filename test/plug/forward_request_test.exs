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
end
