alias DestinyRecommender.Repo
alias DestinyRecommender.Recommendations.{Catalog, CatalogItem}

items =
  Enum.map(Catalog.default_weapons(), fn item ->
    %{
      slug: item.id,
      name: item.name,
      slot: "weapon",
      class: "Any",
      tags: item.tags,
      source: "seed",
      review_state: "ready",
      meta_notes: ""
    }
  end) ++
    Enum.map(Catalog.default_armors(), fn item ->
      %{
        slug: item.id,
        name: item.name,
        slot: "armor",
        class: item.class,
        tags: item.tags,
        source: "seed",
        review_state: "ready",
        meta_notes: ""
      }
    end)

Enum.each(items, fn attrs ->
  %CatalogItem{}
  |> CatalogItem.changeset(attrs)
  |> Repo.insert!(on_conflict: :nothing, conflict_target: :slug)
end)

IO.puts("Seeded catalog_items from hardcoded catalog")
