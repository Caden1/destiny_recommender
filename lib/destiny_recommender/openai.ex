defmodule DestinyRecommender.OpenAI do
  @moduledoc """
  Minimal OpenAI Responses API wrapper.
  """

  @base_url "https://api.openai.com/v1"

  def model do
    config()[:model] || "gpt-5.2"
  end

  def create_response(payload) when is_map(payload) do
    with {:ok, api_key} <- fetch_api_key() do
      req =
        Req.new(
          base_url: @base_url,
          headers: [
            {"authorization", "Bearer #{api_key}"},
            {"content-type", "application/json"}
          ]
        )

      case Req.post(req, url: "/responses", json: payload) do
        {:ok, %{status: 200, body: body}} -> {:ok, body}
        {:ok, %{status: status, body: body}} -> {:error, {:openai_http_error, status, body}}
        {:error, reason} -> {:error, {:openai_req_error, reason}}
      end
    end
  end

  defp fetch_api_key do
    case config()[:api_key] do
      key when is_binary(key) and byte_size(key) > 0 -> {:ok, key}
      _ -> {:error, :missing_openai_api_key}
    end
  end

  defp config do
    Application.get_env(:destiny_recommender, __MODULE__, [])
  end
end
