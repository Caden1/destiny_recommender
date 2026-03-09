defmodule DestinyRecommender.Recommendations.Notes do
  @moduledoc """
  Small helper for retrieving short RAG note bullets.

  The recommendation prompt never gets an unbounded blob of text. We only pull a
  handful of short bullets, and we skip the embedding call entirely when there are
  no notes for the current class/activity.
  """

  import Ecto.Query
  import Pgvector.Ecto.Query

  alias DestinyRecommender.Recommendations.BuildNote
  alias DestinyRecommender.Repo

  @max_notes 5
  @max_bullet_chars 220

  def retrieve_note_bullets(class, activity, limit \\ 5) do
    limit = limit |> min(@max_notes) |> max(1)

    if any_notes_for?(class, activity) do
      query_text =
        case activity do
          "Crucible" ->
            "Destiny 2 solo #{class} Crucible: maximize kills. Reliable duels, positioning, survivability."

          "Strike" ->
            "Destiny 2 solo #{class} Strike: fastest clear. Add clear, boss damage, survivability, tempo."
        end

      with {:ok, notes} <- semantic_search(class, activity, query_text, limit) do
        {:ok, Enum.map(notes, &to_prompt_bullet/1)}
      end
    else
      {:ok, []}
    end
  end

  def any_notes_for?(class, activity) do
    BuildNote
    |> where([n], n.class == "Any" or n.class == ^class)
    |> where([n], n.activity == "Any" or n.activity == ^activity)
    |> select([_n], 1)
    |> limit(1)
    |> Repo.exists?()
  end

  def semantic_search(class, activity, query_text, limit) do
    with {:ok, embedding} <- openai_client().create_embedding(query_text) do
      qvec = Pgvector.new(embedding)

      notes =
        BuildNote
        |> where([n], n.class == "Any" or n.class == ^class)
        |> where([n], n.activity == "Any" or n.activity == ^activity)
        |> order_by([n], cosine_distance(n.embedding, ^qvec))
        |> limit(^limit)
        |> Repo.all()

      {:ok, notes}
    end
  end

  defp to_prompt_bullet(%BuildNote{content: content, tags: tags}) do
    tag_prefix =
      case tags do
        [] -> ""
        _ -> "[tags: " <> Enum.join(tags, ", ") <> "] "
      end

    bullet =
      (tag_prefix <> String.trim(content))
      |> String.replace(~r/\s+/, " ")

    if String.length(bullet) > @max_bullet_chars do
      String.slice(bullet, 0, @max_bullet_chars - 1) <> "…"
    else
      bullet
    end
  end

  defp openai_client do
    Application.get_env(:destiny_recommender, :openai_client, DestinyRecommender.OpenAI)
  end
end
