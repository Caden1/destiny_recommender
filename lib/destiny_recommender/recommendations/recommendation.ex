defmodule DestinyRecommender.Recommendations.Recommendation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @why_max_length 400
  @tip_max_length 300
  @ascii_text_regex ~r/^[\t\n\r\x20-\x7E]+$/

  embedded_schema do
    field(:weapon_id, :string)
    field(:armor_id, :string)
    field(:why, :string)
    field(:playstyle_tips, {:array, :string}, default: [])
  end

  def why_max_length, do: @why_max_length
  def tip_max_length, do: @tip_max_length

  def changeset(attrs, weapon_ids, armor_ids) when is_list(weapon_ids) and is_list(armor_ids) do
    %__MODULE__{}
    |> cast(attrs, [:weapon_id, :armor_id, :why, :playstyle_tips])
    |> validate_required([:weapon_id, :armor_id, :why, :playstyle_tips])
    |> validate_inclusion(:weapon_id, weapon_ids)
    |> validate_inclusion(:armor_id, armor_ids)
    |> validate_length(:why, max: @why_max_length)
    |> validate_format(:why, @ascii_text_regex,
      message: "must contain only English ASCII characters"
    )
    |> validate_length(:playstyle_tips, min: 1, max: 6)
    |> validate_tip_lengths()
    |> validate_tip_characters()
  end

  defp validate_tip_lengths(changeset) do
    validate_change(changeset, :playstyle_tips, fn :playstyle_tips, tips ->
      if Enum.all?(tips, &(String.length(&1) <= @tip_max_length)) do
        []
      else
        [
          playstyle_tips:
            {"each tip should be at most %{count} character(s)",
             [count: @tip_max_length, validation: :length, kind: :max, type: :string]}
        ]
      end
    end)
  end

  defp validate_tip_characters(changeset) do
    validate_change(changeset, :playstyle_tips, fn :playstyle_tips, tips ->
      if Enum.all?(tips, &(is_binary(&1) and Regex.match?(@ascii_text_regex, &1))) do
        []
      else
        [
          playstyle_tips:
            {"each tip must contain only English ASCII characters", [validation: :format]}
        ]
      end
    end)
  end
end
