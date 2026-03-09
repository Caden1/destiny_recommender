defmodule DestinyRecommender.Recommendations.Curation do
  @moduledoc """
  Helpers for the slow, human-in-the-loop curation workflow.

  Manifest sync imports canonical items. Human review adds tags, notes, and
  activity suitability. Only after that does the app enqueue offline curator jobs
  that generate proposals for admin approval.
  """

  import Ecto.Query

  alias DestinyRecommender.Recommendations.ManifestSnapshot
  alias DestinyRecommender.Repo
  alias DestinyRecommender.Workers.CuratorProposalWorker

  @classes ~w(Warlock Titan Hunter)
  @activities ~w(Crucible Strike)

  def latest_synced_manifest_version do
    ManifestSnapshot
    |> where([snapshot], snapshot.status == "synced")
    |> order_by([snapshot], desc: snapshot.synced_at, desc: snapshot.inserted_at)
    |> limit(1)
    |> select([snapshot], snapshot.version)
    |> Repo.one()
  end

  @doc """
  Enqueues one curator proposal job for each class/activity combination.

  When no synced manifest exists yet, jobs still run in local mode using the ready
  seed/manual catalog, which is helpful during development.
  """
  def enqueue_curator_proposals(opts \\ []) do
    manifest_version = Keyword.get(opts, :manifest_version, latest_synced_manifest_version())

    count =
      Enum.reduce(@classes, 0, fn class, acc ->
        Enum.reduce(@activities, acc, fn activity, inner_acc ->
          args = %{"class" => class, "activity" => activity}
          args = if is_binary(manifest_version), do: Map.put(args, "manifest_version", manifest_version), else: args

          {:ok, _job} =
            Oban.insert(
              CuratorProposalWorker.new(args,
                unique: [period: 86_400, keys: [:class, :activity, :manifest_version]]
              )
            )

          inner_acc + 1
        end)
      end)

    {:ok, %{count: count, manifest_version: manifest_version}}
  rescue
    error ->
      {:error, Exception.message(error)}
  end
end
