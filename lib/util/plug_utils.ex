defmodule Heimdall.Util.PlugUtils do

  def wrap_plug(current, next) do
    case {is_function(current), is_function(next)} do
      {true, true} ->
        fn conn, opts ->
          conn
          |> current.(opts)
          |> next.(opts)
        end
      {false, true} ->
        true = is_atom(current)

        fn conn, opts ->
          conn
          |> current.call(current.init(opts))
          |> next.(opts)
        end
      {true, false} ->
        true = is_atom(next)

        fn conn, opts ->
          conn
          |> current.(opts)
          |> next.call(next.init(opts))
        end
      {false, false} ->
        {true, true} = {is_atom(current), is_atom(next)}

        fn conn, opts ->
          conn
          |> current.call(current.init(opts))
          |> next.call(next.init(opts))
        end
    end
  end

  def wrap_plugs(plugs, start) when is_function(start) do
    plugs
    |> Enum.reverse()
    |> Enum.reduce(start, &wrap_plug/2)
  end

  def wrap_plugs(plugs, start) when is_atom(start) do
    start_fn = fn conn, opts -> start.call(conn, start.init(opts)) end
    wrap_plugs(plugs, start_fn)
  end
end
