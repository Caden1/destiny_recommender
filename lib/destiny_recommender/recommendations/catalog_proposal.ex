defmodule DestinyRecommender.Recommendations.CatalogProposal do
  use Ecto.Schema
  import Ecto.Changeset

  @classes ~w(Warlock Titan Hunter)
  @activities ~w(Crucible Strike)
  @statuses ~w(pending approved rejected)

  schema "catalog_proposals" do
    field(:manifest_version, :string)
    field(:class, :string)
    field(:activity, :string)
    field(:status, :string, default: "pending")
    field(:weapon_slugs, {:array, :string}, default: [])
    field(:armor_slugs, {:array, :string}, default: [])
    field(:summary, :string, default: "")
    field(:response_json, :map, default: %{})
    field(:approved_at, :utc_datetime)
    field(:rejected_at, :utc_datetime)

    has_many(:rankings, DestinyRecommender.Recommendations.CatalogRanking,
      foreign_key: :proposal_id
    )

    timestamps(type: :utc_datetime)
  end

  def changeset(proposal, attrs) do
    proposal
    |> cast(attrs, [
      :manifest_version,
      :class,
      :activity,
      :status,
      :weapon_slugs,
      :armor_slugs,
      :summary,
      :response_json,
      :approved_at,
      :rejected_at
    ])
    |> validate_required([
      :class,
      :activity,
      :status,
      :weapon_slugs,
      :armor_slugs,
      :summary,
      :response_json
    ])
    |> validate_inclusion(:class, @classes)
    |> validate_inclusion(:activity, @activities)
    |> validate_inclusion(:status, @statuses)
    |> validate_change(:weapon_slugs, &validate_string_list/2)
    |> validate_change(:armor_slugs, &validate_string_list/2)
    |> validate_length(:weapon_slugs, min: 1, max: 20)
    |> validate_length(:armor_slugs, min: 1, max: 20)
    |> validate_length(:summary, max: 2000)
  end

  defp validate_string_list(field, values) do
    if Enum.all?(values, &is_binary/1) do
      []
    else
      [{field, "must be a list of strings"}]
    end
  end
end
