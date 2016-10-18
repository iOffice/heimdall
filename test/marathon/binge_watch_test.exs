defmodule Heimdall.Test.BingeWatch do
  use ExUnit.Case, async: true
  use Plug.Test
  import Heimdall.Test.Util

  alias Heimdall.Marathon.BingeWatch

  defmodule TestModule do
    def test(), do: "test"
  end

  defmodule TestPlug do
    def init(opts), do: opts
    def call(conn, _opts), do: conn
  end

  test "string_to_module gives a module atom if correct" do
    mod = BingeWatch.string_to_module("Heimdall.Test.BingeWatch.TestModule")
    assert mod.test == "test"
  end

  test "string_to_module raises error if module is invalid" do
    assert_raise ArgumentError, "argument error", fn ->
      BingeWatch.string_to_module("FakeUnrealModule")
    end
  end

  test "call retireves apps from marathon and registers them" do
    app_response = File.read!("test/marathon/app_response.json")
    response = {:ok, %HTTPoison.Response{status_code: 200, body: app_response}}
    with_request_response response do
      conn = :get
      |> conn("http://localhost:4000/marathon-callback")
      |> BingeWatch.call([])

      assert String.contains?(conn.resp_body, "/test-app")
    end
  end
end
