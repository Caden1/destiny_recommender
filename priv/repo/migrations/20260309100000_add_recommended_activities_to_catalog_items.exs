defmodule DestinyRecommender.Repo.Migrations.AddRecommendedActivitiesToCatalogItems do
  use Ecto.Migration

  @crucible_slugs [
    "ace_of_spades",
    "thorn",
    "the_last_word",
    "no_time_to_explain",
    "le_monarque",
    "conditional_finality",
    "ophidian_aspect",
    "transversive_steps",
    "the_stag",
    "one_eyed_mask",
    "dunemarchers",
    "peacekeepers",
    "st0mp_ee5",
    "wormhusk_crown",
    "the_dragons_shadow"
  ]

  @strike_slugs [
    "witherhoard",
    "gjallarhorn",
    "trinity_ghoul",
    "sunshot",
    "arbalest",
    "riskrunner",
    "sunbracers",
    "necrotic_grip",
    "contraverse_hold",
    "heart_of_inmost_light",
    "synthoceps",
    "cuirass_of_the_falling_star",
    "gyrfalcons_hauberk",
    "star_eater_scales",
    "omnioculus"
  ]

  def up do
    alter table(:catalog_items) do
      add :recommended_activities, {:array, :string}, null: false, default: []
    end

    create index(:catalog_items, [:manifest_version, :review_state, :slot])

    execute(update_activity_sql(@crucible_slugs, "Crucible"))
    execute(update_activity_sql(@strike_slugs, "Strike"))
  end

  def down do
    drop index(:catalog_items, [:manifest_version, :review_state, :slot])

    alter table(:catalog_items) do
      remove :recommended_activities
    end
  end

  defp update_activity_sql(slugs, activity) do
    quoted_slugs = Enum.map_join(slugs, ", ", &"'#{&1}'")

    """
    UPDATE catalog_items
    SET recommended_activities = ARRAY['#{activity}']
    WHERE slug IN (#{quoted_slugs})
    """
  end
end
