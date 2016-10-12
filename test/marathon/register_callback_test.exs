defmodule Heimdall.Test.RegisterCallback do
  use ExUnit.Case, async: true
  use Plug.Test
  import Mock

  alias Heimdall.Marathon.RegisterCallback

  defmacro with_success_request_mock(block) do
    quote do
      mock =
      with_mock HTTPoison, [post: fn url, body, headers -> {:ok, %HTTPoison.Response{status_code: 200, body: "success!"}} end] do
        unquote(block)
      end
    end
  end

  test "register returns body of successful request to marathon" do
    marathon_url = Application.fetch_env!(:heimdall, :marathon_url)
    with_success_request_mock do
      assert {:ok, body} = RegisterCallback.register(marathon_url, 4000)
      assert body == "success!"
    end
  end
end
