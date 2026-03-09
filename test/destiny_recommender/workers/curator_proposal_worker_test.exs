defmodule DestinyRecommender.Workers.CuratorProposalWorkerTest do
  use DestinyRecommender.DataCase, async: true

  import DestinyRecommender.RecommendationsFixtures

  alias DestinyRecommender.Recommendations.CatalogProposal
  alias DestinyRecommender.Repo
  alias DestinyRecommender.Workers.CuratorProposalWorker

  setup do
    Application.put_env(
      :destiny_recommender,
      :curator_ai_module,
      DestinyRecommender.TestSupport.FakeCuratorAI
    )

    Application.delete_env(:destiny_recommender, :fake_curator_result)

    on_exit(fn ->
      Application.delete_env(:destiny_recommender, :curator_ai_module)
      Application.delete_env(:destiny_recommender, :fake_curator_result)
    end)

    :ok
  end

  test "uses only ready candidates for the requested activity and manifest version" do
    catalog_item_fixture(%{
      slug: "weapon_current",
      slot: "weapon",
      class: "Any",
      source: "manifest",
      manifest_version: "manifest-v2",
      recommended_activities: ["Crucible"]
    })

    catalog_item_fixture(%{
      slug: "weapon_old",
      slot: "weapon",
      class: "Any",
      source: "manifest",
      manifest_version: "manifest-v1",
      recommended_activities: ["Crucible"]
    })

    catalog_item_fixture(%{
      slug: "weapon_wrong_activity",
      slot: "weapon",
      class: "Any",
      source: "manifest",
      manifest_version: "manifest-v2",
      recommended_activities: ["Strike"]
    })

    catalog_item_fixture(%{
      slug: "armor_current",
      slot: "armor",
      class: "Warlock",
      source: "manifest",
      manifest_version: "manifest-v2",
      recommended_activities: ["Crucible"]
    })

    catalog_item_fixture(%{
      slug: "seed_weapon",
      slot: "weapon",
      class: "Any",
      source: "seed",
      manifest_version: nil,
      recommended_activities: ["Crucible"]
    })

    assert :ok =
             CuratorProposalWorker.perform(%Oban.Job{
               args: %{
                 "class" => "Warlock",
                 "activity" => "Crucible",
                 "manifest_version" => "manifest-v2"
               }
             })

    proposal = Repo.one!(CatalogProposal)
    assert proposal.weapon_slugs == ["weapon_current"]
    assert proposal.armor_slugs == ["armor_current"]
  end
end
