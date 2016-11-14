defmodule Heimdall.Marathon.BingeWatch do

  @moduledoc """
  There's a Marathon playing, and we're gonna BingeWatch it.

  This module is for handling callback events from Marathon.
  Given any event it will query all running apps, and rebuild
  the dynmaic routes based on the labels of each app.

  This module is also a plug, traffic from /marathon-callback is
  routed to `call/2` by `Heimdall.Router`
  """

  require Logger
  import Plug.Conn
  alias Heimdall.DynamicRoutes
  alias Plug.Router.Utils

  def init(opts) do
    opts
  end

  @doc """
  Converts a string to an elixir module atom. Will throw an argument
  error if the module does not exist. (There is no need to give a
  fully qualified erlang module name, just refer to it as you would
  in elixir)

  ## Examples

      iex>Heimdall.Marathon.BingeWatch.string_to_module("Heimdall.Marathon.BingeWatch")
      Heimdall.Marathon.BingeWatch
  """
  def string_to_module(module_string) do
    String.to_existing_atom("Elixir." <> module_string)
  end

  @doc """
  Builds a route given a map that represents the Marathon config
  for an app. The config must have a `labels` map, as well as a
  `heimdall.host` and `heimdall.path` in the `labels` map.

  `heimdall.filters` and `heimdall.opts` are optional, they will
  default to an empty list and tuple respectively.
  """
  def build_route(app) do
    labels = app |> Map.get("labels")
    host = labels |> Map.get("heimdall.host")
    path = labels |> Map.get("heimdall.path") |> Utils.split
    opts_string = labels |> Map.get("heimdall.options", "{}")
    filters_string = labels |> Map.get("heimdall.filters", "[]")
    {:ok, filters} = Poison.decode(filters_string)
    {:ok, opts} = Poison.decode(opts_string)
    plugs = Enum.map(filters, &string_to_module/1)
    {host, path, plugs, opts}
  end

  @doc """
  Builds a list of routest given a list of map that represent
  the Marathon app configs. It will filter out all of the apps
  that do not have a proper Heimdall configuration set up (i.e.
  they don't have a labels with `heimdall.host` and
  `heimdall.path`.
  """
  def build_routes(apps) do
    apps
    |> Enum.filter(&(&1 |> Map.has_key?("labels")))
    |> Enum.filter(&(&1 |> Map.get("labels") |> Map.has_key?("heimdall.host")))
    |> Enum.filter(&(&1 |> Map.get("labels") |> Map.has_key?("heimdall.path")))
    |> Enum.map(&build_route/1)
  end

  defp request_apps(url) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}
      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        {:error, "Request to Marathon failed: #{status} #{body}"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Request to Marathon failed: #{reason}"}
    end
  end

  defp decode_apps(result) do
    case Poison.decode(result) do
      {:ok, decoded} ->
        Map.fetch(decoded, "apps")
      {:error, _} = error -> error
    end
  end

  defp register_routes(routes) do
    DynamicRoutes.unregister_all(:heimdall_routes)
    Enum.each routes, fn {host, path, plug, opts} ->
      DynamicRoutes.register(:heimdall_routes, host, path, plug, opts)
    end
    routes
  end

  @docs """
  Reloads and register routes from Marathon.

  When called, it will make a HTTP request to Marathon to attempt
  to retrieve and decode the list of all running apps. It will
  use this list to build an internal representation of routes
  based on the config for each app, and register the routes with
  `Heimdall.DynamicRoutes` using `Heimdall.DynamicRoutes.register/5`
  """
  def reload_marathon_routes(marathon_url) do
    with url <- marathon_url <> "/v2/apps",
         {:ok, resp} <- request_apps(url),
         {:ok, apps} <- decode_apps(resp),
         routes <- build_routes(apps),
    do: {:ok, register_routes(routes)}
  end

  @docs """
  The call function that is feed traffic from /marathon-callback.

  Triggers a reload of routes from Marathon.  It will respond with
  the created routes if successful, or the reason for for failure
  otherwise.
  """
  def call(conn, _opts) do
    marathon_url = Application.fetch_env!(:heimdall, :marathon_url)
    maybe_routes = reload_marathon_routes(marathon_url)

    case maybe_routes do
      {:ok, routes} ->
        conn
        |> send_resp(200, "ok, routes created: #{inspect(routes)}")
      {:error, reason} ->
        Logger.warn "Creating routes failed: #{reason}"
        conn |> send_resp(500, "")
      _ ->
        Logger.warn "Creating routes failed for unknown reason"
        conn |> send_resp(500, "")
    end
  end
end
