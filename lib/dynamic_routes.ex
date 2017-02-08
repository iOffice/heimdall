defmodule Heimdall.DynamicRoutes do

  @moduledoc """
  Module for dynamically registering routes and routing requests.
  
  This is where most of the magic happens. All traffic through the
  application is routed through this plug.

  Routes are stored in an ETS table to be looked up when the plug
  is called. When called `Heimdall.DynamicRoutes` search for a route
  that matches the request, wrap all plugs in the route into one function
  and call it with the current request. The final plug in the chain will
  always be `Heimdall.Plug.ForwardRequest`
  """

  import Plug.Conn
  import Heimdall.Util.PlugUtils
  alias Heimdall.Plug.ForwardRequest

  @doc """
  Registers a route for later lookup
  """
  def register(tab, host, path, plugs, opts) do
    true = :ets.insert(tab, {host, path, plugs, opts})
  end

  @doc """
  Unregisters a route given its host and path
  """
  def unregister(tab, host, path) do
    true = :ets.match_delete(tab, {host, path, :_, :_})
  end

  @doc """
  Unregisters all routes for a give table
  """
  def unregister_all(tab) do
    :ets.delete_all_objects(tab)
  end

  def init([tab: tab]), do: tab

  @doc """
  Returns the route in given routes that matches a path as a list (which
  is how plug conns reperesent them internally). Will return `:no_routes`
  if no routes are found.
  
  ## Examples

      iex> Heimdall.DynamicRoutes.lookup_path([{"localhost", ["test", "path"], [], {}}], ["test", "path"])
      {"localhost", ["test", "path"], [], {}}

      iex> Heimdall.DynamicRoutes.lookup_path([{"localhost", ["test", "path"], [], {}}], ["test", "path", "but", "longer"])
      {"localhost", ["test", "path"], [], {}}
  """
  def lookup_path(routes, conn_path) do
    routes
    |> Enum.sort_by(fn {_, path, _, _} -> -length(path) end)
    |> Enum.find(:no_routes, fn({_, route_path, _, _}) ->
      split_path = Enum.take(conn_path, length(route_path))
      route_path == split_path
    end)
  end

  defp path_match_query(tab, host, path) do
    # This is Erlang Match Spec, I know it's weird
    # but it's basically a function pattern match
    # that follows the pattern [{pattern, guards, return}, ...]
    # http://erlang.org/doc/apps/erts/match_spec.html
    # 
    # Here we're saying match anything with the host and path
    # or anything that has the path as a prefix
    IO.inspect path
    pattern = [
      {{host, path, :_, :_}, [], [:"$_"]},
      {{host, path ++ :_, :_, :_}, [], [:"$_"]}
    ]
    result = :ets.select(tab, pattern)
    IO.inspect result
    result
  end

  def call(conn, tab) do
    case path_match_query(tab, conn.host, conn.path_info) do
      [] -> send_resp(conn, 404, "no routes found")
      routes ->
        case lookup_path(routes, conn.path_info) do
          {_, path, plugs, opts} ->
            {base, new_path} = Enum.split(conn.path_info, length(path))
            new_conn = %{ conn | path_info: new_path, script_name: conn.script_name ++ base }
            IO.inspect path
            IO.inspect base
            IO.inspect new_path
            wrap_plugs(plugs, ForwardRequest).(new_conn, opts)
          _ ->
            send_resp(conn, 404, "no routes found")
        end
    end
  end
end
