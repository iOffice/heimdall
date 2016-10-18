defmodule Heimdall.Test.RegisterCallback do
  use ExUnit.Case, async: true
  use Plug.Test
  import Heimdall.Test.Util

  alias Heimdall.Marathon.RegisterCallback

  test "register returns body of successful request to marathon" do
    marathon_url = Application.fetch_env!(:heimdall, :marathon_url)
    response = {:ok, %HTTPoison.Response{status_code: 200, body: "success!"}}
    with_request_response response do
      assert {:ok, body} = RegisterCallback.register(marathon_url, 4000)
      assert body == "success!"
    end
  end

end
