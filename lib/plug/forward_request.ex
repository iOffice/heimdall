defmodule Heimdall.Plug.ForwardRequest do
  import Rackla

  def init(%{"forward_url" => url}), do: [forward_url: url]
  def init(opts), do: opts

  def build_request_path(path_info) do
    "/" <> Enum.join(path_info)
  end

  def build_query_string(query_string) do
    if query_string != "", do: "?#{query_string}", else: ""
  end

  def build_url(base, conn) do
    query_string = build_query_string(conn.query_string)
    request_path = build_request_path(conn.path_info)

    base <> request_path <> query_string
  end

  def forward_conn(conn, forward_url) do
    {_, {:ok, forward_request}} = incoming_request_conn(conn)
    new_url = build_url(forward_url, conn)
    forward_request
    |> Map.put(:url, new_url)
    |> request(follow_redirect: true)
    |> response
  end

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
