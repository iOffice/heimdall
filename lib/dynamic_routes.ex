defmodule Heimdall.DynamicRoutes do
  import Rackla
  import Plug.Conn

  defmodule AddApplicationHeader do
    def init(opts), do: opts

    def call(conn, opts) do
      conn
      |> put_req_header("x-application-code", "HEIMDALLTEST")
    end
  end

  def default_proxy_plug(conn, opts) do
    {_, {:ok, forward_request}} = incoming_request_conn(conn)
    query_string =  if conn.query_string != "", do: "?#{conn.query_string}", else: ""
    new_url =
      "#{Atom.to_string(conn.scheme)}://#{conn.host}:#{8081}#{conn.request_path}#{query_string}"

    forward_request
    |> Map.put(:url, new_url)
    |> request
    |> response
  end

  def register(tab, host, path, plugs, opts) do
    true = :ets.insert(tab, {host, path, plugs, opts})
  end

  def unregister(tab, host, path, plugs) do
    true = :ets.match_delete(tab, {host, path, plugs, :_})
  end

  def unregister_all(tab) do
    :ets.delete_all_objects(tab)
  end

  def init([tab: tab]), do: tab

  def call(conn, tab) do
    case :ets.match_object(tab, {conn.host, conn.request_path, :_, :_}) do
      [{host, path, plugs, opts}] -> wrap_plugs(plugs).(conn, opts)
      [] -> send_resp(conn, 404, "no routes found")
    end
  end


  defp wrap_plug(current, next) do
    (fn conn, opts -> next.(current.(conn, opts), opts) end)
  end

  defp convert_plug(plug) when is_function(plug) do
    plug
  end

  defp convert_plug(plug) when is_atom(plug) do
    &plug.call/2
  end

  defp wrap_plugs(plugs) do
    plugs
    |> Enum.map(&convert_plug/1)
    |> Enum.reduce(&default_proxy_plug/2, &wrap_plug/2)
  end

end
