defmodule DestinyRecommender.Recommendations.AIRecommender do
  @moduledoc """
  Uses “context engineering” by sending a small, relevant candidate set for the chosen (class, activity).
  The output is constrained via JSON Schema with enums, so the model must select from the exact IDs.
  """

  alias DestinyRecommender.OpenAI
  alias DestinyRecommender.Recommendations.{Catalog, Recommendation}
  @ascii_text_pattern "^[\\x09\\x0A\\x0D\\x20-\\x7E]+$"

  def recommend(class, activity) do
    weapons = Catalog.weapons_for(activity)
    armors = Catalog.armors_for(class, activity)

    weapon_ids = Enum.map(weapons, & &1.id)
    armor_ids = Enum.map(armors, & &1.id)
    why_max_length = Recommendation.why_max_length()
    tip_max_length = Recommendation.tip_max_length()

    schema = json_schema(weapon_ids, armor_ids, why_max_length, tip_max_length)

    payload = %{
      "model" => OpenAI.model(),
      "input" => [
        %{
          "role" => "system",
          "content" => system_prompt()
        },
        %{
          "role" => "user",
          "content" =>
            user_prompt(class, activity, weapons, armors, why_max_length, tip_max_length)
        }
      ],
      "text" => %{
        "format" => %{
          "type" => "json_schema",
          "name" => "destiny_recommendation",
          "schema" => schema,
          "strict" => true
        }
      }
    }

    with {:ok, body} <- OpenAI.create_response(payload),
         {:ok, attrs} <- decode_output_json(body),
         changeset <- Recommendation.changeset(attrs, weapon_ids, armor_ids),
         {:ok, rec} <- apply_action(changeset, :insert) do
      {:ok, rec}
    end
  end

  defp system_prompt() do
    """
    You are a Destiny 2 solo loadout assistant.

    Task:
    - Choose EXACTLY one exotic weapon AND one exotic armor from the provided candidates.
    - Assume the player is SOLO (no fireteam).
    - If activity is Crucible: optimize for getting the MOST kills.
    - If activity is Strike: optimize for fastest SOLO completion (clear speed + safety).

    Hard rules:
    - Use only the candidate IDs provided.
    - Do not invent items.
    - Use English only. Do not include non-English scripts.
    - Output MUST match the JSON schema exactly.
    """
  end

  defp user_prompt(class, activity, weapons, armors, why_max_length, tip_max_length) do
    goal =
      case activity do
        "Crucible" ->
          "Most kills (solo). Favor reliability, dueling, ease-of-use, snowball potential."

        "Strike" ->
          "Fastest solo clear. Favor add clear + boss damage + survivability."
      end

    """
    Player:
    - class: #{class}
    - activity: #{activity}
    - constraint: solo (no fireteam)
    Goal: #{goal}

    Weapon candidates:
    #{format_candidates(weapons)}

    Armor candidates (must match class):
    #{format_candidates(armors)}

    Pick the best 1 weapon + 1 armor combo and provide a short reason + a few actionable tips.
    Keep "why" at #{why_max_length} characters or fewer.
    Keep each tip in "playstyle_tips" at #{tip_max_length} characters or fewer.
    Use English only.
    """
  end

  defp format_candidates(cands) do
    cands
    |> Enum.map(fn c ->
      "- id: #{c.id} | name: #{c.name} | tags: #{Enum.join(c.tags, ", ")}"
    end)
    |> Enum.join("\n")
  end

  defp json_schema(weapon_ids, armor_ids, why_max_length, tip_max_length) do
    %{
      "type" => "object",
      "additionalProperties" => false,
      "properties" => %{
        "weapon_id" => %{"type" => "string", "enum" => weapon_ids},
        "armor_id" => %{"type" => "string", "enum" => armor_ids},
        "why" => %{
          "type" => "string",
          "maxLength" => why_max_length,
          "pattern" => @ascii_text_pattern
        },
        "playstyle_tips" => %{
          "type" => "array",
          "items" => %{
            "type" => "string",
            "maxLength" => tip_max_length,
            "pattern" => @ascii_text_pattern
          },
          "minItems" => 1,
          "maxItems" => 6
        }
      },
      "required" => ["weapon_id", "armor_id", "why", "playstyle_tips"]
    }
  end

  defp decode_output_json(%{"output_text" => text}) when is_binary(text) do
    Jason.decode(text)
  end

  defp decode_output_json(%{"output" => output}) when is_list(output) do
    text =
      output
      |> Enum.flat_map(&(&1["content"] || []))
      |> Enum.find_value(fn
        %{"type" => "output_text", "text" => t} when is_binary(t) -> t
        _ -> nil
      end)

    if is_binary(text), do: Jason.decode(text), else: {:error, :missing_output_text}
  end

  defp decode_output_json(_), do: {:error, :unexpected_openai_response_shape}

  defp apply_action(changeset, action) do
    case Ecto.Changeset.apply_action(changeset, action) do
      {:ok, struct} -> {:ok, struct}
      {:error, cs} -> {:error, {:invalid_model_output, cs}}
    end
  end
end
