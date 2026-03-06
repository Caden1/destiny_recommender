defmodule DestinyRecommender.Repo.Migrations.CreateManifestSnapshots do
  use Ecto.Migration

  def change do
    create table(:manifest_snapshots) do
      add(:version, :string, null: false)
      add(:locale, :string, null: false, default: "en")
      add(:items_path, :string)
      add(:status, :string, null: false, default: "pending")
      add(:error, :text)
      add(:checked_at, :utc_datetime)
      add(:synced_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:manifest_snapshots, [:version, :locale]))
  end
end
