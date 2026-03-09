defmodule DestinyRecommender.TestSupport.FakeCuratorAI do
  @moduledoc false

  def curate(_class, _activity, weapon_candidates, armor_candidates, _note_bullets) do
    case Application.get_env(:destiny_recommender, :fake_curator_result) do
      nil ->
        {:ok,
         %{
           "weapon_slugs" => Enum.map(weapon_candidates, & &1["slug"]),
           "armor_slugs" => Enum.map(armor_candidates, & &1["slug"]),
           "summary" => "Fixture curator result"
         }}

      configured_result ->
        {:ok, configured_result}
    end
  end
end
