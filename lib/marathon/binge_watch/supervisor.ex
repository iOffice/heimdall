defmodule Heimdall.Marathon.BingeWatch.Supervisor do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  def init(args) do
    marathon_url = Keyword.get(args, :marathon_url)
    children = [
      worker(Heimdall.Marathon.BingeWatch, [[marathon_url: marathon_url]], restart: :permanent)
    ]

    supervise(children, strategy: :one_for_one, max_retries: :infinity, max_seconds: 1)
  end
end
