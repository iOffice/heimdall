defmodule Heimdall.Marathon.BingeWatch do

  @moduledoc """
  There's a Marathon playing, and we're gonna BingeWatch it.

  This module is for handling events streamed from Marathon.
  Given any event it will query all running apps, and rebuild
  the dynmaic routes based on the labels of each app.

  This module implements the `GenServer` behavour, and begins
  streaming Marathon events to itself in `start_link/0`. 
  """

  @name Heimdall.Marathon.BingeWatch

  use GenServer

  require Logger
  alias Heimdall.DynamicRoutes
  alias Plug.Router.Utils

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  def init(args) do
    state = reset_retries(args)
    GenServer.cast(@name, :connect)
    {:ok, state}
  end

  def handle_cast(:connect, state) do
    retries = Keyword.get(state, :retries)
    :timer.sleep(delay_seconds(retries))
    marathon_url = Keyword.get(state, :marathon_url)
    case connect_to_marathon(marathon_url) do
      {:ok, _} ->
        new_state = reset_retries(state)
        {:noreply, new_state}
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn "Failed to connect to Marathon: #{inspect(reason)}"
        retry_connect(state)
      {:error, reason} ->
        Logger.warn "Failed to connect to Marathon: #{inspect(reason)}"
        retry_connect(state)
    end
  end

  def handle_cast(_req, state) do
    {:noreply, state}
  end

  defp delay_seconds(retries) do
    back_off = round(:math.pow(2, retries))
    :timer.seconds(back_off)
  end

  defp increment_retries(state) do
    Keyword.update(state, :retries, 0, fn r -> r + 1 end)
  end

  defp reset_retries(state) do
    Keyword.put(state, :retries, 0)
  end

  defp retry_connect(state) do
    new_state = increment_retries(state)
    GenServer.cast(@name, :connect)
    {:noreply, new_state}
  end

  defp connect_to_marathon(marathon_url) do
    HTTPoison.get(marathon_url <> "/v2/events", %{"Accept": "text/event-stream"}, stream_to: self, recv_timeout: 15_000)
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
    with {:ok, filters} <- Poison.decode(filters_string),
         {:ok, opts} <- Poison.decode(opts_string),
         plugs = Enum.map(filters, &string_to_module/1),
    do: {host, path, plugs, opts}
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
    |> Enum.filter(&!match?({:error, _}, &1))
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
  `handle_info/2` handles responses streamed in from Marathon

  If a response from Marathon gives back anything other than 200,
  or if there is an error connecting, BingeWatch will attempt to
  reconnect with exponential back-off.

  Any chunked response other than a carriage return (which is used 
  as a keep-alive) from Marathon will trigger a reload of the
  routes config.

  Also other message to `handle_info/2` will be ignored.
  """
  def handle_info(%HTTPoison.AsyncStatus{code: 200}, state) do 
    Logger.info "Successfully connected to Marathon stream"
    new_state = reset_retries(state)
    {:noreply, new_state}
  end

  def handle_info(%HTTPoison.AsyncStatus{code: status}, state) do
    Logger.warn "Got error status code from Marathon: #{status}"
    retry_connect(state)
  end

  def handle_info(%HTTPoison.AsyncChunk{chunk: "\r\n"}, state) do
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncChunk{chunk: _chunk}, state) do
    marathon_url = Keyword.get(state, :marathon_url)
    maybe_routes = reload_marathon_routes(marathon_url)
    case maybe_routes do
      {:ok, _routes} ->
        {:noreply, state}
      {:error, reason} ->
        Logger.warn "Creating routes failed: #{inspect(reason)}"
        {:noreply, state}
      _ ->
        Logger.warn "Creating routes failed for unknown reason"
        {:noreply, state}
    end
  end

  def handle_info(%HTTPoison.AsyncEnd{}, state) do
    Logger.warn "Disconnected from Marathon, attempting to reconnect now"
    retry_connect(state)
  end

  def handle_info(%HTTPoison.Error{reason: reason}, state) do
    Logger.warn "Got error from Marathon stream: #{inspect(reason)}"
    retry_connect(state)
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
