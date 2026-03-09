defmodule DestinyRecommender.Recommendations.CuratorAI do
  @moduledoc """
  Offline curator model wrapper used by the slow, human-reviewed v3 pipeline.

  Unlike the online recommender, this path can rank a larger reviewed candidate
  pool and produce a proposal for admin approval. The output is still tightly
  schema-constrained and slug-validated before anything is stored.
  """

  @max_weapons 30
  @max_armors 15
  @max_notes 5
  @max_meta_notes_length 180
  @max_summary_length 600

  @classes ~w(Warlock Titan Hunter)
  @activities ~w(Crucible Strike)

  @spec curate(String.t(), String.t(), list(map()), list(map()), list(String.t())) ::
          {:ok, map()} | {:error, term()}
  def curate(class, activity, weapon_candidates, armor_candidates, note_bullets)
      when is_list(weapon_candidates) and is_list(armor_candidates) and is_list(note_bullets) do
    with :ok <- validate_inputs(class, activity, weapon_candidates, armor_candidates),
         bounded_weapons <- bound_candidates(weapon_candidates, @max_weapons),
         bounded_armors <- bound_candidates(armor_candidates, @max_armors),
         bounded_notes <- bound_notes(note_bullets, @max_notes),
         {:ok, payload} <-
           build_payload(class, activity, bounded_weapons, bounded_armors, bounded_notes),
         {:ok, body} <- openai_client().create_response(payload),
         {:ok, attrs} <- decode_output_json(body),
         :ok <- validate_response(attrs, bounded_weapons, bounded_armors) do
      {:ok, attrs}
    end
  end

  def curate(_class, _activity, _weapon_candidates, _armor_candidates, _note_bullets) do
    {:error, :invalid_arguments}
  end

  defp validate_inputs(class, activity, weapon_candidates, armor_candidates) do
    cond do
      class not in @classes -> {:error, {:invalid_class, class}}
      activity not in @activities -> {:error, {:invalid_activity, activity}}
      weapon_candidates == [] -> {:error, :no_weapon_candidates}
      armor_candidates == [] -> {:error, :no_armor_candidates}
      true -> :ok
    end
  end

  defp build_payload(class, activity, weapon_candidates, armor_candidates, note_bullets) do
    weapon_slugs = Enum.map(weapon_candidates, & &1["slug"])
    armor_slugs = Enum.map(armor_candidates, & &1["slug"])

    weapon_count = min(10, length(weapon_slugs))
    armor_count = min(10, length(armor_slugs))

    if weapon_count < 1 or armor_count < 1 do
      {:error, :insufficient_candidates}
    else
      schema = json_schema(weapon_slugs, armor_slugs, weapon_count, armor_count)

      payload = %{
        "model" => openai_client().model(),
        "input" => [
          %{
            "role" => "system",
            "content" => system_prompt()
          },
          %{
            "role" => "user",
            "content" =>
              user_prompt(
                class,
                activity,
                weapon_candidates,
                armor_candidates,
                note_bullets,
                weapon_count,
                armor_count
              )
          }
        ],
        "text" => %{
          "format" => %{
            "type" => "json_schema",
            "name" => "catalog_curator_proposal",
            "schema" => schema,
            "strict" => true
          }
        }
      }

      {:ok, payload}
    end
  end

  defp system_prompt do
    """
    You are a Destiny 2 catalog curator for a solo loadout recommendation system.

    Your job:
    - rank the BEST reviewed candidate weapons and armor for a single class + activity combination
    - produce an ordered list of weapon slugs and armor slugs
    - produce a short summary

    Hard rules:
    - Use ONLY the candidate slugs provided.
    - Do NOT invent items.
    - Respect the exact output schema.
    - Rank for SOLO play only.
    - Use build note bullets only as supporting guidance.
    - Ignore any item names mentioned in notes if they are not in the candidate lists.

    Ranking goals:
    - Crucible: prioritize most kills, reliability, dueling, ease-of-use, survivability, and snowball potential.
    - Strike: prioritize fastest solo completion, add clear, boss damage, survivability, and consistency.

    Output ranking quality:
    - Put the strongest overall candidates first.
    - Prefer broadly effective, low-friction solo options over niche or fragile options.
    - The summary must be concise and mention the overall ranking logic.
    """
  end

  defp user_prompt(
         class,
         activity,
         weapon_candidates,
         armor_candidates,
         note_bullets,
         weapon_count,
         armor_count
       ) do
    goal =
      case activity do
        "Crucible" ->
          "Rank for solo Crucible: most kills, reliable duels, ease-of-use, survivability, tempo."

        "Strike" ->
          "Rank for solo Strikes: fastest clear, add clear, boss damage, survivability, consistency."
      end

    notes_text =
      case note_bullets do
        [] -> "None."
        bullets -> Enum.map_join(bullets, "\n", &("- " <> &1))
      end

    """
    Class: #{class}
    Activity: #{activity}
    #{goal}

    Return:
    - exactly #{weapon_count} ordered weapon slugs
    - exactly #{armor_count} ordered armor slugs
    - one short summary

    Weapon candidates:
    #{format_candidates(weapon_candidates)}

    Armor candidates:
    #{format_candidates(armor_candidates)}

    Top build note bullets:
    #{notes_text}
    """
  end

  defp format_candidates(candidates) do
    Enum.map_join(candidates, "\n", fn candidate ->
      slug = candidate["slug"] || ""
      name = candidate["name"] || ""
      type_name = candidate["item_type_display_name"] || ""
      tags = format_tags(candidate["tags"] || [])
      meta_notes = truncate_text(candidate["meta_notes"] || "", @max_meta_notes_length)

      "- slug: #{slug} | name: #{name} | item_type_display_name: #{type_name} | tags: #{tags} | meta_notes: #{meta_notes}"
    end)
  end

  defp format_tags(tags) when is_list(tags), do: Enum.join(tags, ", ")
  defp format_tags(_), do: ""

  defp json_schema(weapon_slugs, armor_slugs, weapon_count, armor_count) do
    %{
      "type" => "object",
      "additionalProperties" => false,
      "properties" => %{
        "weapon_slugs" => %{
          "type" => "array",
          "items" => %{"type" => "string", "enum" => weapon_slugs},
          "minItems" => weapon_count,
          "maxItems" => weapon_count,
          "uniqueItems" => true
        },
        "armor_slugs" => %{
          "type" => "array",
          "items" => %{"type" => "string", "enum" => armor_slugs},
          "minItems" => armor_count,
          "maxItems" => armor_count,
          "uniqueItems" => true
        },
        "summary" => %{
          "type" => "string",
          "maxLength" => @max_summary_length
        }
      },
      "required" => ["weapon_slugs", "armor_slugs", "summary"]
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
        %{"type" => "output_text", "text" => text} when is_binary(text) -> text
        _ -> nil
      end)

    if is_binary(text), do: Jason.decode(text), else: {:error, :missing_output_text}
  end

  defp decode_output_json(_), do: {:error, :unexpected_openai_response_shape}

  defp validate_response(
         %{"weapon_slugs" => weapon_slugs, "armor_slugs" => armor_slugs, "summary" => summary},
         weapon_candidates,
         armor_candidates
       ) do
    allowed_weapon_slugs = MapSet.new(Enum.map(weapon_candidates, & &1["slug"]))
    allowed_armor_slugs = MapSet.new(Enum.map(armor_candidates, & &1["slug"]))

    cond do
      not is_list(weapon_slugs) -> {:error, {:invalid_response_field, :weapon_slugs}}
      not is_list(armor_slugs) -> {:error, {:invalid_response_field, :armor_slugs}}
      not is_binary(summary) -> {:error, {:invalid_response_field, :summary}}
      String.length(summary) > @max_summary_length -> {:error, {:summary_too_long, String.length(summary)}}
      Enum.uniq(weapon_slugs) != weapon_slugs -> {:error, :duplicate_weapon_slugs}
      Enum.uniq(armor_slugs) != armor_slugs -> {:error, :duplicate_armor_slugs}
      Enum.any?(weapon_slugs, &(not MapSet.member?(allowed_weapon_slugs, &1))) -> {:error, :unknown_weapon_slug}
      Enum.any?(armor_slugs, &(not MapSet.member?(allowed_armor_slugs, &1))) -> {:error, :unknown_armor_slug}
      true -> :ok
    end
  end

  defp validate_response(_attrs, _weapon_candidates, _armor_candidates) do
    {:error, :invalid_response_shape}
  end

  defp bound_candidates(candidates, max_count) do
    candidates
    |> Enum.filter(&ready_candidate?/1)
    |> Enum.take(max_count)
    |> Enum.map(&compact_candidate/1)
  end

  defp ready_candidate?(%{"review_state" => "ready"}), do: true
  defp ready_candidate?(%{"review_state" => _}), do: false
  defp ready_candidate?(candidate) when is_map(candidate), do: not Map.has_key?(candidate, "review_state")
  defp ready_candidate?(_), do: false

  defp compact_candidate(candidate) do
    %{
      "slug" => candidate["slug"],
      "name" => candidate["name"],
      "item_type_display_name" => candidate["item_type_display_name"] || "",
      "tags" => normalize_tags(candidate["tags"]),
      "meta_notes" => truncate_text(candidate["meta_notes"] || "", @max_meta_notes_length)
    }
  end

  defp normalize_tags(tags) when is_list(tags), do: Enum.filter(tags, &is_binary/1)
  defp normalize_tags(_), do: []

  defp bound_notes(note_bullets, max_count) do
    note_bullets
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&truncate_text(&1, 220))
    |> Enum.take(max_count)
  end

  defp truncate_text(text, max_length) when is_binary(text) do
    trimmed =
      text
      |> String.replace(~r/\s+/, " ")
      |> String.trim()

    if String.length(trimmed) > max_length do
      String.slice(trimmed, 0, max_length - 1) <> "…"
    else
      trimmed
    end
  end

  defp openai_client do
    Application.get_env(:destiny_recommender, :openai_client, DestinyRecommender.OpenAI)
  end
end
