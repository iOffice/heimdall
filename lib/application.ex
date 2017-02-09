defmodule Heimdall.Application do
  @moduledoc false

  use Application
  alias Heimdall.Marathon.BingeWatch

  def main(_args) do
    :timer.sleep(:infinity)
  end

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    port = Application.get_env(:heimdall, :port, 4000)
    port = if is_binary(port), do: String.to_integer(port), else: port

    Heimdall.DynamicRoutes.new(:heimdall_routes)

    marathon_url = Application.fetch_env!(:heimdall, :marathon_url)
    register_marathon = Application.fetch_env!(:heimdall, :register_marathon)
    bingewatch_sup =
      if register_marathon do
        [supervisor(BingeWatch.Supervisor, [[marathon_url: marathon_url]], restart: :temporary)]
      else
        []
      end

    children = [
      Plug.Adapters.Cowboy.child_spec(:http, Heimdall.Router, [], port: port)
    ] ++ bingewatch_sup

    opts = [strategy: :one_for_one, name: Heimdall.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
