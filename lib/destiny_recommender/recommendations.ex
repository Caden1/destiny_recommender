defmodule DestinyRecommender.Recommendations do
  @moduledoc false

  alias DestinyRecommender.Recommendations.{AIRecommender, Catalog}

  def recommend(class, activity) do
    cond do
      not Catalog.valid_class?(class) ->
        {:error, {:invalid_class, class}}

      not Catalog.valid_activity?(activity) ->
        {:error, {:invalid_activity, activity}}

      true ->
        with {:ok, rec} <- AIRecommender.recommend(class, activity) do
          weapon = Catalog.weapon_by_id(rec.weapon_id)
          armor = Catalog.armor_by_id(rec.armor_id)

          {:ok,
           %{
             weapon: weapon,
             armor: armor,
             why: rec.why,
             tips: rec.playstyle_tips
           }}
        end
    end
  end
end
