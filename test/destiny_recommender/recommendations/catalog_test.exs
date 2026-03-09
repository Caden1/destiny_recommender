defmodule DestinyRecommender.Recommendations.CatalogTest do
  use DestinyRecommender.DataCase, async: true

  import DestinyRecommender.RecommendationsFixtures

  alias DestinyRecommender.Recommendations.Catalog

  test "db-ranked manifest items expose Bungie hashes as model-facing ids" do
    weapon =
      catalog_item_fixture(%{
        slug: "manifest_weapon",
        bungie_hash: 12_345,
        slot: "weapon",
        class: "Any",
        recommended_activities: ["Crucible"],
        source: "manifest"
      })

    catalog_ranking_fixture(%{
      class: "Warlock",
      activity: "Crucible",
      slot: "weapon",
      rank: 1,
      catalog_item: weapon
    })

    weapon_name = weapon.name

    assert [%{id: "12345", name: ^weapon_name}] = Catalog.weapons_for("Warlock", "Crucible")
    assert %{name: ^weapon_name, slug: "manifest_weapon"} = Catalog.weapon_by_id("12345")
  end
end
