defmodule Heimdall do
  # This module is just for the docs
  #
  # it loads the README as a moduledoc, using regex to convert
  # github style markdown to ExDoc style markdown
  @moduledoc Regex.replace(
    ~r/```(elixir|json)(\n|.*)```/Us, 
    File.read!("README.md"), 
    fn(_, _, code) -> 
      Regex.replace(~r/^/m, code, "    ") 
    end)
end
