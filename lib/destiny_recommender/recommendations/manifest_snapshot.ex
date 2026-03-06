defmodule DestinyRecommender.Recommendations.ManifestSnapshot do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending synced failed)

  schema "manifest_snapshots" do
    field(:version, :string)
    field(:locale, :string, default: "en")
    field(:items_path, :string)
    field(:status, :string, default: "pending")
    field(:error, :string)
    field(:checked_at, :utc_datetime)
    field(:synced_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [:version, :locale, :items_path, :status, :error, :checked_at, :synced_at])
    |> validate_required([:version, :locale, :status])
    |> validate_length(:version, min: 1, max: 255)
    |> validate_length(:locale, min: 1, max: 10)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint([:version, :locale], name: :manifest_snapshots_version_locale_index)
  end
end
