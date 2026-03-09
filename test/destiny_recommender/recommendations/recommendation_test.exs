defmodule DestinyRecommender.Recommendations.RecommendationTest do
  use DestinyRecommender.DataCase, async: true

  alias DestinyRecommender.Recommendations.Recommendation

  test "normalizes smart punctuation and accepts valid candidate ids" do
    attrs = %{
      "weapon_id" => "ace_of_spades",
      "armor_id" => "ophidian_aspect",
      "why" => "Use “Ace of Spades” — it’s reliable.",
      "playstyle_tips" => ["Take high-percentage duels…", "Disengage when weak."]
    }

    changeset = Recommendation.changeset(attrs, ["ace_of_spades"], ["ophidian_aspect"])

    assert changeset.valid?
    assert {:ok, recommendation} = Ecto.Changeset.apply_action(changeset, :insert)
    assert recommendation.why == "Use \"Ace of Spades\" - it's reliable."
    assert recommendation.playstyle_tips == ["Take high-percentage duels...", "Disengage when weak."]
  end

  test "rejects ids that are not present in the candidate list" do
    attrs = %{
      "weapon_id" => "not_allowed",
      "armor_id" => "ophidian_aspect",
      "why" => "A short reason.",
      "playstyle_tips" => ["One tip."]
    }

    changeset = Recommendation.changeset(attrs, ["ace_of_spades"], ["ophidian_aspect"])

    refute changeset.valid?
    assert "is invalid" in errors_on(changeset).weapon_id
  end
end
