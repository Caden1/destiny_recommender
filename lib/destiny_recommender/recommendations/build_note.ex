defmodule DestinyRecommender.Recommendations.BuildNote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "build_notes" do
    field(:slug, :string)
    field(:class, :string, default: "Any")
    field(:activity, :string, default: "Any")
    field(:content, :string)
    field(:tags, {:array, :string}, default: [])
    field(:embedding, Pgvector.Ecto.Vector)

    timestamps(type: :utc_datetime)
  end

  @classes ~w(Any Warlock Titan Hunter)
  @activities ~w(Any Crucible Strike)

  def changeset(note, attrs) do
    note
    |> cast(attrs, [:slug, :class, :activity, :content, :tags, :embedding])
    |> validate_required([:slug, :class, :activity, :content, :embedding])
    |> validate_inclusion(:class, @classes)
    |> validate_inclusion(:activity, @activities)
    |> validate_length(:content, min: 20, max: 400)
    |> unique_constraint(:slug)
  end
end
