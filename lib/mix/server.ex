defmodule Mix.Tasks.Server do
  @moduledoc false
  use Mix.Task

  def run(_args) do
    Mix.Task.run "app.start", []
    unless iex_running?(), do: :timer.sleep(:infinity)
  end

  def iex_running? do
    Code.ensure_loaded(IEx) && IEx.started?
  end
end
