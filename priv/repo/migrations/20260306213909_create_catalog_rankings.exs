defmodule DestinyRecommender.Repo.Migrations.CreateCatalogRankings do
  use Ecto.Migration

  def change do
    create table(:catalog_rankings) do
      add(:class, :string, null: false)
      add(:activity, :string, null: false)
      add(:slot, :string, null: false)
      add(:rank, :integer, null: false)
      add(:catalog_item_id, references(:catalog_items, on_delete: :delete_all), null: false)
      add(:proposal_id, references(:catalog_proposals, on_delete: :nilify_all))

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:catalog_rankings, [:class, :activity, :slot, :rank]))
    create(index(:catalog_rankings, [:catalog_item_id]))
  end
end
