defmodule Heimdall.Marathon.RegisterCallback do
  def register(marathon_url, callback_port) do
    {:ok, hostname} = :inet.gethostname
    callback_url = "http://#{hostname}:#{callback_port}/marathon-callback"
    full_url = marathon_url <> "/v2/eventSubscriptions?callbackUrl=#{callback_url}"
    headers = %{"Content-Type": "application/json"}
    require_marathon = Application.fetch_env!(:heimdall, :require_marathon)
    raise_error = fn reason ->
      if require_marathon do
        raise HTTPoison.Error, reason: reason
      else
        :ok
      end
    end

    case HTTPoison.post(full_url, "", headers) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        :ok
      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        raise_error.("Could not connect to Marathon at #{full_url}: #{code} - #{body}")
      {:error, %HTTPoison.Error{reason: reason}} ->
        raise_error.(reason)
    end
  end
end
