defmodule DestinyRecommender.Recommendations.AIRecommender do
  @moduledoc """
  Fast, bounded online recommender.

  This module is intentionally *not* an open-ended chatbot. It follows a very
  small agent loop:

    1. gather a validated candidate set
    2. assemble a compact context pack
    3. ask the model to choose exactly one weapon and one armor
    4. validate the JSON output
    5. retry once with an even smaller context if the model drifts

  The model chooses from server-approved IDs; it never invents Destiny items.
  """

  alias DestinyRecommender.Recommendations.{
    Catalog,
    ContextPack,
    Notes,
    Recommendation,
    RecommendationCache
  }

  @max_notes 5
  @max_retries 1

  def recommend(class, activity) do
    context_pack = build_context_pack(class, activity)
    cache_key = ContextPack.cache_key(context_pack)

    :telemetry.execute(
      [:destiny_recommender, :recommendation, :context],
      %{
        candidate_count:
          length(context_pack.candidates.weapons) + length(context_pack.candidates.armors),
        note_count: length(context_pack.note_bullets),
        prompt_characters: ContextPack.prompt_character_count(context_pack)
      },
      %{class: class, activity: activity, retry_count: context_pack.retry_count}
    )

    RecommendationCache.get_or_store(cache_key, fn ->
      run_recommendation(context_pack, @max_retries)
    end)
  end

  defp build_context_pack(class, activity) do
    weapons = Catalog.weapons_for(class, activity)
    armors = Catalog.armors_for(class, activity)

    note_bullets =
      case Notes.retrieve_note_bullets(class, activity, @max_notes) do
        {:ok, bullets} -> bullets
        {:error, _reason} -> []
      end

    ContextPack.new(
      class,
      activity,
      weapons,
      armors,
      note_bullets,
      Recommendation.why_max_length(),
      Recommendation.tip_max_length()
    )
  end

  defp run_recommendation(%ContextPack{} = context_pack, retries_remaining) do
    started_at = System.monotonic_time()

    result =
      with payload <- build_payload(context_pack),
           {:ok, body} <- openai_client().create_response(payload),
           {:ok, attrs} <- decode_output_json(body),
           changeset <-
             Recommendation.changeset(
               attrs,
               ContextPack.weapon_ids(context_pack),
               ContextPack.armor_ids(context_pack)
             ),
           {:ok, recommendation} <- apply_action(changeset, :insert) do
        {:ok, recommendation}
      end

    duration_native = System.monotonic_time() - started_at

    case result do
      {:ok, recommendation} ->
        :telemetry.execute(
          [:destiny_recommender, :recommendation, :success],
          %{duration: duration_native},
          %{
            class: context_pack.request.class,
            activity: context_pack.request.activity,
            retry_count: context_pack.retry_count,
            weapon_id: recommendation.weapon_id,
            armor_id: recommendation.armor_id
          }
        )

        {:ok, recommendation}

      {:error, reason} ->
        maybe_retry(context_pack, retries_remaining, reason)
    end
  end

  defp maybe_retry(%ContextPack{} = context_pack, retries_remaining, reason)
       when retries_remaining > 0 do
    if retryable_reason?(reason) do
      :telemetry.execute(
        [:destiny_recommender, :recommendation, :retry],
        %{count: 1},
        %{
          class: context_pack.request.class,
          activity: context_pack.request.activity,
          retry_count: context_pack.retry_count,
          reason: inspect(reason)
        }
      )

      context_pack
      |> ContextPack.shrink_for_retry()
      |> run_recommendation(retries_remaining - 1)
    else
      {:error, reason}
    end
  end

  defp maybe_retry(_context_pack, _retries_remaining, reason), do: {:error, reason}

  defp retryable_reason?({:invalid_model_output, _changeset}), do: true
  defp retryable_reason?(:missing_output_text), do: true
  defp retryable_reason?(:unexpected_openai_response_shape), do: true
  defp retryable_reason?(%Jason.DecodeError{}), do: true
  defp retryable_reason?(_reason), do: false

  defp build_payload(%ContextPack{} = context_pack) do
    %{
      "model" => openai_client().model(),
      "input" => [
        %{
          "role" => "system",
          "content" => system_prompt(context_pack)
        },
        %{
          "role" => "user",
          "content" => user_prompt(context_pack)
        }
      ],
      "text" => %{
        "format" => %{
          "type" => "json_schema",
          "name" => "destiny_recommendation",
          "schema" => json_schema(context_pack),
          "strict" => true
        }
      }
    }
  end

  defp system_prompt(%ContextPack{request: %{activity: activity}, retry_count: retry_count}) do
    base_prompt = [
      "You are a Destiny 2 solo loadout assistant.",
      "Task:",
      "- Choose EXACTLY one exotic weapon AND one exotic armor from the provided candidates.",
      "- Assume the player is SOLO (no fireteam).",
      case activity do
        "Crucible" -> "- Optimize for getting the MOST kills in Crucible."
        "Strike" -> "- Optimize for the FASTEST solo Strike completion."
      end,
      "",
      "Hard rules:",
      "- Use only the candidate IDs provided.",
      "- Do not invent items.",
      "- If notes mention items not in candidates, ignore those names.",
      "- Output MUST match the JSON schema exactly."
    ]

    retry_line =
      if retry_count > 0 do
        [
          "",
          "Retry rule:",
          "- The previous output failed validation. Copy candidate IDs exactly as written."
        ]
      else
        []
      end

    Enum.join(base_prompt ++ retry_line, "\n")
  end

  defp user_prompt(%ContextPack{} = context_pack) do
    notes_text =
      case context_pack.note_bullets do
        [] -> "None."
        bullets -> Enum.map_join(bullets, "\n", &("- " <> &1))
      end

    """
    Request:
    - class: #{context_pack.request.class}
    - activity: #{context_pack.request.activity}
    - solo: true
    - goal: #{context_pack.request.goal}

    Constraints:
    #{Enum.map_join(context_pack.constraints, "\n", &("- " <> &1))}

    Weapon candidates:
    #{format_candidates(context_pack.candidates.weapons)}

    Armor candidates:
    #{format_candidates(context_pack.candidates.armors)}

    Retrieved build notes:
    #{notes_text}

    Keep \"why\" at #{context_pack.output_limits.why_max_length} characters or fewer.
    Keep each entry in \"playstyle_tips\" at #{context_pack.output_limits.tip_max_length} characters or fewer.
    """
  end

  defp format_candidates(candidates) do
    Enum.map_join(candidates, "\n", fn candidate ->
      note_segment =
        case candidate.meta_notes do
          "" -> ""
          note -> " | meta_notes: #{note}"
        end

      "- id: #{candidate.id} | name: #{candidate.name} | tags: #{Enum.join(candidate.tags, ", ")}#{note_segment}"
    end)
  end

  defp json_schema(%ContextPack{} = context_pack) do
    %{
      "type" => "object",
      "additionalProperties" => false,
      "properties" => %{
        "weapon_id" => %{"type" => "string", "enum" => ContextPack.weapon_ids(context_pack)},
        "armor_id" => %{"type" => "string", "enum" => ContextPack.armor_ids(context_pack)},
        "why" => %{
          "type" => "string",
          "minLength" => 1,
          "maxLength" => context_pack.output_limits.why_max_length
        },
        "playstyle_tips" => %{
          "type" => "array",
          "items" => %{
            "type" => "string",
            "minLength" => 1,
            "maxLength" => context_pack.output_limits.tip_max_length
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
        %{"type" => "output_text", "text" => text} when is_binary(text) -> text
        _ -> nil
      end)

    if is_binary(text), do: Jason.decode(text), else: {:error, :missing_output_text}
  end

  defp decode_output_json(_), do: {:error, :unexpected_openai_response_shape}

  defp apply_action(changeset, action) do
    case Ecto.Changeset.apply_action(changeset, action) do
      {:ok, struct} -> {:ok, struct}
      {:error, changeset} -> {:error, {:invalid_model_output, changeset}}
    end
  end

  defp openai_client do
    Application.get_env(:destiny_recommender, :openai_client, DestinyRecommender.OpenAI)
  end
end
