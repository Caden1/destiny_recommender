defmodule DestinyRecommender.Recommendations.Catalog do
  @moduledoc false

  @classes ~w(Warlock Titan Hunter)
  @activities ~w(Crucible Strike)

  # Note: Replace/expand these as you refine the sandbox/meta.
  @weapons [
    # Crucible-leaning
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

    # Strike-leaning
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
    # Warlock
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

    # Titan
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

    # Hunter
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

  def weapons_for(activity) when activity in @activities do
    Enum.filter(@weapons, &(&1.activity == activity))
  end

  def armors_for(class, activity) when class in @classes and activity in @activities do
    Enum.filter(@armors, &(&1.class == class and &1.activity == activity))
  end

  def weapon_by_id(id), do: Enum.find(@weapons, &(&1.id == id))
  def armor_by_id(id), do: Enum.find(@armors, &(&1.id == id))
end
