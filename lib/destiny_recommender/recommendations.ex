defmodule DestinyRecommender.Recommendations do
  @moduledoc false

  import Ecto.Query

  alias DestinyRecommender.Recommendations.{
    AIRecommender,
    Catalog,
    CatalogItem,
    CatalogProposal,
    CatalogRanking
  }

  alias DestinyRecommender.Repo

  def recommend(class, activity) do
    cond do
      not Catalog.valid_class?(class) ->
        {:error, {:invalid_class, class}}

      not Catalog.valid_activity?(activity) ->
        {:error, {:invalid_activity, activity}}

      true ->
        with {:ok, rec} <- AIRecommender.recommend(class, activity),
             weapon when not is_nil(weapon) <- Catalog.weapon_by_id(rec.weapon_id),
             armor when not is_nil(armor) <- Catalog.armor_by_id(rec.armor_id) do
          {:ok,
           %{
             weapon: weapon,
             armor: armor,
             why: rec.why,
             tips: rec.playstyle_tips
           }}
        else
          nil -> {:error, :catalog_lookup_failed}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def list_items_needing_review do
    CatalogItem
    |> where([item], item.review_state == "needs_review")
    |> order_by([item], asc: item.inserted_at, asc: item.name)
    |> Repo.all()
  end

  def update_catalog_item(%CatalogItem{} = item, attrs) when is_map(attrs) do
    item
    |> CatalogItem.changeset(attrs)
    |> Repo.update()
  end

  def update_catalog_item(item_id, attrs) when is_integer(item_id) and is_map(attrs) do
    case Repo.get(CatalogItem, item_id) do
      nil -> {:error, :not_found}
      item -> update_catalog_item(item, attrs)
    end
  end

  def mark_catalog_item_ready(%CatalogItem{} = item) do
    update_catalog_item(item, %{review_state: "ready"})
  end

  def mark_catalog_item_ready(item_id) when is_integer(item_id) do
    update_catalog_item(item_id, %{review_state: "ready"})
  end

  def list_pending_proposals do
    CatalogProposal
    |> where([proposal], proposal.status == "pending")
    |> order_by([proposal], asc: proposal.inserted_at)
    |> Repo.all()
  end

  def approve_proposal!(%CatalogProposal{} = proposal) do
    Repo.transaction(fn ->
      slug_to_item_id =
        CatalogItem
        |> where([item], item.slug in ^(proposal.weapon_slugs ++ proposal.armor_slugs))
        |> select([item], {item.slug, item.id})
        |> Repo.all()
        |> Map.new()

      weapon_rankings =
        build_ranking_attrs!(proposal.weapon_slugs, slug_to_item_id, proposal, "weapon")

      armor_rankings =
        build_ranking_attrs!(proposal.armor_slugs, slug_to_item_id, proposal, "armor")

      now = DateTime.utc_now()

      CatalogRanking
      |> where([ranking], ranking.class == ^proposal.class and ranking.activity == ^proposal.activity)
      |> Repo.delete_all()

      Repo.insert_all(CatalogRanking, add_timestamps(weapon_rankings, now))
      Repo.insert_all(CatalogRanking, add_timestamps(armor_rankings, now))

      proposal
      |> CatalogProposal.changeset(%{
        status: "approved",
        approved_at: now,
        rejected_at: nil
      })
      |> Repo.update!()
    end)
  end

  def approve_proposal!(proposal_id) when is_integer(proposal_id) do
    case Repo.get(CatalogProposal, proposal_id) do
      nil -> raise "CatalogProposal #{proposal_id} not found"
      proposal -> approve_proposal!(proposal)
    end
  end

  def reject_proposal!(%CatalogProposal{} = proposal) do
    proposal
    |> CatalogProposal.changeset(%{
      status: "rejected",
      rejected_at: DateTime.utc_now(),
      approved_at: nil
    })
    |> Repo.update!()
  end

  def reject_proposal!(proposal_id) when is_integer(proposal_id) do
    case Repo.get(CatalogProposal, proposal_id) do
      nil -> raise "CatalogProposal #{proposal_id} not found"
      proposal -> reject_proposal!(proposal)
    end
  end

  defp build_ranking_attrs!(slugs, slug_to_item_id, proposal, slot) do
    Enum.map(Enum.with_index(slugs, 1), fn {slug, rank} ->
      catalog_item_id =
        Map.get(slug_to_item_id, slug) ||
          raise "Could not find catalog item for slug #{inspect(slug)}"

      %{
        class: proposal.class,
        activity: proposal.activity,
        slot: slot,
        rank: rank,
        catalog_item_id: catalog_item_id,
        proposal_id: proposal.id
      }
    end)
  end

  defp add_timestamps(attrs, now) do
    Enum.map(attrs, &Map.merge(&1, %{inserted_at: now, updated_at: now}))
  end
end
