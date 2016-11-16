defmodule Heimdall.Test.DynamicRoutes do
  use ExUnit.Case, async: true
  use Plug.Test

  import Plug.Test
  import Mock

  alias Heimdall.DynamicRoutes

  setup context do
    table_name = context.test
    ^table_name = :ets.new(table_name, [:named_table, :bag, :public])
    {:ok, tab: context.test}
  end

  doctest Heimdall.DynamicRoutes

  defmodule TestPlug1 do
    def init(opts), do: opts

    def call(conn, _opts) do
      conn
      |> assign(:test1, "test")
    end
  end

  defmodule TestPlug2 do
    def init(opts), do: opts

    def call(conn, _opts) do
      conn
      |> assign(:test2, "test")
    end
  end

  defmodule MockForwardRequest do
    def init(opts), do: opts
    def call(conn, _opts), do: conn
  end

  defmacro with_forward_mock(block) do
    quote do
      with_mock Heimdall.Plug.ForwardRequest, [call: fn conn, _opts -> conn end, init: fn opts -> opts end] do
        unquote(block)
      end
    end
  end

  describe "call" do
    test "without routes gives 404", %{tab: tab} do
      conn =
        :get
        |> conn("http://test.com/")
        |> DynamicRoutes.call(tab)
      assert conn.status == 404
    end

    test "after register for a route calls the registered plug", %{tab: tab} do
      DynamicRoutes.register(tab, "localhost", ["test"], [Heimdall.Test.DynamicRoutes.TestPlug1], {})
      with_forward_mock do
        conn =
          :get
          |> conn("http://localhost/test")
          |> DynamicRoutes.call(tab)
        assert conn.assigns[:test1] == "test"
      end
    end

    test "after register and unregister all returns 404", %{tab: tab} do
      DynamicRoutes.register(tab, "localhost", ["test"], [Heimdall.Test.DynamicRoutes.TestPlug1], {})
      DynamicRoutes.unregister_all(tab)
      with_forward_mock do
        conn =
          :get
          |> conn("http://localhost/test")
          |> DynamicRoutes.call(tab)
        assert conn.assigns[:test1] != "test"
        assert conn.status == 404
      end
    end

    test "after register and unregister of route returns 404", %{tab: tab} do
      DynamicRoutes.register(tab, "localhost", ["test"], [Heimdall.Test.DynamicRoutes.TestPlug1], {})
      DynamicRoutes.unregister(tab, "localhost", ["test"])
      with_forward_mock do
        conn =
          :get
          |> conn("http://localhost/test")
          |> DynamicRoutes.call(tab)
        assert conn.assigns[:test1] != "test"
        assert conn.status == 404
      end
    end

    test "finds correct route when there are two routes", %{tab: tab} do
      DynamicRoutes.register(tab, "localhost", ["test1"], [Heimdall.Test.DynamicRoutes.TestPlug1], {})
      DynamicRoutes.register(tab, "localhost", ["test2"], [Heimdall.Test.DynamicRoutes.TestPlug2], {})
      with_forward_mock do
        conn =
          :get
          |> conn("http://localhost/test2")
          |> DynamicRoutes.call(tab)
        assert conn.assigns[:test2] == "test"
      end
    end

    test "works when there are multipe plugs", %{tab: tab} do
      plugs = [Heimdall.Test.DynamicRoutes.TestPlug1, Heimdall.Test.DynamicRoutes.TestPlug2]
      DynamicRoutes.register(tab, "localhost", ["test"], plugs, {})
      with_forward_mock do
        conn =
          :get
          |> conn("http://localhost/test")
          |> DynamicRoutes.call(tab)
        assert conn.assigns[:test1] == "test"
      end
    end

    test "strips the path that it matches", %{tab: tab} do
      DynamicRoutes.register(tab, "localhost", ["test"], [], {})
      with_forward_mock do
        conn =
          :get
          |> conn("http://localhost/test")
          |> DynamicRoutes.call(tab)
        assert conn.path_info == []
      end
    end

    test "leaves the path after what it matched", %{tab: tab} do
      DynamicRoutes.register(tab, "localhost", ["test"], [], {})
      with_forward_mock do
        conn =
          :get
          |> conn("http://localhost/test/another/path")
          |> DynamicRoutes.call(tab)
        assert conn.path_info == ["another", "path"]
      end
    end

    test "matched host with no routes should give 404", %{tab: tab} do
      DynamicRoutes.register(tab, "localhost", ["test"], [], {})
      with_forward_mock do
        conn =
          :get
          |> conn("http://localhost/wrong-path")
          |> DynamicRoutes.call(tab)
        assert conn.status == 404
      end
    end
  end

  describe "lookup_path" do
    test "gives a route if provided path is the same as the route path" do
      path = ["test", "some", "path"]
      route = {"localhost", path, [], []}
      result = DynamicRoutes.lookup_path([route], path)
      assert route == result
    end

    test "gives a route if path has additional parts" do
      route_path = ["test", "some", "path"]
      longer_path = route_path ++ ["with", "some", "more"]
      route = {"localhost", route_path, [], []}
      result = DynamicRoutes.lookup_path([route], longer_path)
      assert route == result
    end

    test "gives :no_routes if no path doesn't match" do
      route_path = ["test", "some", "path"]
      req_path = ["test", "some", "wrong", "path"]
      route = {"localhost", route_path, [], []}
      result = DynamicRoutes.lookup_path([route], req_path)
      assert result == :no_routes
    end
  end
end
