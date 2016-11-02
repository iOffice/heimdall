defmodule Heimdall do
  @moduledoc Regex.replace(
    ~r/```(elixir|json)(\n|.*)```/Us, 
    File.read!("README.md"), 
    fn(_, _, code) -> 
      Regex.replace(~r/^/m, code, "    ") 
    end)
end
