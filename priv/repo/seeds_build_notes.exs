alias DestinyRecommender.Repo
alias DestinyRecommender.OpenAI
alias DestinyRecommender.Recommendations.BuildNote

notes = [
  %{
    slug: "any_crucible_play_your_life",
    class: "Any",
    activity: "Crucible",
    tags: ["solo", "fundamentals"],
    content:
      "Solo Crucible: prioritize staying alive; take high-percentage duels and disengage early to preserve streaks."
  },
  %{
    slug: "warlock_crucible_rift_timing",
    class: "Warlock",
    activity: "Crucible",
    tags: ["rift", "positioning"],
    content:
      "Warlock Crucible: use rift as a tempo tool—place it after you win space, not before you peek a lane."
  },
  %{
    slug: "any_strike_tempo",
    class: "Any",
    activity: "Strike",
    tags: ["pve", "tempo"],
    content:
      "Solo Strike speed: keep forward momentum; clear only what blocks progress and use safe damage while moving."
  },
  %{
    slug: "hunter_strike_invis_escape",
    class: "Hunter",
    activity: "Strike",
    tags: ["survivability"],
    content:
      "Hunter solo PvE: keep an escape plan—use invis or distance to reset when you lose control of adds."
  }
]

contents = Enum.map(notes, & &1.content)

{:ok, embeddings} = OpenAI.create_embeddings(contents)

notes
|> Enum.zip(embeddings)
|> Enum.each(fn {note, embedding} ->
  attrs =
    note
    |> Map.put(:embedding, embedding)

  changeset = BuildNote.changeset(%BuildNote{}, attrs)

  Repo.insert!(changeset, on_conflict: :nothing, conflict_target: :slug)
end)

IO.puts("Seeded build notes: #{length(notes)}")
