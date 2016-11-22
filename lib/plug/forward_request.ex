defmodule Heimdall.Plug.ForwardRequest do

  @moduledoc """
  This plug acts as a reverse proxy, it will forward any
  request to a configured location.

  This location can be configured either as a default
  location by setting the applications `:default_forward_url`,
  or by providing it in opts to `call/2` like `call(conn, forward_url: url)`
  """

  import Rackla
  import Plug.Conn
  require Logger

  @doc """
  Init will reshape the data coming in from
  `Heimdall.Marathon.BingeWatch`, which comes in as a map
  with the key `"forward_url"` and comes out as a list
  with the atom `:forward_url`.
  """
  def init(%{} = opts) do 
    opts
    |> Enum.into([], fn {k, v} -> {String.to_existing_atom(k), v} end)
  end
  def init(opts), do: opts

  defp build_request_path(path_info) do
    "/" <> Enum.join(path_info, "/")
  end

  defp build_query_string(query_string) do
    if query_string != "", do: "?#{query_string}", else: ""
  end

  def build_url(base, conn) do
    has_trailing_slash = String.ends_with?(conn.request_path, "/")
    path_suffix = if has_trailing_slash, do: "/", else: ""
    query_string = build_query_string(conn.query_string)
    request_path = build_request_path(conn.path_info) <> path_suffix

    base <> request_path <> query_string
  end

  defp set_headers(conn, headers) do
    Enum.reduce(headers, conn, fn({key, value}, conn) ->
      put_resp_header(conn, key, value)
    end)
  end

  defp forward_conn(conn, forward_url, opts) do
    {_, {:ok, forward_request}} = incoming_request_conn(conn)
    new_url = build_url(forward_url, conn)
    rackla_opts = [
      follow_redirect: true, 
      force_redirect: true, 
      full: true,
      receive_timeout: 10_000
    ] |> Keyword.merge(opts)
    rackla_response =
      forward_request
      |> Map.put(:url, new_url)
      |> request(rackla_opts)
      |> collect
    case rackla_response do
      %Rackla.Response{status: status, headers: headers, body: body} ->
        conn
        |> resp(status, body)
        |> set_headers(headers)
      other ->
        Logger.warn("Problem connecting to service: #{inspect(other)}\nRequest path: #{inspect(new_url)}")
        conn
        |> resp(500, "An error occured communicating with service, reason: #{inspect(other)}")
    end
  end

  @doc """
  If the conn is not already in the `:set` state,
  `call/2` will read the conn and all of its metadata and
  forward it to either the `:forward_url` specified in opts
  or the applications `:default_forward_url`.

  Otherwise call will simple return the conn.
  """
  def call(%Plug.Conn{state: :set} = conn, _opts) do
    conn
  end

  def call(conn, opts) do
    default_url = Application.fetch_env!(:heimdall, :default_forward_url)
    url = opts |> Keyword.get(:forward_url, default_url)
    forward_conn(conn, url, opts)
  end
end
