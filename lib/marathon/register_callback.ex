defmodule Heimdall.Marathon.RegisterCallback do
  require Logger

  def raise_error(reason) do
    require_marathon = Application.fetch_env!(:heimdall, :require_marathon)
    if require_marathon do
      raise HTTPoison.Error, reason: reason
    else
      Logger.warn reason
      {:error, reason}
    end
  end

  def subscribe_to_marathon(subscribe_url) do
    headers = %{"Content-Type": "application/json"}

    case HTTPoison.post(subscribe_url, "", headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}
      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        raise_error("Could not connect to Marathon at #{subscribe_url}: #{code} - #{body}")
      {:error, %HTTPoison.Error{reason: reason}} ->
        raise_error(reason)
    end
  end

  def register(marathon_url, callback_port) do
    {:ok, hostname} = :inet.gethostname
    callback_url = "http://#{hostname}:#{callback_port}/marathon-callback"
    subscribe_url =
      marathon_url <> "/v2/eventSubscriptions?callbackUrl=#{callback_url}"

    subscribe_to_marathon(subscribe_url)
  end
end
