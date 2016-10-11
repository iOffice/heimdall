defmodule Heimdall.Marathon.BingeWatch do
  require Logger
  import Plug.Conn
  alias Heimdall.DynamicRoutes

  def init(opts) do
    opts
  end

  def string_to_module(module_string) do
    String.to_existing_atom("Elixir." <> module_string)
  end

  defp build_route(app) do
    host = get_in(app, ["labels", "heimdall.host"])
    path = get_in(app, ["labels", "heimdall.path"])
    opts = get_in(app, ["labels", "heimdall.options"])
    filters_string = get_in(app, ["labels", "heimdall.filters"])
    {:ok, filters} = Poison.decode(filters_string)
    plugs = Enum.map(filters, &string_to_module/1)
    {host, path, plugs, opts}
  end

  defp build_routes(apps) do
    apps
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

  defp reload_marathon_routes(marathon_url) do
    with url <- marathon_url <> "/v2/apps",
         {:ok, resp} <- request_apps(url),
         {:ok, apps} <- decode_apps(resp),
         routes <- build_routes(apps),
    do: {:ok, register_routes(routes)}
  end

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
        Logger.warn "Created routes failed for unknown reason"
        conn |> send_resp(500, "")
    end
  end
end
