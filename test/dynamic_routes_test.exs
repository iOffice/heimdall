defmodule Heimdall.Test.DynamicRoutes do
  use ExUnit.Case, async: true
  use Plug.Test

  import Plug.Test
  import Mock

  alias Heimdall.DynamicRoutes

  setup_all do
    # Setup table for doctests
    table_name = :some_table
    ^table_name = DynamicRoutes.new(table_name)
    :ok
  end

  setup context do
    table_name = context.test
    ^table_name = DynamicRoutes.new(table_name)
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

  defmodule OptsPlug do
    def init(opts), do: opts

    def call(conn, opts) do
      conn
      |> assign(:opts, opts)
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
      DynamicRoutes.register(tab, "localhost", ["test"], [Heimdall.Test.DynamicRoutes.TestPlug1], [])
      with_forward_mock do
        conn =
          :get
          |> conn("http://localhost/test")
          |> DynamicRoutes.call(tab)
        assert conn.assigns[:test1] == "test"
      end
    end

    test "after register and unregister all returns 404", %{tab: tab} do
      DynamicRoutes.register(tab, "localhost", ["test"], [Heimdall.Test.DynamicRoutes.TestPlug1], [])
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
      DynamicRoutes.register(tab, "localhost", ["test"], [Heimdall.Test.DynamicRoutes.TestPlug1], [])
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
      DynamicRoutes.register(tab, "localhost", ["test1"], [Heimdall.Test.DynamicRoutes.TestPlug1], [])
      DynamicRoutes.register(tab, "localhost", ["test2"], [Heimdall.Test.DynamicRoutes.TestPlug2], [])
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
      DynamicRoutes.register(tab, "localhost", ["test"], plugs, [])
      with_forward_mock do
        conn =
          :get
          |> conn("http://localhost/test")
          |> DynamicRoutes.call(tab)
        assert conn.assigns[:test1] == "test"
      end
    end

    test "strips the path that it matches", %{tab: tab} do
      DynamicRoutes.register(tab, "localhost", ["test"], [], [])
      with_forward_mock do
        conn =
          :get
          |> conn("http://localhost/test")
          |> DynamicRoutes.call(tab)
        assert conn.path_info == []
      end
    end

    test "leaves the path after what it matched", %{tab: tab} do
      DynamicRoutes.register(tab, "localhost", ["test"], [], [])
      with_forward_mock do
        conn =
          :get
          |> conn("http://localhost/test/another/path")
          |> DynamicRoutes.call(tab)
        assert conn.path_info == ["another", "path"]
      end
    end

    test "matched host with no routes should give 404", %{tab: tab} do
      DynamicRoutes.register(tab, "localhost", ["test"], [], [])
      with_forward_mock do
        conn =
          :get
          |> conn("http://localhost/wrong-path")
          |> DynamicRoutes.call(tab)
        assert conn.status == 404
      end
    end

    test "works with a configuration of / (root route)", %{tab: tab} do
      DynamicRoutes.register(tab, "localhost", [], [TestPlug2], [])
      with_forward_mock do
        conn =
          :get
          |> conn("http://localhost/")
          |> DynamicRoutes.call(tab)
        assert conn.assigns[:test2] == "test"
      end
    end

    test "appends proxy path to beginning of matched request", %{tab: tab} do
      DynamicRoutes.register(tab, "localhost", ["path"], [TestPlug2], [], true, ["proxy"])
      with_forward_mock do
        conn =
          :get
          |> conn("http://localhost/path")
          |> DynamicRoutes.call(tab)
        assert conn.path_info == ["proxy"]
      end
    end

    test "appends proxy path before at the begging without stripping path", %{tab: tab} do
      DynamicRoutes.register(tab, "localhost", ["path"], [TestPlug2], [], false, ["proxy"])
      with_forward_mock do
        conn =
          :get
          |> conn("http://localhost/path")
          |> DynamicRoutes.call(tab)
        assert conn.path_info == ["proxy", "path"]
      end
    end

    test "Merges global_opts keyword list with tab's opts keyword list", %{tab: tab} do
      DynamicRoutes.register(tab, "localhost", ["path"], [OptsPlug], [test2: "right", overwrite: "right"], false, [])
      with_forward_mock do
        conn =
          :get
          |> conn("http://localhost/path")
          |> DynamicRoutes.call(tab)
        # The first test comes from config/test.exs
        assert conn.assigns[:opts] == [test_opt: "this is a test option", test2: "right", overwrite: "right"]
      end
    end
  end

  describe "lookup_path" do
    test "gives a route if provided path is the same as the route path", %{tab: tab} do
      path = ["test", "some", "path"]
      route = {"localhost", path, [], [], true, []}
      DynamicRoutes.register(tab, route)
      result = DynamicRoutes.lookup_path(tab, "localhost", path)
      assert route == result
    end

    test "gives a route if path has additional parts", %{tab: tab} do
      route_path = ["test", "some", "path"]
      longer_path = route_path ++ ["with", "some", "more"]
      route = {"localhost", route_path, [], [], true, []}
      DynamicRoutes.register(tab, route)
      result = DynamicRoutes.lookup_path(tab, "localhost", longer_path)
      assert route == result
    end

    test "gives :no_routes if no path doesn't match", %{tab: tab} do
      route_path = ["test", "some", "path"]
      req_path = ["test", "some", "wrong", "path"]
      route = {"localhost", route_path, [], []}
      DynamicRoutes.register(tab, route)
      result = DynamicRoutes.lookup_path(tab, "localhost", req_path)
      assert result == nil
    end

    test "matches most specific path first", %{tab: tab} do
      wrong_path = ["test", "some", "path"]
      right_path = ["test", "some", "path", "but", "more", "specific"]
      req_path = right_path ++ ["extra"]
      expected = {"localhost", right_path, [], [], true, []}
      routes = [
        {"localhost", wrong_path, [], []},
        expected
      ]
      Enum.each(routes, &DynamicRoutes.register(tab, &1))
      result = DynamicRoutes.lookup_path(tab, "localhost", req_path)
      assert result == expected
    end
  end
end
