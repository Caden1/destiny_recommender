defmodule DestinyRecommender.RecommendationsFixtures do
  @moduledoc false

  alias DestinyRecommender.Recommendations.{
    CatalogItem,
    CatalogProposal,
    CatalogRanking,
    ManifestSnapshot
  }

  alias DestinyRecommender.Repo

  def catalog_item_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    defaults = %{
      slug: "catalog_item_#{unique}",
      name: "Catalog Item #{unique}",
      slot: "weapon",
      class: "Any",
      tags: ["test"],
      recommended_activities: ["Crucible"],
      source: "manual",
      review_state: "ready",
      raw: %{"fixture" => true}
    }

    %CatalogItem{}
    |> CatalogItem.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  def catalog_proposal_fixture(attrs \\ %{}) do
    defaults = %{
      class: "Warlock",
      activity: "Crucible",
      status: "pending",
      weapon_slugs: ["weapon_a"],
      armor_slugs: ["armor_a"],
      summary: "Fixture proposal summary",
      response_json: %{"fixture" => true}
    }

    %CatalogProposal{}
    |> CatalogProposal.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  def catalog_ranking_fixture(attrs \\ %{}) do
    catalog_item =
      Map.get_lazy(attrs, :catalog_item, fn ->
        catalog_item_fixture(%{slot: attrs[:slot] || "weapon", class: attrs[:class] || "Any"})
      end)

    defaults = %{
      class: attrs[:class] || "Warlock",
      activity: attrs[:activity] || "Crucible",
      slot: attrs[:slot] || "weapon",
      rank: attrs[:rank] || 1,
      catalog_item_id: catalog_item.id,
      proposal_id: attrs[:proposal_id]
    }

    %CatalogRanking{}
    |> CatalogRanking.changeset(Map.merge(defaults, Map.delete(attrs, :catalog_item)))
    |> Repo.insert!()
  end

  def manifest_snapshot_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    defaults = %{
      version: "manifest-#{unique}",
      locale: "en",
      status: "synced",
      checked_at: DateTime.utc_now(),
      synced_at: DateTime.utc_now()
    }

    %ManifestSnapshot{}
    |> ManifestSnapshot.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end
end
