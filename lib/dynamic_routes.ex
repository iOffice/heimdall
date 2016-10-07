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

  def call(conn, tab) do
    case :ets.match_object(tab, {conn.host, conn.request_path, :_, :_}) do
      [{_, _, plugs, opts}] -> wrap_plugs(plugs, ForwardRequest).(conn, opts)
      [] -> send_resp(conn, 404, "no routes found")
    end
  end
end
