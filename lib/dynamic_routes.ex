defmodule Heimdall.DynamicRoutes do
  def register(tab, host, path, plug, opts) do
    true = :ets.insert(tab, {host, path, plug, opts})
  end

  def unregister(tab, host, path, plug) do
    true = :ets.match_delete(tab, {host, path, plug, :_})
  end

  def init([tab: tab]), do: tab

  def call(conn, tab) do
    case :ets.match_object(tab, {conn.host, conn.request_path, :_, :_}) do
      [{host, path, plug, opts}] -> plug.call(conn, plug.init(opts))
      [] -> conn
    end
  end
end
