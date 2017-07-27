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
      app = %{
        "heimdall.host" => "localhost",
        "heimdall.path" => "/test",
        "heimdall.options" => ~s({"forward_url": "localhost:8080/test"}),
        "heimdall.filters" => ~s(["Heimdall.Test.BingeWatch.TestPlug"])
      }
      expected = {
        "localhost",
        ["test"],
        [Heimdall.Test.BingeWatch.TestPlug],
        %{"forward_url" => "localhost:8080/test"},
        true,
        []
      }
      result = BingeWatch.build_route(app)
      assert expected == result
    end

    test "handles missing labels" do
      app = %{
        "heimdall.host" => "localhost",
        "heimdall.path" => "/test",
      }
      expected = {"localhost", ["test"], [], %{}, true, []}
      result = BingeWatch.build_route(app)
      assert expected == result
    end

    test "should return error when there is an error decoding filters" do
      app = %{
        "heimdall.host" => "localhost",
        "heimdall.path" => "/test",
        "heimdall.filters" => "[}"
      }
      result = BingeWatch.build_route(app)
      assert {:error, _} = result
    end

    test "should return error when there is an error decoding opts" do
      app = %{
        "heimdall.host" => "localhost",
        "heimdall.path" => "/test",
        "heimdall.options" => "[}"
      }
      result = BingeWatch.build_route(app)
      assert {:error, _} = result
    end

    test "handles strip path" do
      app = 
        %{
          "heimdall.host" => "host",
          "heimdall.path" => "/",
          "heimdall.strip_path" => "false"
        }
      result = BingeWatch.build_route(app)
      assert elem(result, 4) == false
    end

    test "handles proxy path" do
      app = 
        %{
          "heimdall.host" => "host",
          "heimdall.path" => "/",
          "heimdall.proxy_path" => "/proxy/path"
        }
      result = BingeWatch.build_route(app)
      assert elem(result, 5) == ["proxy", "path"]
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

    test "filters out apps with invalid json in options or filters" do
      baseApp =
        %{
          "heimdall.host" => "host",
          "heimdall.path" => "path"
        }
      apps = [
        %{"labels" => Map.put(baseApp, "heimdall.filters", "{]")},
        %{"labels" => Map.put(baseApp, "heimdall.options", "{]")},
      ]
      result = BingeWatch.build_routes(apps)
      assert result == []
    end

    test "turns multiple entrypoints into multiple routes" do
      app = 
        %{
          "heimdall.host" => "host",
          "heimdall.path" => "/",
          "heimdall.entrypoints" => "[{\"heimdall.host\": \"test\"}]"
        }
      results = BingeWatch.build_routes([%{"labels" => app}])
      assert length(results) == 2
    end

    test "multipe entrypoints overwrite the top level settings" do
      app = 
        %{
          "heimdall.host" => "host",
          "heimdall.path" => "/",
          "heimdall.entrypoints" => "[{\"heimdall.host\": \"test\"}]"
        }
      results = BingeWatch.build_routes([%{"labels" => app}])
      assert Enum.find(results, fn route -> elem(route, 0) == "test" end)
    end
  end

  describe "handle_info" do
    test "retireves apps from marathon and registers them on marathon change" do
      app_response = File.read!("test/marathon/app_response.json")
      response = {:ok, %HTTPoison.Response{status_code: 200, body: app_response}}
      with_request_response response do
        chunk = %HTTPoison.AsyncChunk{chunk: "test", id: make_ref()}
        assert {:noreply, _state} = BingeWatch.handle_info(chunk, marathon_url: "test")
      end
    end
  end
end
