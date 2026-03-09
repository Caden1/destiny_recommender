defmodule DestinyRecommenderWeb.Admin.CatalogLiveTest do
  use DestinyRecommenderWeb.ConnCase

  import DestinyRecommender.RecommendationsFixtures
  import Phoenix.LiveViewTest

  alias DestinyRecommender.Recommendations.CatalogItem
  alias DestinyRecommender.Repo

  test "saving an item updates tags, activities, and notes", %{conn: conn} do
    item =
      catalog_item_fixture(%{
        slot: "weapon",
        class: "Any",
        review_state: "needs_review",
        recommended_activities: ["Crucible"]
      })

    {:ok, view, _html} = live(conn, "/admin/catalog")

    view
    |> form("#catalog-item-form-#{item.id}", %{
      "id" => item.id,
      "tags" => "aggressive, dueling",
      "recommended_activities" => "Crucible, Strike",
      "meta_notes" => "Prefer easy-to-use solo picks."
    })
    |> render_submit()

    assert render(view) =~ "Item updated."

    updated_item = Repo.get!(CatalogItem, item.id)
    assert updated_item.tags == ["aggressive", "dueling"]
    assert updated_item.recommended_activities == ["Crucible", "Strike"]
    assert updated_item.meta_notes == "Prefer easy-to-use solo picks."
  end

  test "approval errors are shown instead of crashing", %{conn: conn} do
    proposal =
      catalog_proposal_fixture(%{
        weapon_slugs: ["missing_weapon"],
        armor_slugs: ["missing_armor"]
      })

    {:ok, view, _html} = live(conn, "/admin/catalog")

    view
    |> element("button[phx-click='approve_proposal'][phx-value-id='#{proposal.id}']")
    |> render_click()

    assert render(view) =~ "Could not approve proposal"
  end
end
