defmodule DestinyRecommender.Recommendations.ManifestImporterTest do
  use DestinyRecommender.DataCase, async: true

  import DestinyRecommender.RecommendationsFixtures

  alias DestinyRecommender.Recommendations.{CatalogItem, ManifestImporter}
  alias DestinyRecommender.Repo

  test "merges manifest data into an existing seed row instead of inserting a duplicate" do
    existing_item =
      catalog_item_fixture(%{
        slug: "ace_of_spades",
        name: "Ace of Spades",
        slot: "weapon",
        class: "Any",
        source: "seed",
        recommended_activities: ["Crucible"],
        review_state: "ready",
        bungie_hash: nil
      })

    manifest_items = %{
      "987654" => %{
        "displayProperties" => %{"name" => "Ace of Spades"},
        "inventory" => %{"tierTypeName" => "Exotic"},
        "equippable" => true,
        "itemType" => 3,
        "classType" => 3,
        "itemTypeDisplayName" => "Hand Cannon"
      }
    }

    ManifestImporter.import_inventory_items!(manifest_items, "manifest-v1")

    items = Repo.all(CatalogItem)
    assert length(items) == 1

    imported_item = hd(items)
    assert imported_item.id == existing_item.id
    assert imported_item.bungie_hash == 987_654
    assert imported_item.source == "manifest"
    assert imported_item.review_state == "ready"
    assert imported_item.recommended_activities == ["Crucible"]
  end
end
