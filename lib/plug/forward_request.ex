defmodule Heimdall.Plug.ForwardRequest do
  import Rackla

  def init(opts), do: opts

  def call(conn, _opts) do
    {_, {:ok, forward_request}} = incoming_request_conn(conn)
    forward_url = Application.fetch_env!(:heimdall, :forward_url)
    query_string =  if conn.query_string != "", do: "?#{conn.query_string}", else: ""
    new_url = forward_url <> conn.request_path <> query_string <> "/"

    forward_request
    |> Map.put(:url, new_url)
    |> request
    |> response
  end
end
