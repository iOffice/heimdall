defmodule Heimdall.Util.PlugUtils do

  defmacro check_conn(conn, [do: expression]) do
    quote do
      case unquote(conn) do
        %Plug.Conn{halted: true} -> unquote(conn)
        _ -> unquote(expression)
      end
    end
  end

  def wrap_plug(current, next) do
    case {is_function(current), is_function(next)} do
      {true, true} ->
        fn conn, opts ->
          check_conn conn do
            conn
            |> current.(opts)
            |> next.(opts)
          end
        end
      {false, true} ->
        true = is_atom(current)

        fn conn, opts ->
          check_conn conn do
            conn
            |> current.call(current.init(opts))
            |> next.(opts)
          end
        end
      {true, false} ->
        true = is_atom(next)

        fn conn, opts ->
          check_conn conn do
            conn
            |> current.(opts)
            |> next.call(next.init(opts))
          end
        end
      {false, false} ->
        {true, true} = {is_atom(current), is_atom(next)}

        fn conn, opts ->
          check_conn conn do
            conn
            |> current.call(current.init(opts))
            |> next.call(next.init(opts))
          end
        end
    end
  end

  def wrap_plugs(plugs, last) when is_function(last) do
    checked_last = fn conn, opts -> check_conn conn, do: last.(conn, opts) end
    plugs
    |> Enum.reverse()
    |> Enum.reduce(checked_last, &wrap_plug/2)
  end

  def wrap_plugs(plugs, last) when is_atom(last) do
    last_fn = fn conn, opts -> last.call(conn, last.init(opts)) end
    wrap_plugs(plugs, last_fn)
  end
end
