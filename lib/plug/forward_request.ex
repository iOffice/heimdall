defmodule Heimdall.Plug.ForwardRequest do

  @moduledoc """
  This plug acts as a reverse proxy, it will forward any
  request to a configured location.

  This location can be configured either as a default
  location by setting the applications `:default_forward_url`,
  or by providing it in opts to `call/2` like `call(conn, forward_url: url)`
  """

  import Rackla

  @doc """
  Init will reshape the data coming in from
  `Heimdall.Marathon.BingeWatch`, which comes in as a map
  with the key `"forward_url"` and comes out as a list
  with the atom `:forward_url`.
  """
  def init(%{"forward_url" => url}), do: [forward_url: url]
  def init(opts), do: opts

  defp build_request_path(path_info) do
    "/" <> Enum.join(path_info)
  end

  defp build_query_string(query_string) do
    if query_string != "", do: "?#{query_string}", else: ""
  end

  defp build_url(base, conn) do
    query_string = build_query_string(conn.query_string)
    request_path = build_request_path(conn.path_info)

    base <> request_path <> query_string
  end

  defp forward_conn(conn, forward_url) do
    {_, {:ok, forward_request}} = incoming_request_conn(conn)
    new_url = build_url(forward_url, conn)
    forward_request
    |> Map.put(:url, new_url)
    |> request(follow_redirect: true, force_redirect: true)
    |> response
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

  def call(conn, [forward_url: url]) do
    forward_conn(conn, url)
  end

  def call(conn, _opts) do
    url = Application.fetch_env!(:heimdall, :default_forward_url)
    forward_conn(conn, url)
  end
end
