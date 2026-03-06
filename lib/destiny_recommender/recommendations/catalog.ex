defmodule DestinyRecommender.Recommendations.Catalog do
  @moduledoc false

  import Ecto.Query

  alias DestinyRecommender.Repo

  alias DestinyRecommender.Recommendations.{
    CatalogItem,
    CatalogRanking
  }

  @classes ~w(Warlock Titan Hunter)
  @activities ~w(Crucible Strike)

  @weapons [
    %{
      id: "ace_of_spades",
      name: "Ace of Spades",
      activity: "Crucible",
      tags: ~w(dueling reliable range snowball)
    },
    %{id: "thorn", name: "Thorn", activity: "Crucible", tags: ~w(dueling chip damage pressure)},
    %{
      id: "the_last_word",
      name: "The Last Word",
      activity: "Crucible",
      tags: ~w(close_range dueling aggressive)
    },
    %{
      id: "no_time_to_explain",
      name: "No Time to Explain",
      activity: "Crucible",
      tags: ~w(mid_range lane easy)
    },
    %{
      id: "le_monarque",
      name: "Le Monarque",
      activity: "Crucible",
      tags: ~w(pick damage_over_time anti_peek)
    },
    %{
      id: "conditional_finality",
      name: "Conditional Finality",
      activity: "Crucible",
      tags: ~w(close_range burst shutdown)
    },
    %{
      id: "witherhoard",
      name: "Witherhoard",
      activity: "Strike",
      tags: ~w(add_clear area_denial easy solo)
    },
    %{
      id: "gjallarhorn",
      name: "Gjallarhorn",
      activity: "Strike",
      tags: ~w(boss_damage burst easy)
    },
    %{
      id: "trinity_ghoul",
      name: "Trinity Ghoul",
      activity: "Strike",
      tags: ~w(add_clear chain lightning)
    },
    %{id: "sunshot", name: "Sunshot", activity: "Strike", tags: ~w(add_clear explosions fast)},
    %{
      id: "arbalest",
      name: "Arbalest",
      activity: "Strike",
      tags: ~w(anti_shield precision utility)
    },
    %{
      id: "riskrunner",
      name: "Riskrunner",
      activity: "Strike",
      tags: ~w(survivability add_clear damage_resist)
    }
  ]

  @armors [
    %{
      id: "ophidian_aspect",
      name: "Ophidian Aspect",
      class: "Warlock",
      activity: "Crucible",
      tags: ~w(neutral handling reload dueling)
    },
    %{
      id: "transversive_steps",
      name: "Transversive Steps",
      class: "Warlock",
      activity: "Crucible",
      tags: ~w(mobility reposition reload)
    },
    %{
      id: "the_stag",
      name: "The Stag",
      class: "Warlock",
      activity: "Crucible",
      tags: ~w(survivability rift anchor)
    },
    %{
      id: "sunbracers",
      name: "Sunbracers",
      class: "Warlock",
      activity: "Strike",
      tags: ~w(add_clear ability_spam fast)
    },
    %{
      id: "necrotic_grip",
      name: "Necrotic Grip",
      class: "Warlock",
      activity: "Strike",
      tags: ~w(add_clear poison synergy)
    },
    %{
      id: "contraverse_hold",
      name: "Contraverse Hold",
      class: "Warlock",
      activity: "Strike",
      tags: ~w(grenade uptime survivability)
    },
    %{
      id: "one_eyed_mask",
      name: "One-Eyed Mask",
      class: "Titan",
      activity: "Crucible",
      tags: ~w(dueling survivability snowball)
    },
    %{
      id: "dunemarchers",
      name: "Dunemarchers",
      class: "Titan",
      activity: "Crucible",
      tags: ~w(mobility chain damage)
    },
    %{
      id: "peacekeepers",
      name: "Peacekeepers",
      class: "Titan",
      activity: "Crucible",
      tags: ~w(smg handling strafe)
    },
    %{
      id: "heart_of_inmost_light",
      name: "Heart of Inmost Light",
      class: "Titan",
      activity: "Strike",
      tags: ~w(ability uptime fast)
    },
    %{
      id: "synthoceps",
      name: "Synthoceps",
      class: "Titan",
      activity: "Strike",
      tags: ~w(melee burst add_clear)
    },
    %{
      id: "cuirass_of_the_falling_star",
      name: "Cuirass of the Falling Star",
      class: "Titan",
      activity: "Strike",
      tags: ~w(boss_damage burst)
    },
    %{
      id: "st0mp_ee5",
      name: "St0mp-EE5",
      class: "Hunter",
      activity: "Crucible",
      tags: ~w(mobility evasive)
    },
    %{
      id: "wormhusk_crown",
      name: "Wormhusk Crown",
      class: "Hunter",
      activity: "Crucible",
      tags: ~w(survivability neutral)
    },
    %{
      id: "the_dragons_shadow",
      name: "The Dragon's Shadow",
      class: "Hunter",
      activity: "Crucible",
      tags: ~w(neutral reload handling)
    },
    %{
      id: "gyrfalcons_hauberk",
      name: "Gyrfalcon's Hauberk",
      class: "Hunter",
      activity: "Strike",
      tags: ~w(solo survivability damage uptime)
    },
    %{
      id: "star_eater_scales",
      name: "Star-Eater Scales",
      class: "Hunter",
      activity: "Strike",
      tags: ~w(boss_damage burst)
    },
    %{
      id: "omnioculus",
      name: "Omnioculus",
      class: "Hunter",
      activity: "Strike",
      tags: ~w(survivability invis solo)
    }
  ]

  def classes, do: @classes
  def activities, do: @activities

  def valid_class?(c), do: c in @classes
  def valid_activity?(a), do: a in @activities

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
    case Repo.get_by(CatalogItem, slug: id, slot: "weapon") do
      nil -> Enum.find(@weapons, &(&1.id == id))
      item -> to_public_item(item)
    end
  end

  def armor_by_id(id) when is_binary(id) do
    case Repo.get_by(CatalogItem, slug: id, slot: "armor") do
      nil -> Enum.find(@armors, &(&1.id == id))
      item -> to_public_item(item)
    end
  end

  def default_weapons, do: @weapons
  def default_armors, do: @armors

  defp db_ranked_items(class, activity, slot) do
    CatalogRanking
    |> join(:inner, [r], i in CatalogItem, on: i.id == r.catalog_item_id)
    |> where([r, i], r.class == ^class and r.activity == ^activity and r.slot == ^slot)
    |> where([r, i], i.review_state == "ready")
    |> order_by([r, _i], asc: r.rank)
    |> select([_r, i], i)
    |> Repo.all()
    |> Enum.map(&to_public_item/1)
  end

  defp to_public_item(%CatalogItem{} = item) do
    %{
      id: item.slug,
      name: item.name,
      class: item.class,
      tags: item.tags || [],
      item_type_display_name: item.item_type_display_name,
      tier_name: item.tier_name,
      meta_notes: item.meta_notes || "",
      source: item.source,
      review_state: item.review_state
    }
  end
end
