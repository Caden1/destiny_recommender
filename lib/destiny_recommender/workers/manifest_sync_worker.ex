defmodule DestinyRecommender.Workers.ManifestSyncWorker do
  use Oban.Worker, queue: :manifest, max_attempts: 3

  alias DestinyRecommender.Bungie
  alias DestinyRecommender.Repo
  alias DestinyRecommender.Recommendations.ManifestImporter
  alias DestinyRecommender.Recommendations.ManifestSnapshot
  alias DestinyRecommender.Workers.CuratorProposalWorker

  @classes ~w(Warlock Titan Hunter)
  @activities ~w(Crucible Strike)

  @impl true
  def perform(%Oban.Job{args: %{"snapshot_id" => snapshot_id}}) do
    with {:ok, snapshot} <- fetch_snapshot(snapshot_id),
         {:ok, manifest_payload} <- download_inventory_item_definitions(snapshot),
         :ok <- import_filtered_exotics(manifest_payload, snapshot),
         {:ok, _snapshot} <- mark_snapshot_synced(snapshot, manifest_payload.version),
         :ok <- enqueue_curator_proposals(manifest_payload.version) do
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
    case Bungie.fetch_inventory_item_definitions(locale) do
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

  defp enqueue_curator_proposals(manifest_version) do
    Enum.each(@classes, fn class ->
      Enum.each(@activities, fn activity ->
        args = %{
          "class" => class,
          "activity" => activity,
          "manifest_version" => manifest_version
        }

        CuratorProposalWorker.new(args,
          unique: [period: 86_400, keys: [:class, :activity, :manifest_version]]
        )
        |> Oban.insert!()
      end)
    end)

    :ok
  rescue
    error -> {:error, {:enqueue_curator_proposals_failed, Exception.message(error)}}
  end

  defp maybe_mark_failed(snapshot_id, reason) do
    case Repo.get(ManifestSnapshot, snapshot_id) do
      nil ->
        :ok

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
end
