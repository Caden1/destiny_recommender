defmodule DestinyRecommender.Recommendations.Recommendation do
  @moduledoc """
  Embedded schema used to validate and normalize the model's structured output.

  The model still returns JSON, but the UI never trusts that JSON directly. We run
  the payload through an Ecto changeset so we can enforce the exact fields and
  candidate IDs we allow.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @why_max_length 400
  @tip_max_length 300

  embedded_schema do
    field(:weapon_id, :string)
    field(:armor_id, :string)
    field(:why, :string)
    field(:playstyle_tips, {:array, :string}, default: [])
  end

  def why_max_length, do: @why_max_length
  def tip_max_length, do: @tip_max_length

  def changeset(attrs, weapon_ids, armor_ids) when is_list(weapon_ids) and is_list(armor_ids) do
    attrs = normalize_attrs(attrs)

    %__MODULE__{}
    |> cast(attrs, [:weapon_id, :armor_id, :why, :playstyle_tips])
    |> validate_required([:weapon_id, :armor_id, :why, :playstyle_tips])
    |> validate_inclusion(:weapon_id, weapon_ids)
    |> validate_inclusion(:armor_id, armor_ids)
    |> validate_length(:why, min: 1, max: @why_max_length)
    |> validate_length(:playstyle_tips, min: 1, max: 6)
    |> validate_tip_lengths()
    |> validate_tip_contents()
  end

  @doc """
  Normalizes common Unicode punctuation into plain ASCII-friendly equivalents.

  This keeps the UX forgiving: a smart quote or em dash from the model should not
  make an otherwise valid recommendation fail.
  """
  def normalize_attrs(attrs) when is_map(attrs) do
    attrs
    |> Map.update("why", nil, &normalize_text/1)
    |> Map.update("playstyle_tips", [], fn
      tips when is_list(tips) -> Enum.map(tips, &normalize_text/1)
      other -> other
    end)
  end

  def normalize_attrs(other), do: other

  def normalize_text(text) when is_binary(text) do
    text
    |> String.replace("’", "'")
    |> String.replace("‘", "'")
    |> String.replace("“", "\"")
    |> String.replace("”", "\"")
    |> String.replace("–", "-")
    |> String.replace("—", "-")
    |> String.replace("…", "...")
    |> String.replace(" ", " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  def normalize_text(other), do: other

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

  defp validate_tip_contents(changeset) do
    validate_change(changeset, :playstyle_tips, fn :playstyle_tips, tips ->
      if Enum.all?(tips, &(is_binary(&1) and String.trim(&1) != "")) do
        []
      else
        [playstyle_tips: {"each tip must be a non-empty string", [validation: :required]}]
      end
    end)
  end
end
