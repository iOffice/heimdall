defmodule Heimdall.Marathon.BingeWatch.Supervisor do
  use Supervisor

  @name Heimdall.Marathon.BingeWatch.Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: @name)
  end

  def init(args) do
    children = [
      worker(Heimdall.Marathon.BingeWatch, [args], restart: :permanent)
    ]

    supervise(children, strategy: :one_for_one, max_retries: :infinity, max_seconds: 1)
  end
end
