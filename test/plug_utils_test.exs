defmodule Heimdall.PlugUtilsTest do
  use ExUnit.Case
  use Plug.Test

  import Heimdall.Util.PlugUtils

  defmodule TestPlugOne do
    def init(opts), do: opts

    def call(conn, opts) do
      conn
      |> put_req_header("test1", "test")
    end
  end

  defmodule TestPlugTwo do
    def init(opts), do: opts

    def call(conn, opts) do
      conn
      |> put_req_header("test2", "test")
    end
  end

  test "wrap_plugs takes a list of module plugs returning a composed function plug" do
    conn = conn(:get, "http://test.com/")
    new_plug = wrap_plugs([TestPlugTwo], TestPlugOne)
    new_conn = new_plug.(conn, %{})
    assert List.keyfind(new_conn.req_headers, "test1", 0) == {"test1", "test"}
    assert List.keyfind(new_conn.req_headers, "test2", 0) == {"test2", "test"}
  end
end
