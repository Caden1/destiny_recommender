defmodule DestinyRecommender.Workers.CuratorProposalWorker do
  @moduledoc """
  Offline worker that asks the curator model to rank a reviewed candidate pool.

  Important boundaries:

    * only `ready` catalog items are eligible
    * candidates must be tagged for the requested activity
    * when a manifest version is supplied, seed rows are excluded so v3 uses the
      manifest-backed catalog instead of mixing old MVP fallback data
  """

  use Oban.Worker, queue: :curator, max_attempts: 3

  import Ecto.Query

  alias DestinyRecommender.Recommendations.{CatalogItem, CatalogProposal, Notes}
  alias DestinyRecommender.Repo

  @classes ~w(Warlock Titan Hunter)
  @activities ~w(Crucible Strike)

  @max_weapon_candidates 30
  @max_armor_candidates 15
  @notes_limit 5

  @impl true
  def perform(%Oban.Job{args: %{"class" => class, "activity" => activity} = args}) do
    manifest_version = Map.get(args, "manifest_version")

    with :ok <- validate_combo(class, activity),
         {:ok, weapon_candidates, armor_candidates} <-
           load_reviewed_candidates(class, activity, manifest_version),
         {:ok, note_bullets} <- load_note_bullets(class, activity),
         {:ok, ai_result} <-
           curator_ai_module().curate(
             class,
             activity,
             format_candidates(weapon_candidates),
             format_candidates(armor_candidates),
             note_bullets
           ),
         {:ok, _proposal} <-
           store_catalog_proposal(
             manifest_version,
             class,
             activity,
             ai_result,
             weapon_candidates,
             armor_candidates
           ) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def perform(%Oban.Job{}), do: {:error, :missing_required_args}

  defp validate_combo(class, activity) do
    cond do
      class not in @classes -> {:error, {:invalid_class, class}}
      activity not in @activities -> {:error, {:invalid_activity, activity}}
      true -> :ok
    end
  end

  defp load_reviewed_candidates(class, activity, manifest_version) do
    base_query =
      CatalogItem
      |> where([item], item.review_state == "ready")
      |> where([item], fragment("? = ANY(?)", ^activity, item.recommended_activities))
      |> maybe_scope_to_manifest_version(manifest_version)

    weapons =
      base_query
      |> where([item], item.slot == "weapon")
      |> order_by([item], asc: item.name)
      |> limit(^@max_weapon_candidates)
      |> Repo.all()

    armors =
      base_query
      |> where([item], item.slot == "armor")
      |> where([item], item.class == ^class or item.class == "Any")
      |> order_by([item], asc: item.name)
      |> limit(^@max_armor_candidates)
      |> Repo.all()

    cond do
      weapons == [] -> {:error, {:no_weapon_candidates, class, activity, manifest_version}}
      armors == [] -> {:error, {:no_armor_candidates, class, activity, manifest_version}}
      true -> {:ok, weapons, armors}
    end
  end

  defp maybe_scope_to_manifest_version(query, manifest_version) when is_binary(manifest_version) do
    query
    |> where([item], item.source != "seed")
    |> where([item], item.manifest_version == ^manifest_version or item.source == "manual")
  end

  defp maybe_scope_to_manifest_version(query, _manifest_version), do: query

  defp load_note_bullets(class, activity) do
    case Notes.retrieve_note_bullets(class, activity, @notes_limit) do
      {:ok, bullets} -> {:ok, bullets}
      {:error, _reason} -> {:ok, []}
    end
  end

  defp store_catalog_proposal(
         manifest_version,
         class,
         activity,
         %{"weapon_slugs" => weapon_slugs, "armor_slugs" => armor_slugs, "summary" => summary} =
           ai_result,
         weapon_candidates,
         armor_candidates
       ) do
    weapon_slug_set = MapSet.new(Enum.map(weapon_candidates, & &1.slug))
    armor_slug_set = MapSet.new(Enum.map(armor_candidates, & &1.slug))

    with :ok <- validate_slugs(weapon_slugs, weapon_slug_set, :weapon_slugs),
         :ok <- validate_slugs(armor_slugs, armor_slug_set, :armor_slugs) do
      %CatalogProposal{}
      |> CatalogProposal.changeset(%{
        manifest_version: manifest_version,
        class: class,
        activity: activity,
        status: "pending",
        weapon_slugs: weapon_slugs,
        armor_slugs: armor_slugs,
        summary: summary,
        response_json: ai_result
      })
      |> Repo.insert()
    end
  end

  defp store_catalog_proposal(_manifest_version, _class, _activity, other, _weapons, _armors) do
    {:error, {:invalid_curator_ai_response, other}}
  end

  defp validate_slugs(slugs, allowed_set, field) when is_list(slugs) do
    cond do
      slugs == [] -> {:error, {field, :empty}}
      Enum.any?(slugs, &(not is_binary(&1))) -> {:error, {field, :non_string_slug}}
      Enum.uniq(slugs) != slugs -> {:error, {field, :duplicate_slugs}}
      Enum.any?(slugs, &(not MapSet.member?(allowed_set, &1))) -> {:error, {field, :unknown_slug}}
      true -> :ok
    end
  end

  defp validate_slugs(_slugs, _allowed_set, field), do: {:error, {field, :invalid_type}}

  defp format_candidates(items) do
    Enum.map(items, fn item ->
      %{
        "slug" => item.slug,
        "name" => item.name,
        "slot" => item.slot,
        "class" => item.class,
        "item_type_display_name" => item.item_type_display_name,
        "tags" => item.tags,
        "meta_notes" => item.meta_notes,
        "review_state" => item.review_state
      }
    end)
  end

  defp curator_ai_module do
    Application.get_env(
      :destiny_recommender,
      :curator_ai_module,
      DestinyRecommender.Recommendations.CuratorAI
    )
  end
end
