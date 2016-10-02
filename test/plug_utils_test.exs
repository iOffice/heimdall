defmodule Heimdall.PlugUtilsTest do
  use ExUnit.Case
  use Plug.Test

  import Plug.Conn
  import Heimdall.Util.PlugUtils

  defmodule TestWrapPlugOne do
    def init(opts), do: opts

    def call(conn, opts) do
      conn
      |> assign(:test1, opts)
    end
  end

  defmodule TestWrapPlugTwo do
    def init(opts), do: opts

    def call(conn, opts) do
      conn
      |> assign(:test2, opts)
    end
  end

  test "wrap_plugs for a list of module plugs returns a function plug of both" do
    conn = conn(:get, "http://test.com/")
    new_plug = wrap_plugs([TestWrapPlugTwo], TestWrapPlugOne)
    new_conn = new_plug.(conn, "test")
    assert new_conn.assigns[:test1] == "test"
    assert new_conn.assigns[:test2] == "test"
  end

  defmodule TestInitPlug do
    def init([test: test]), do: test

    def call(conn, opts) do
      conn
      |> assign(:test, opts)
    end
  end

  test "wrap_plugs respects a module plug's init function" do
    conn = conn(:get, "http://test.com/")
    new_plug = wrap_plugs([TestInitPlug], fn conn, opts -> conn end)
    new_conn = new_plug.(conn, [test: "test"])
    assert new_conn.assigns[:test] == "test"
  end

  test "wrap_plugs respects a module plug's init function as start param" do
    conn = conn(:get, "http://test.com/")
    new_plug = wrap_plugs([fn conn, opts -> conn end], TestInitPlug)
    new_conn = new_plug.(conn, [test: "test"])
    assert new_conn.assigns[:test] == "test"
  end

  test "wrap_plugs works for two function plugs" do
    conn = conn(:get, "http://test.com/")
    new_plug = wrap_plugs([&TestWrapPlugTwo.call/2], &TestWrapPlugOne.call/2)
    new_conn = new_plug.(conn, "test")
    assert new_conn.assigns[:test1] == "test"
    assert new_conn.assigns[:test2] == "test"
  end

  test "wrap_plug fails for two non plug params" do
    assert_raise MatchError, "no match of right hand side value: {false, false}", fn ->
      wrap_plug("test1", "test2")
    end
  end

  test "wrap_plug fails for one non plug params" do
    assert_raise MatchError, "no match of right hand side value: false", fn ->
      wrap_plug("test1", fn c, o -> c end)
    end
  end

  test "wrap_plug fails for another non plug params" do
    assert_raise MatchError, "no match of right hand side value: false", fn ->
      wrap_plug(fn c, o -> c end, "test1")
    end
  end
end
