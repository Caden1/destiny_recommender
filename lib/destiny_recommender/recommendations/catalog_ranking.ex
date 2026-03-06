defmodule DestinyRecommender.Recommendations.CatalogRanking do
  use Ecto.Schema
  import Ecto.Changeset

  @classes ~w(Warlock Titan Hunter)
  @activities ~w(Crucible Strike)
  @slots ~w(weapon armor)

  schema "catalog_rankings" do
    field(:class, :string)
    field(:activity, :string)
    field(:slot, :string)
    field(:rank, :integer)

    belongs_to(:catalog_item, DestinyRecommender.Recommendations.CatalogItem)
    belongs_to(:proposal, DestinyRecommender.Recommendations.CatalogProposal)

    timestamps(type: :utc_datetime)
  end

  def changeset(ranking, attrs) do
    ranking
    |> cast(attrs, [:class, :activity, :slot, :rank, :catalog_item_id, :proposal_id])
    |> validate_required([:class, :activity, :slot, :rank, :catalog_item_id])
    |> validate_inclusion(:class, @classes)
    |> validate_inclusion(:activity, @activities)
    |> validate_inclusion(:slot, @slots)
    |> validate_number(:rank, greater_than: 0)
    |> foreign_key_constraint(:catalog_item_id)
    |> foreign_key_constraint(:proposal_id)
    |> unique_constraint([:class, :activity, :slot, :rank],
      name: :catalog_rankings_class_activity_slot_rank_index
    )
  end
end
