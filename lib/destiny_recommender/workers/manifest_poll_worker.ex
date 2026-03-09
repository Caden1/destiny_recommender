defmodule DestinyRecommender.Workers.ManifestPollWorker do
  use Oban.Worker,
    queue: :manifest,
    max_attempts: 3,
    unique: [period: 3600, fields: [:worker, :args]]

  alias DestinyRecommender.Recommendations.ManifestSnapshot
  alias DestinyRecommender.Repo
  alias DestinyRecommender.Workers.ManifestSyncWorker

  @impl true
  def perform(_job) do
    with {:ok, %{"Response" => response}} <- bungie_client().get_manifest(),
         version when is_binary(version) <- response["version"],
         path when is_binary(path) <-
           get_in(response, [
             "jsonWorldComponentContentPaths",
             "en",
             "DestinyInventoryItemDefinition"
           ]) do
      snapshot =
        Repo.get_by(ManifestSnapshot, version: version, locale: "en") ||
          Repo.insert!(%ManifestSnapshot{
            version: version,
            locale: "en",
            items_path: path,
            status: "pending",
            checked_at: DateTime.utc_now()
          })

      Oban.insert!(
        ManifestSyncWorker.new(
          %{"snapshot_id" => snapshot.id},
          unique: [period: 86_400, keys: [:snapshot_id]]
        )
      )

      :ok
    else
      _ -> {:error, :manifest_poll_failed}
    end
  end

  defp bungie_client do
    Application.get_env(:destiny_recommender, :bungie_client, DestinyRecommender.Bungie)
  end
end
