defmodule Heimdall.DynamicRoutes do
  import Plug.Conn
  import Heimdall.Util.PlugUtils
  alias Heimdall.Plug.ForwardRequest

  def register(tab, host, path, plugs, opts) do
    true = :ets.insert(tab, {host, path, plugs, opts})
  end

  def unregister(tab, host, path) do
    true = :ets.match_delete(tab, {host, path, :_, :_})
  end

  def unregister_all(tab) do
    :ets.delete_all_objects(tab)
  end

  def init([tab: tab]), do: tab

  def lookup_path(routes, conn_path) do
    Enum.find routes, {nil, nil, [], []}, fn({_, route_path, _, _}) ->
      split_path = Enum.take(conn_path, length(route_path))
      route_path == split_path
    end
  end

  def call(conn, tab) do
    case :ets.match_object(tab, {conn.host, :_, :_, :_}) do
      [] -> send_resp(conn, 404, "no routes found")
      routes ->
        {_, path, plugs, opts} = lookup_path(routes, conn.path_info)
        {base, new_path} = Enum.split(conn.path_info, length(path))
        new_conn = %{ conn | path_info: new_path, script_name: conn.script_name ++ base }
        wrap_plugs(plugs, ForwardRequest).(new_conn, opts)
    end
  end
end
