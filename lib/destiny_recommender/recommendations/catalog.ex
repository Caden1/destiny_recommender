defmodule DestinyRecommender.Recommendations.Catalog do
  @moduledoc """
  Candidate catalog used by both the online recommender and the offline curator.

  The public item maps returned by this module always include an `:id` field that
  the model can safely choose from:

    * if a Bungie hash exists, we expose the hash as a string
    * otherwise we fall back to the local slug

  This lets the app move toward canonical Bungie identifiers without breaking the
  local fallback catalog.
  """

  import Ecto.Query

  alias DestinyRecommender.Recommendations.{CatalogItem, CatalogRanking}
  alias DestinyRecommender.Repo

  @classes ~w(Warlock Titan Hunter)
  @activities ~w(Crucible Strike)

  @weapons [
    %{
      id: "ace_of_spades",
      slug: "ace_of_spades",
      name: "Ace of Spades",
      activity: "Crucible",
      recommended_activities: ["Crucible"],
      tags: ~w(dueling reliable range snowball),
      meta_notes: ""
    },
    %{
      id: "thorn",
      slug: "thorn",
      name: "Thorn",
      activity: "Crucible",
      recommended_activities: ["Crucible"],
      tags: ~w(dueling chip damage pressure),
      meta_notes: ""
    },
    %{
      id: "the_last_word",
      slug: "the_last_word",
      name: "The Last Word",
      activity: "Crucible",
      recommended_activities: ["Crucible"],
      tags: ~w(close_range dueling aggressive),
      meta_notes: ""
    },
    %{
      id: "no_time_to_explain",
      slug: "no_time_to_explain",
      name: "No Time to Explain",
      activity: "Crucible",
      recommended_activities: ["Crucible"],
      tags: ~w(mid_range lane easy),
      meta_notes: ""
    },
    %{
      id: "le_monarque",
      slug: "le_monarque",
      name: "Le Monarque",
      activity: "Crucible",
      recommended_activities: ["Crucible"],
      tags: ~w(pick damage_over_time anti_peek),
      meta_notes: ""
    },
    %{
      id: "conditional_finality",
      slug: "conditional_finality",
      name: "Conditional Finality",
      activity: "Crucible",
      recommended_activities: ["Crucible"],
      tags: ~w(close_range burst shutdown),
      meta_notes: ""
    },
    %{
      id: "witherhoard",
      slug: "witherhoard",
      name: "Witherhoard",
      activity: "Strike",
      recommended_activities: ["Strike"],
      tags: ~w(add_clear area_denial easy solo),
      meta_notes: ""
    },
    %{
      id: "gjallarhorn",
      slug: "gjallarhorn",
      name: "Gjallarhorn",
      activity: "Strike",
      recommended_activities: ["Strike"],
      tags: ~w(boss_damage burst easy),
      meta_notes: ""
    },
    %{
      id: "trinity_ghoul",
      slug: "trinity_ghoul",
      name: "Trinity Ghoul",
      activity: "Strike",
      recommended_activities: ["Strike"],
      tags: ~w(add_clear chain lightning),
      meta_notes: ""
    },
    %{
      id: "sunshot",
      slug: "sunshot",
      name: "Sunshot",
      activity: "Strike",
      recommended_activities: ["Strike"],
      tags: ~w(add_clear explosions fast),
      meta_notes: ""
    },
    %{
      id: "arbalest",
      slug: "arbalest",
      name: "Arbalest",
      activity: "Strike",
      recommended_activities: ["Strike"],
      tags: ~w(anti_shield precision utility),
      meta_notes: ""
    },
    %{
      id: "riskrunner",
      slug: "riskrunner",
      name: "Riskrunner",
      activity: "Strike",
      recommended_activities: ["Strike"],
      tags: ~w(survivability add_clear damage_resist),
      meta_notes: ""
    }
  ]

  @armors [
    %{
      id: "ophidian_aspect",
      slug: "ophidian_aspect",
      name: "Ophidian Aspect",
      class: "Warlock",
      activity: "Crucible",
      recommended_activities: ["Crucible"],
      tags: ~w(neutral handling reload dueling),
      meta_notes: ""
    },
    %{
      id: "transversive_steps",
      slug: "transversive_steps",
      name: "Transversive Steps",
      class: "Warlock",
      activity: "Crucible",
      recommended_activities: ["Crucible"],
      tags: ~w(mobility reposition reload),
      meta_notes: ""
    },
    %{
      id: "the_stag",
      slug: "the_stag",
      name: "The Stag",
      class: "Warlock",
      activity: "Crucible",
      recommended_activities: ["Crucible"],
      tags: ~w(survivability rift anchor),
      meta_notes: ""
    },
    %{
      id: "sunbracers",
      slug: "sunbracers",
      name: "Sunbracers",
      class: "Warlock",
      activity: "Strike",
      recommended_activities: ["Strike"],
      tags: ~w(add_clear ability_spam fast),
      meta_notes: ""
    },
    %{
      id: "necrotic_grip",
      slug: "necrotic_grip",
      name: "Necrotic Grip",
      class: "Warlock",
      activity: "Strike",
      recommended_activities: ["Strike"],
      tags: ~w(add_clear poison synergy),
      meta_notes: ""
    },
    %{
      id: "contraverse_hold",
      slug: "contraverse_hold",
      name: "Contraverse Hold",
      class: "Warlock",
      activity: "Strike",
      recommended_activities: ["Strike"],
      tags: ~w(grenade uptime survivability),
      meta_notes: ""
    },
    %{
      id: "one_eyed_mask",
      slug: "one_eyed_mask",
      name: "One-Eyed Mask",
      class: "Titan",
      activity: "Crucible",
      recommended_activities: ["Crucible"],
      tags: ~w(dueling survivability snowball),
      meta_notes: ""
    },
    %{
      id: "dunemarchers",
      slug: "dunemarchers",
      name: "Dunemarchers",
      class: "Titan",
      activity: "Crucible",
      recommended_activities: ["Crucible"],
      tags: ~w(mobility chain damage),
      meta_notes: ""
    },
    %{
      id: "peacekeepers",
      slug: "peacekeepers",
      name: "Peacekeepers",
      class: "Titan",
      activity: "Crucible",
      recommended_activities: ["Crucible"],
      tags: ~w(smg handling strafe),
      meta_notes: ""
    },
    %{
      id: "heart_of_inmost_light",
      slug: "heart_of_inmost_light",
      name: "Heart of Inmost Light",
      class: "Titan",
      activity: "Strike",
      recommended_activities: ["Strike"],
      tags: ~w(ability uptime fast),
      meta_notes: ""
    },
    %{
      id: "synthoceps",
      slug: "synthoceps",
      name: "Synthoceps",
      class: "Titan",
      activity: "Strike",
      recommended_activities: ["Strike"],
      tags: ~w(melee burst add_clear),
      meta_notes: ""
    },
    %{
      id: "cuirass_of_the_falling_star",
      slug: "cuirass_of_the_falling_star",
      name: "Cuirass of the Falling Star",
      class: "Titan",
      activity: "Strike",
      recommended_activities: ["Strike"],
      tags: ~w(boss_damage burst),
      meta_notes: ""
    },
    %{
      id: "st0mp_ee5",
      slug: "st0mp_ee5",
      name: "St0mp-EE5",
      class: "Hunter",
      activity: "Crucible",
      recommended_activities: ["Crucible"],
      tags: ~w(mobility evasive),
      meta_notes: ""
    },
    %{
      id: "wormhusk_crown",
      slug: "wormhusk_crown",
      name: "Wormhusk Crown",
      class: "Hunter",
      activity: "Crucible",
      recommended_activities: ["Crucible"],
      tags: ~w(survivability neutral),
      meta_notes: ""
    },
    %{
      id: "the_dragons_shadow",
      slug: "the_dragons_shadow",
      name: "The Dragon's Shadow",
      class: "Hunter",
      activity: "Crucible",
      recommended_activities: ["Crucible"],
      tags: ~w(neutral reload handling),
      meta_notes: ""
    },
    %{
      id: "gyrfalcons_hauberk",
      slug: "gyrfalcons_hauberk",
      name: "Gyrfalcon's Hauberk",
      class: "Hunter",
      activity: "Strike",
      recommended_activities: ["Strike"],
      tags: ~w(solo survivability damage uptime),
      meta_notes: ""
    },
    %{
      id: "star_eater_scales",
      slug: "star_eater_scales",
      name: "Star-Eater Scales",
      class: "Hunter",
      activity: "Strike",
      recommended_activities: ["Strike"],
      tags: ~w(boss_damage burst),
      meta_notes: ""
    },
    %{
      id: "omnioculus",
      slug: "omnioculus",
      name: "Omnioculus",
      class: "Hunter",
      activity: "Strike",
      recommended_activities: ["Strike"],
      tags: ~w(survivability invis solo),
      meta_notes: ""
    }
  ]

  def classes, do: @classes
  def activities, do: @activities

  def valid_class?(class), do: class in @classes
  def valid_activity?(activity), do: activity in @activities

  def weapons_for(class, activity) when class in @classes and activity in @activities do
    case db_ranked_items(class, activity, "weapon") do
      [] -> Enum.filter(@weapons, &(&1.activity == activity))
      items -> items
    end
  end

  def armors_for(class, activity) when class in @classes and activity in @activities do
    case db_ranked_items(class, activity, "armor") do
      [] -> Enum.filter(@armors, &(&1.class == class and &1.activity == activity))
      items -> items
    end
  end

  def weapon_by_id(id) when is_binary(id) do
    case lookup_db_item("weapon", id) do
      %CatalogItem{} = item -> to_public_item(item)
      nil -> Enum.find(@weapons, &matches_candidate_id?(&1, id))
    end
  end

  def armor_by_id(id) when is_binary(id) do
    case lookup_db_item("armor", id) do
      %CatalogItem{} = item -> to_public_item(item)
      nil -> Enum.find(@armors, &matches_candidate_id?(&1, id))
    end
  end

  def default_weapons, do: @weapons
  def default_armors, do: @armors

  @doc """
  Returns the model-facing candidate ID.

  Manifest-backed items use the Bungie hash when available. Fallback items keep
  using slugs so the local MVP still works without manifest data.
  """
  def candidate_id(%CatalogItem{bungie_hash: hash, slug: slug}),
    do: if(is_integer(hash), do: Integer.to_string(hash), else: slug)

  def candidate_id(%{bungie_hash: hash, slug: slug}),
    do: if(is_integer(hash), do: Integer.to_string(hash), else: slug)

  def candidate_id(%{id: id}) when is_binary(id), do: id

  defp db_ranked_items(class, activity, slot) do
    CatalogRanking
    |> join(:inner, [r], item in CatalogItem, on: item.id == r.catalog_item_id)
    |> where([r, item], r.class == ^class and r.activity == ^activity and r.slot == ^slot)
    |> where([_r, item], item.review_state == "ready")
    |> order_by([r, _item], asc: r.rank)
    |> select([_r, item], item)
    |> Repo.all()
    |> Enum.map(&to_public_item/1)
  end

  defp lookup_db_item(slot, id) when is_binary(id) do
    case parse_integer(id) do
      {:ok, bungie_hash} ->
        Repo.get_by(CatalogItem, bungie_hash: bungie_hash, slot: slot) ||
          Repo.get_by(CatalogItem, slug: id, slot: slot)

      :error ->
        Repo.get_by(CatalogItem, slug: id, slot: slot)
    end
  end

  defp to_public_item(%CatalogItem{} = item) do
    %{
      id: candidate_id(item),
      slug: item.slug,
      bungie_hash: item.bungie_hash,
      name: item.name,
      class: item.class,
      tags: item.tags || [],
      item_type_display_name: item.item_type_display_name,
      tier_name: item.tier_name,
      meta_notes: item.meta_notes || "",
      recommended_activities: item.recommended_activities || [],
      source: item.source,
      review_state: item.review_state
    }
  end

  defp matches_candidate_id?(item, id) do
    candidate_id(item) == id or item.slug == id
  end

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> {:ok, integer}
      _ -> :error
    end
  end
end
