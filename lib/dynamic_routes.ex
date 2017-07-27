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

  def new(table_name) do
    :ets.new(table_name, [:named_table, :set, :public, keypos: 2])
  end

  @doc """
  Registers a route for later lookup
  """
  def register(tab, {host, path, plugs, opts}) do
    register(tab, host, path, plugs, opts)
  end

  def register(tab, {_, _, _, _, _, _} = route) do
    true = :ets.insert(tab, route)
  end

  @doc """
  Registers a route for later lookup
  """
  def register(tab, host, path, plugs, opts, strip_path \\ true, proxy_path \\ []) do
    register(tab, {host, path, plugs, opts, strip_path, proxy_path})
  end

  @doc """
  Unregisters a route given its host and path
  """
  def unregister(tab, host, path) do
    true = :ets.match_delete(tab, {host, path, :_, :_, :_, :_})
  end

  @doc """
  Unregisters all routes for a give table
  """
  def unregister_all(tab) do
    :ets.delete_all_objects(tab)
  end

  def init([tab: tab]), do: tab

  @doc """
  Returns the route in registered routes that matches a path as a list (which
  is how plug conns reperesent them internally). Will return `nil`
  if no routes are found.
  
  ## Examples

      iex> Heimdall.DynamicRoutes.register(:some_table, "localhost", ["test", "path"], [], [])
      true
      iex> Heimdall.DynamicRoutes.lookup_path(:some_table, "localhost", ["test", "path"])
      {"localhost", ["test", "path"], [], [], true, []}

      iex> Heimdall.DynamicRoutes.register(:some_table, "localhost", ["test", "path"], [], [])
      true
      iex> Heimdall.DynamicRoutes.lookup_path(:some_table, "localhost", ["test", "path", "but", "longer"])
      {"localhost", ["test", "path"], [], [], true, []}
  """
  def lookup_path(tab, host, conn_path) do
    pattern = match_spec_patterns(host, conn_path)
    :ets.select(tab, pattern)
    |> Enum.sort_by(fn {_, path, _, _, _, _} -> -length(path) end) # Take the most specific (longest) paths first
    |> List.first
  end

  defp match_spec_patterns(host, path) do
    # This is Erlang Match Spec, I know it's weird
    # but it's basically a function pattern match
    # that follows the pattern [{pattern, guards, return}, ...]
    # http://erlang.org/doc/apps/erts/match_spec.html
    # 
    # Here we're saying match anything with the host
    # and any part of the path as a prefix
    path
    |> Enum.scan([], &(&2 ++ [&1])) # Enumerates possible path prefixes to match
    |> (fn p -> if length(p) == 0, do: [[]], else: p end).() # Handle if the list is empty
    |> Enum.flat_map(fn prefix -> [ # Generate match specs
      {{host, prefix, :_, :_, :_, :_}, [], [:"$_"]} # Will only match this prefix
    ] end)
  end

  def call(conn, tab) do
    case lookup_path(tab, conn.host, conn.path_info) do
      {_, path, plugs, opts, strip_path, proxy_path} ->
        new_conn  = if strip_path do
          {base, new_path} = Enum.split(conn.path_info, length(path))
          %{ conn | path_info: proxy_path ++ new_path, script_name: conn.script_name ++ base }
        else
          %{ conn | path_info: proxy_path ++ conn.path_info }
        end
        wrap_plugs(plugs, ForwardRequest).(new_conn, opts)
      _ -> 
        send_resp(conn, 404, "no routes found")
    end
  end
end
