defmodule DestinyRecommender.Repo.Migrations.CreateCatalogProposals do
  use Ecto.Migration

  def change do
    create table(:catalog_proposals) do
      add(:manifest_version, :string)
      add(:class, :string, null: false)
      add(:activity, :string, null: false)
      add(:status, :string, null: false, default: "pending")
      add(:weapon_slugs, {:array, :string}, null: false, default: [])
      add(:armor_slugs, {:array, :string}, null: false, default: [])
      add(:summary, :text, null: false, default: "")
      add(:response_json, :map, null: false, default: %{})
      add(:approved_at, :utc_datetime)
      add(:rejected_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(index(:catalog_proposals, [:status, :inserted_at]))
  end
end
