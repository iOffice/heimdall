defmodule Heimdall.Plug.ForwardRequest do
  import Rackla

  def init(%{"forward_url" => url}), do: [forward_url: url]
  def init(opts), do: opts

  def make_url(base, conn) do
    query_string =  if conn.query_string != "", do: "?#{conn.query_string}", else: ""
    base <> conn.request_path <> query_string <> "/"
  end

  def forward_conn(conn, forward_url) do
    {_, {:ok, forward_request}} = incoming_request_conn(conn)
    new_url = make_url(forward_url, conn)
    forward_request
    |> Map.put(:url, new_url)
    |> request
    |> response
  end

  def call(conn, [forward_url: url]) do
    forward_conn(conn, url)
  end

  def call(conn, _opts) do
    url = Application.fetch_env!(:heimdall, :default_forward_url)
    forward_conn(conn, url)
  end
end
