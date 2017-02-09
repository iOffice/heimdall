defmodule Heimdall.Plug.NoOp do
  @moduledoc """
  A plug that does nothing.
  """

  def init(opts), do: opts
  def call(conn, _opts), do: conn
end
