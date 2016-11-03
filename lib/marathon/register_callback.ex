defmodule Heimdall.Marathon.RegisterCallback do

  @moduledoc """
  Simple module to register Heimdall's `/marathon-callback` with Marathon.
  """

  require Logger

  defp raise_error(reason) do
    require_marathon = Application.fetch_env!(:heimdall, :require_marathon)
    if require_marathon do
      raise HTTPoison.Error, reason: reason
    else
      Logger.warn reason
      {:error, reason}
    end
  end

  defp subscribe_to_marathon(subscribe_url) do
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

  @docs """
  Sends a post requeset to Marathon's event subscriptions with the
  location Heimdall is running with the path specified as `/marathon-callback`.

  If the application is configured with :require_marathon set to true, this
  function will raise an error. Otherwise it will just return the error like 
  `{:error, reason}`.
  """
  def register(marathon_url, callback_port) do
    {:ok, hostname} = :inet.gethostname
    callback_url = "http://#{hostname}:#{callback_port}/marathon-callback"
    subscribe_url =
      marathon_url <> "/v2/eventSubscriptions?callbackUrl=#{callback_url}"

    subscribe_to_marathon(subscribe_url)
  end
end
