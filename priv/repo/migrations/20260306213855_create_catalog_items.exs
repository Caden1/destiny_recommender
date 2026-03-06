defmodule DestinyRecommender.Repo.Migrations.CreateCatalogItems do
  use Ecto.Migration

  def change do
    create table(:catalog_items) do
      add(:slug, :string, null: false)
      add(:bungie_hash, :bigint)
      add(:name, :string, null: false)
      add(:slot, :string, null: false)
      add(:class, :string, null: false, default: "Any")
      add(:item_type_display_name, :string)
      add(:tier_name, :string)
      add(:tags, {:array, :string}, null: false, default: [])
      add(:meta_notes, :text, null: false, default: "")
      add(:review_state, :string, null: false, default: "needs_review")
      add(:source, :string, null: false, default: "manifest")
      add(:manifest_version, :string)
      add(:raw, :map, null: false, default: %{})

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:catalog_items, [:slug]))
    create(unique_index(:catalog_items, [:bungie_hash]))
    create(index(:catalog_items, [:slot, :class, :review_state]))
  end
end
