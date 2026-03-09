defmodule DestinyRecommender.Recommendations.CatalogItem do
  use Ecto.Schema
  import Ecto.Changeset

  @slots ~w(weapon armor)
  @classes ~w(Any Warlock Titan Hunter)
  @activities ~w(Crucible Strike)
  @review_states ~w(needs_review ready archived)
  @sources ~w(manifest seed manual)

  schema "catalog_items" do
    field(:slug, :string)
    field(:bungie_hash, :integer)
    field(:name, :string)
    field(:slot, :string)
    field(:class, :string, default: "Any")
    field(:item_type_display_name, :string)
    field(:tier_name, :string)
    field(:tags, {:array, :string}, default: [])
    field(:recommended_activities, {:array, :string}, default: [])
    field(:meta_notes, :string, default: "")
    field(:review_state, :string, default: "needs_review")
    field(:source, :string, default: "manifest")
    field(:manifest_version, :string)
    field(:raw, :map, default: %{})

    has_many(:rankings, DestinyRecommender.Recommendations.CatalogRanking)

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :slug,
      :bungie_hash,
      :name,
      :slot,
      :class,
      :item_type_display_name,
      :tier_name,
      :tags,
      :recommended_activities,
      :meta_notes,
      :review_state,
      :source,
      :manifest_version,
      :raw
    ])
    |> validate_required([:slug, :name, :slot, :class, :review_state, :source, :raw])
    |> validate_length(:slug, min: 1, max: 255)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_inclusion(:slot, @slots)
    |> validate_inclusion(:class, @classes)
    |> validate_inclusion(:review_state, @review_states)
    |> validate_inclusion(:source, @sources)
    |> normalize_tags()
    |> normalize_recommended_activities()
    |> validate_change(:tags, fn :tags, tags ->
      if Enum.all?(tags, &is_binary/1), do: [], else: [tags: "must be a list of strings"]
    end)
    |> validate_change(:recommended_activities, fn :recommended_activities, activities ->
      invalid = Enum.reject(activities, &(&1 in @activities))

      cond do
        not Enum.all?(activities, &is_binary/1) ->
          [recommended_activities: "must be a list of strings"]

        invalid != [] ->
          [recommended_activities: "contains invalid activity values"]

        true ->
          []
      end
    end)
    |> unique_constraint(:slug)
    |> unique_constraint(:bungie_hash)
  end

  defp normalize_tags(changeset) do
    update_change(changeset, :tags, fn tags ->
      tags
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()
    end)
  end

  defp normalize_recommended_activities(changeset) do
    update_change(changeset, :recommended_activities, fn activities ->
      activities
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()
    end)
  end
end
