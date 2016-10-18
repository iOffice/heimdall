defmodule Heimdall.Test.Util do
  import Mock

  defmacro with_request_response(response, block) do
    quote do
      mock = [
        {:post, fn url, body, headers -> unquote(response) end},
        {:get, fn url -> unquote(response) end}
      ]
      with_mock HTTPoison, mock do
        unquote(block)
      end
    end
  end
end

Code.load_file("test/test_router.ex")
ExUnit.start()
