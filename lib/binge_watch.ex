defmodule Heimdall.BingeWatch do
  import Plug.Conn
  alias Heimdall.DynamicRoutes

  def init(opts) do
    opts
  end

  defp string_to_module(module_string) do
    String.to_existing_atom("Elixir." <> module_string)
  end

  def build_route(app) do
    host = get_in(app, ["labels", "heimdall.host"])
    path = get_in(app, ["labels", "heimdall.path"])
    opts = get_in(app, ["labels", "heimdall.options"])
    filtersString = get_in(app, ["labels", "heimdall.filters"])
    {:ok, filters} = Poison.decode(filtersString)
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
        IO.puts("Request to Marathon failed: #{status} #{body}")
        {:error, ""}
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts("Request to Marathon failed: " <> reason)
        {:error, ""}
    end
  end

  defp decode_apps(http) do
    case http do
      {:ok, json} ->
        case Poison.decode(json) do
          {:ok, decoded} ->
            get_in(decoded, ["apps"])
          {:error, reason} ->
            IO.puts("Failed to decode JSON from marathon: " <> reason)
            {:ok, []}
        end
      {:error, _} -> {:ok, []}
    end
  end

  defp register_routes(routes) do
    DynamicRoutes.unregister_all(:heimdall_routes)
    Enum.map routes, fn {host, path, plug, opts} ->
      DynamicRoutes.register(:heimdall_routes, host, path, plug, opts)
    end
    routes
  end

  defp reload_marathon_config(marathon_url) do
    marathon_url <> "/v2/apps"
    |> request_apps
    |> decode_apps
    |> build_routes
    |> register_routes
  end

  def call(conn, opts) do
    marathon_url = Application.get_env(:heimdall, :marathon_url, "http://localhost:8080")
    routes = reload_marathon_config(marathon_url)

    conn
    |> send_resp(200, "ok, routes created: #{inspect(routes)}")
  end
end
