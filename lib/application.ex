defmodule Heimdall.Application do
  @moduledoc false

  use Application

  def main(_args) do
    :timer.sleep(:infinity)
  end

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    port = Application.get_env(:heimdall, :port, 4000)
    port = if is_binary(port), do: String.to_integer(port), else: port

    marathon_url = Application.fetch_env!(:heimdall, :marathon_url)

    :ets.new(:heimdall_routes, [:named_table, :bag, :public])

    register_marathon = Application.fetch_env!(:heimdall, :register_marathon)

    {:ok, hostname} = :inet.gethostname
    default_callback = "http://#{hostname}:#{port}"
    callback_url = Application.get_env(:heimdall, :marathon_callback_url, default_callback)

    register_worker = if register_marathon do
      [worker(
        Task,
        [Heimdall.Marathon.RegisterCallback, :register, [marathon_url, callback_url]],
        restart: :temporary)]
    else
      []
    end

    children = [
      Plug.Adapters.Cowboy.child_spec(:http, Heimdall.Router, [], [port: port]),
    ] ++ register_worker

    opts = [strategy: :one_for_one, name: Heimdall.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
