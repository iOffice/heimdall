defmodule Heimdall.Test.Plug.ForwardRequestTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Plug.Test
  import ExUnit.CaptureLog

  alias Heimdall.Plug.ForwardRequest

  setup_all do
    {:ok, _pid} = Plug.Adapters.Cowboy.http(Heimdall.Test.TestRouter, [], port: 8088)

    on_exit fn ->
      :ok = Plug.Adapters.Cowboy.shutdown(Heimdall.Test.TestRouter.HTTP)
    end

    :ok
  end

  describe "call" do
    test "sends request to configured forward location" do
      forward_url = %{"forward_url" => "http://localhost:8088"}
      conn =
        :get
        |> conn("http://localhost/forward-test")
        |> ForwardRequest.call(ForwardRequest.init(forward_url))

      assert conn.status == 200
      assert conn.resp_body == "forwarded"
    end

    test "with opts sends request to passed forward location" do
      forward_url = %{"forward_url" => "http://localhost:8088"}
      conn =
        :get
        |> conn("http://wrong-place.com/forward-test")
        |> ForwardRequest.call(ForwardRequest.init(forward_url))

      assert conn.status == 200
      assert conn.resp_body == "forwarded"
    end

    test "properly creates request with extended path" do
      forward_url = %{"forward_url" => "http://localhost:8088"}
      conn =
        :get
        |> conn("http://localhost/forward-test/with/more")
        |> ForwardRequest.call(ForwardRequest.init(forward_url))

      assert conn.status == 200
      assert conn.resp_body == "forwarded"
    end

    test "forwards headers from response" do
      forward_url = %{"forward_url" => "http://localhost:8088"}
      conn =
        :get
        |> conn("http://localhost/forward-test/headers")
        |> ForwardRequest.call(ForwardRequest.init(forward_url))

      assert conn.status == 200
      assert conn.resp_body == "forwarded"
      assert conn |> get_resp_header("x-test-forward") == ["forwarded"]
    end

    test "gives 500 if cannot connect to service" do
      forward_url = %{"forward_url" => "http://localhost:50000"}

      capture_log fn ->
        conn =
          :get
          |> conn("http://localhost/forward-test")
          |> ForwardRequest.call(ForwardRequest.init(forward_url))

        assert conn.status == 500
        assert conn.resp_body != "forwarded"
      end
    end
  end

  test "changing the path info changes the request path" do
    forward_url = %{"forward_url" => "http://localhost:8088"}
    base_conn = conn(:get, "http://some-place.com/change/path/info/test")
    path_conn = %{ base_conn | path_info: ["forward-test"] }
    conn = path_conn |> ForwardRequest.call(ForwardRequest.init(forward_url))

    assert conn.status == 200
    assert conn.resp_body == "forwarded"
  end

  test "does not forward if conn already has a response" do
    forward_url = %{"forward_url" => "http://localhost:8088"}
    conn =
      :get
      |> conn("http://localhost/forward-test")
      |> resp(200, "test")
      |> ForwardRequest.call(ForwardRequest.init(forward_url))

    assert conn.status == 200
    assert conn.resp_body != "forwarded"
  end
end
