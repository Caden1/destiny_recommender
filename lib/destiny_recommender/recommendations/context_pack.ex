defmodule DestinyRecommender.Recommendations.ContextPack do
  @moduledoc """
  A small, explicit struct that captures the exact context sent to the online
  recommendation model.

  Keeping the prompt input in a first-class struct makes it much easier to:

    * test the recommendation pipeline deterministically
    * cache by the actual assembled context instead of only class/activity
    * log, diff, and shrink the context when a retry is needed

  This is the core "context engineering" unit in the app.
  """

  @enforce_keys [:request, :constraints, :candidates, :note_bullets, :output_limits]
  defstruct request: %{},
            constraints: [],
            candidates: %{weapons: [], armors: []},
            note_bullets: [],
            output_limits: %{},
            retry_count: 0

  @type candidate :: %{
          required(:id) => String.t(),
          required(:name) => String.t(),
          required(:tags) => list(String.t()),
          optional(:meta_notes) => String.t()
        }

  @type t :: %__MODULE__{
          request: map(),
          constraints: list(String.t()),
          candidates: %{weapons: list(candidate()), armors: list(candidate())},
          note_bullets: list(String.t()),
          output_limits: map(),
          retry_count: non_neg_integer()
        }

  @max_meta_notes_length 180

  @spec new(
          String.t(),
          String.t(),
          list(map()),
          list(map()),
          list(String.t()),
          pos_integer(),
          pos_integer()
        ) ::
          t()
  def new(class, activity, weapons, armors, note_bullets, why_max_length, tip_max_length) do
    %__MODULE__{
      request: %{
        class: class,
        activity: activity,
        solo: true,
        goal: goal_for(activity)
      },
      constraints: [
        "Return exactly 1 exotic weapon and exactly 1 exotic armor.",
        "Use only the candidate IDs provided.",
        "Armor must be equippable by the selected class.",
        "Assume solo play with no fireteam."
      ],
      candidates: %{
        weapons: Enum.map(weapons, &compact_candidate/1),
        armors: Enum.map(armors, &compact_candidate/1)
      },
      note_bullets: note_bullets,
      output_limits: %{
        why_max_length: why_max_length,
        tip_max_length: tip_max_length
      },
      retry_count: 0
    }
  end

  @doc """
  Builds a deterministic cache key from the assembled context pack.

  We cache by context, not only by `{class, activity}`, so cache entries change
  automatically when notes, candidates, or limits change.
  """
  @spec cache_key(t()) :: String.t()
  def cache_key(%__MODULE__{} = pack) do
    pack
    |> cache_payload()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @spec weapon_ids(t()) :: list(String.t())
  def weapon_ids(%__MODULE__{} = pack), do: Enum.map(pack.candidates.weapons, & &1.id)

  @spec armor_ids(t()) :: list(String.t())
  def armor_ids(%__MODULE__{} = pack), do: Enum.map(pack.candidates.armors, & &1.id)

  @doc """
  Returns a smaller context pack for the single retry path.

  The retry strips notes and keeps only the top slice of candidates so the model
  has less room to drift away from the constrained output.
  """
  @spec shrink_for_retry(t()) :: t()
  def shrink_for_retry(%__MODULE__{} = pack) do
    %__MODULE__{
      pack
      | candidates: %{
          weapons: Enum.take(pack.candidates.weapons, 6),
          armors: Enum.take(pack.candidates.armors, 4)
        },
        note_bullets: [],
        retry_count: pack.retry_count + 1
    }
  end

  @spec prompt_character_count(t()) :: non_neg_integer()
  def prompt_character_count(%__MODULE__{} = pack) do
    pack
    |> cache_payload()
    |> Jason.encode!()
    |> String.length()
  end

  defp compact_candidate(candidate) do
    %{
      id: candidate.id,
      name: candidate.name,
      tags: candidate.tags || [],
      meta_notes: truncate_text(candidate[:meta_notes] || "", @max_meta_notes_length)
    }
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

  defp goal_for("Crucible"), do: "maximize_kills"
  defp goal_for("Strike"), do: "fastest_solo_clear"

  defp cache_payload(%__MODULE__{} = pack) do
    %{
      request: pack.request,
      constraints: pack.constraints,
      candidates: pack.candidates,
      note_bullets: pack.note_bullets,
      output_limits: pack.output_limits,
      retry_count: pack.retry_count
    }
  end
end
