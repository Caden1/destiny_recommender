defmodule DestinyRecommender.Bungie do
  @moduledoc false

  def get_manifest do
    req()
    |> Req.get(url: "/Destiny2/Manifest/")
    |> normalize_json_response()
  end

  def fetch_inventory_item_definitions(locale \\ locale()) do
    with {:ok, %{"Response" => response}} <- get_manifest(),
         version when is_binary(version) <- response["version"],
         paths when is_map(paths) <- response["jsonWorldComponentContentPaths"],
         locale_paths when is_map(locale_paths) <- paths[locale],
         path when is_binary(path) <- locale_paths["DestinyInventoryItemDefinition"] do
      url = content_url() <> path

      case Req.get(url: url) do
        {:ok, %{status: 200, body: body}} when is_map(body) ->
          {:ok, %{version: version, locale: locale, path: path, items: body}}

        {:ok, %{status: status, body: body}} ->
          {:error, {:bungie_http_error, status, body}}

        {:error, reason} ->
          {:error, {:bungie_req_error, reason}}
      end
    else
      _ -> {:error, :invalid_manifest_response}
    end
  end

  defp req do
    Req.new(
      base_url: platform_url(),
      headers: [
        {"x-api-key", api_key!()},
        {"accept", "application/json"}
      ]
    )
  end

  defp normalize_json_response({:ok, %{status: 200, body: body}}) when is_map(body),
    do: {:ok, body}

  defp normalize_json_response({:ok, %{status: status, body: body}}),
    do: {:error, {:bungie_http_error, status, body}}

  defp normalize_json_response({:error, reason}), do: {:error, {:bungie_req_error, reason}}

  defp api_key! do
    Application.fetch_env!(:destiny_recommender, __MODULE__)[:api_key] ||
      raise "Missing BUNGIE_API_KEY"
  end

  defp locale, do: Application.fetch_env!(:destiny_recommender, __MODULE__)[:locale] || "en"
  defp platform_url, do: Application.fetch_env!(:destiny_recommender, __MODULE__)[:platform_url]
  defp content_url, do: Application.fetch_env!(:destiny_recommender, __MODULE__)[:content_url]
end
