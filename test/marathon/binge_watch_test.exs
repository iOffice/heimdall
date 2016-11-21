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

  doctest Heimdall.Marathon.BingeWatch

  describe "string_to_module" do
    test "gives a module atom if correct" do
      mod = BingeWatch.string_to_module("Heimdall.Test.BingeWatch.TestModule")
      assert mod.test == "test"
    end

    test "raises error if module is invalid" do
      assert_raise ArgumentError, "argument error", fn ->
        BingeWatch.string_to_module("FakeUnrealModule")
      end
    end
  end

  describe "build_route" do
    test "properly parses all given parameters" do
      labels = %{
        "heimdall.host" => "localhost",
        "heimdall.path" => "/test",
        "heimdall.options" => ~s({"forward_url": "localhost:8080/test"}),
        "heimdall.filters" => ~s(["Heimdall.Test.BingeWatch.TestPlug"])
      }
      app = %{
        "labels" => labels
      }
      expected = {
        "localhost",
        ["test"],
        [Heimdall.Test.BingeWatch.TestPlug],
        %{"forward_url" => "localhost:8080/test"}
      }
      result = BingeWatch.build_route(app)
      assert expected == result
    end

    test "handles missing labels" do
      labels = %{
        "heimdall.host" => "localhost",
        "heimdall.path" => "/test",
      }
      app = %{
        "labels" => labels
      }
      expected = {"localhost", ["test"], [], %{}}
      result = BingeWatch.build_route(app)
      assert expected == result
    end
  end

  describe "build_routes" do
    test "filters out apps that don't meet the requirements" do
      apps = [
        %{"test" => "test"},
        %{"labels" => %{}},
        %{"labels" => %{"heimdall.host" => "host"}},
        %{"labels" => %{"heimdall.path" => "path"}}
      ]
      result = BingeWatch.build_routes(apps)
      assert result == []
    end
  end

  describe "handle_info" do
    test "retireves apps from marathon and registers them on marathon change" do
      app_response = File.read!("test/marathon/app_response.json")
      response = {:ok, %HTTPoison.Response{status_code: 200, body: app_response}}
      with_request_response response do
        chunk = %HTTPoison.AsyncChunk{chunk: "test", id: make_ref}
        assert {:noreply, _state} = BingeWatch.handle_info(chunk, marathon_url: "test")
      end
    end
  end
end
