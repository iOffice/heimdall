defmodule Heimdall.Test.Plug.ForwardRequestTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Plug.Test

  alias Heimdall.Plug.ForwardRequest

  setup_all do
    {:ok, _pid} = Plug.Adapters.Cowboy.http(Heimdall.Test.TestRouter, [], port: 8082)

    on_exit fn ->
      :ok = Plug.Adapters.Cowboy.shutdown(Heimdall.Test.TestRouter.HTTP)
    end

    :ok
  end

  test "call sends request to configured forward location" do
    conn =
      :get
      |> conn("http://localhost/forward-test")
      |> ForwardRequest.call([])

    assert conn.status == 200
    assert conn.resp_body == "forwarded"
  end
end
