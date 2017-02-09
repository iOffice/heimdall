defmodule Mix.Tasks.DevServer do
  @moduledoc false
  use Mix.Task

  def filters(plugs) do
    plugs
    |> String.split(",")
    |> Poison.encode!
  end

  def options(opts) do
    opts
    |> String.split(",")
    |> Enum.map(&String.split(&1, "="))
    |> Enum.map(fn [k, v | _] -> {k, v} end)
    |> Enum.into(%{})
    |> Poison.encode!()
  end

  def routes_from_args(args) do
    cond do
      length(args) == 0 -> []
      length(args) < 4 ->
        IO.puts "Not enough parameters for args:"
        IO.inspect args
        []
      true ->
        [host, path, plugs, opts | tail] = args
        app = %{
          "labels" => %{
            "heimdall.host" => host,
            "heimdall.path" => path,
            "heimdall.filters" => filters(plugs),
            "heimdall.options" => options(opts)
          }
        }
        [app] ++ routes_from_args(tail)
    end
  end

  def run(args) do
    Mix.Config.persist(heimdall: [register_marathon: false])
    Mix.Task.run "app.start", []
    routes =
      args
      |> routes_from_args
      |> Heimdall.Marathon.BingeWatch.build_routes
      |> Heimdall.Marathon.BingeWatch.register_routes
    IO.puts "Registered routes:"
    IO.inspect routes
    :timer.sleep(:infinity)
  end
end
