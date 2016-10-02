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

  def wrap_plugs(plugs, start) do
    plugs
    |> Enum.reduce(start, &wrap_plug/2)
  end
end
