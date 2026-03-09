defmodule DestinyRecommender.Workers.ManifestSyncWorker do
  @moduledoc """
  Downloads the manifest slice we care about and imports manifest-backed exotics.

  Proposal generation is *not* triggered automatically anymore. The admin review
  step sits between import and proposal creation so the v3 pipeline stays human-in-the-loop.
  """

  use Oban.Worker, queue: :manifest, max_attempts: 3

  alias DestinyRecommender.Recommendations.{ManifestImporter, ManifestSnapshot}
  alias DestinyRecommender.Repo

  @impl true
  def perform(%Oban.Job{args: %{"snapshot_id" => snapshot_id}}) do
    with {:ok, snapshot} <- fetch_snapshot(snapshot_id),
         {:ok, manifest_payload} <- download_inventory_item_definitions(snapshot),
         :ok <- import_filtered_exotics(manifest_payload, snapshot),
         {:ok, _snapshot} <- mark_snapshot_synced(snapshot, manifest_payload.version) do
      :ok
    else
      {:error, reason} ->
        maybe_mark_failed(snapshot_id, reason)
        {:error, reason}
    end
  end

  def perform(%Oban.Job{}), do: {:error, :missing_snapshot_id}

  defp fetch_snapshot(snapshot_id) do
    case Repo.get(ManifestSnapshot, snapshot_id) do
      nil -> {:error, :manifest_snapshot_not_found}
      snapshot -> {:ok, snapshot}
    end
  end

  defp download_inventory_item_definitions(%ManifestSnapshot{locale: locale} = snapshot) do
    case bungie_client().fetch_inventory_item_definitions(locale) do
      {:ok, %{version: version, items: _items} = payload} ->
        if snapshot.version == version do
          {:ok, payload}
        else
          {:error, {:manifest_version_mismatch, expected: snapshot.version, got: version}}
        end

      {:error, reason} ->
        {:error, {:download_inventory_item_definitions_failed, reason}}
    end
  end

  defp import_filtered_exotics(%{items: items, version: version}, _snapshot) when is_map(items) do
    ManifestImporter.import_inventory_items!(items, version)
    :ok
  rescue
    error -> {:error, {:manifest_import_failed, Exception.message(error)}}
  end

  defp mark_snapshot_synced(snapshot, manifest_version) do
    snapshot
    |> ManifestSnapshot.changeset(%{
      status: "synced",
      synced_at: DateTime.utc_now(),
      checked_at: DateTime.utc_now(),
      error: nil,
      version: manifest_version
    })
    |> Repo.update()
  end

  defp maybe_mark_failed(snapshot_id, reason) do
    case Repo.get(ManifestSnapshot, snapshot_id) do
      nil -> :ok
      snapshot ->
        snapshot
        |> ManifestSnapshot.changeset(%{
          status: "failed",
          checked_at: DateTime.utc_now(),
          error: inspect(reason)
        })
        |> Repo.update()
    end
  end

  defp bungie_client do
    Application.get_env(:destiny_recommender, :bungie_client, DestinyRecommender.Bungie)
  end
end
