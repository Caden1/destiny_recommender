defmodule DestinyRecommender.Repo.Migrations.CreateBuildNotes do
  use Ecto.Migration

  def change do
    create table(:build_notes) do
      add(:slug, :string, null: false)
      add(:class, :string, null: false, default: "Any")
      add(:activity, :string, null: false, default: "Any")
      add(:content, :text, null: false)
      add(:tags, {:array, :string}, null: false, default: [])
      add(:embedding, :vector, size: 1536, null: false)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:build_notes, [:slug]))

    # Optional: approximate vector index (useful once you have many notes)
    # Commented out for now, will add later.
    # create index("build_notes", ["embedding vector_cosine_ops"], using: :hnsw)
  end
end
