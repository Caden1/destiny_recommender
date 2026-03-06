defmodule DestinyRecommender.Recommendations.Notes do
  @moduledoc false

  import Ecto.Query
  import Pgvector.Ecto.Query

  alias DestinyRecommender.Repo
  alias DestinyRecommender.OpenAI
  alias DestinyRecommender.Recommendations.BuildNote

  @max_notes 5
  @max_bullet_chars 220

  # Public: returns list of short bullet strings for prompt injection
  def retrieve_note_bullets(class, activity, limit \\ 5) do
    limit = min(limit, @max_notes)

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
  end

  # Internal: vector search in Postgres
  def semantic_search(class, activity, query_text, limit) do
    with {:ok, embedding} <- OpenAI.create_embedding(query_text) do
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
end
