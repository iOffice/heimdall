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

  test "call without routes gives 404", %{tab: tab} do
    conn =
      :get
      |> conn("http://test.com/")
      |> DynamicRoutes.call(tab)
    assert conn.status == 404
  end

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
      with_mock Heimdall.Plug.ForwardRequest, [call: fn conn, _opts -> conn end, init: &(&1)] do
        unquote(block)
      end
    end
  end

  test "call after register for a route calls the registered plug", %{tab: tab} do
    DynamicRoutes.register(tab, "localhost", "/test", [Heimdall.Test.DynamicRoutes.TestPlug1], {})
    with_forward_mock do
      conn =
        :get
        |> conn("http://localhost/test")
        |> DynamicRoutes.call(tab)
      assert conn.assigns[:test1] == "test"
    end
  end

  test "call after register and unregister all returns 404", %{tab: tab} do
    DynamicRoutes.register(tab, "localhost", "/test", [Heimdall.Test.DynamicRoutes.TestPlug1], {})
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

  test "call after register and unregister of route returns 404", %{tab: tab} do
    DynamicRoutes.register(tab, "localhost", "/test", [Heimdall.Test.DynamicRoutes.TestPlug1], {})
    DynamicRoutes.unregister(tab, "localhost", "/test")
    with_forward_mock do
      conn =
        :get
        |> conn("http://localhost/test")
        |> DynamicRoutes.call(tab)
      assert conn.assigns[:test1] != "test"
      assert conn.status == 404
    end
  end

  test "call finds correct route when there are two routes", %{tab: tab} do
    DynamicRoutes.register(tab, "localhost", "/test1", [Heimdall.Test.DynamicRoutes.TestPlug1], {})
    DynamicRoutes.register(tab, "localhost", "/test2", [Heimdall.Test.DynamicRoutes.TestPlug2], {})
    with_forward_mock do
      conn =
        :get
        |> conn("http://localhost/test2")
        |> DynamicRoutes.call(tab)
      assert conn.assigns[:test2] == "test"
    end
  end

  test "call works when there are multipe plugs", %{tab: tab} do
    plugs = [Heimdall.Test.DynamicRoutes.TestPlug1, Heimdall.Test.DynamicRoutes.TestPlug2]
    DynamicRoutes.register(tab, "localhost", "/test", plugs, {})
    with_forward_mock do
      conn =
        :get
        |> conn("http://localhost/test")
        |> DynamicRoutes.call(tab)
      assert conn.assigns[:test1] == "test"
    end
  end
end
