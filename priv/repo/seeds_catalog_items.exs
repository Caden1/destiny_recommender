alias DestinyRecommender.Recommendations.{Catalog, CatalogItem}
alias DestinyRecommender.Repo

# These rows keep the local MVP usable even before the Bungie manifest pipeline is
# exercised. The offline curator pipeline ignores them whenever a manifest version
# is supplied, so they do not contaminate the v3 flow.
items =
  Enum.map(Catalog.default_weapons(), fn item ->
    %{
      slug: item.slug,
      bungie_hash: item[:bungie_hash],
      name: item.name,
      slot: "weapon",
      class: "Any",
      tags: item.tags,
      recommended_activities: item.recommended_activities,
      source: "seed",
      review_state: "ready",
      meta_notes: "",
      raw: %{"seeded" => true}
    }
  end) ++
    Enum.map(Catalog.default_armors(), fn item ->
      %{
        slug: item.slug,
        bungie_hash: item[:bungie_hash],
        name: item.name,
        slot: "armor",
        class: item.class,
        tags: item.tags,
        recommended_activities: item.recommended_activities,
        source: "seed",
        review_state: "ready",
        meta_notes: "",
        raw: %{"seeded" => true}
      }
    end)

Enum.each(items, fn attrs ->
  case Repo.get_by(CatalogItem, slug: attrs.slug) do
    nil ->
      %CatalogItem{}
      |> CatalogItem.changeset(attrs)
      |> Repo.insert!()

    %CatalogItem{} = existing_item ->
      # Seed rows are updated in place so rerunning the script is idempotent.
      existing_item
      |> CatalogItem.changeset(attrs)
      |> Repo.update!()
  end
end)

IO.puts("Seeded catalog_items from the hardcoded fallback catalog")
