defmodule Heimdall.DynamicRoutesTest do
  use ExUnit.Case
  use Plug.Test

  import Plug.Test

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
end
