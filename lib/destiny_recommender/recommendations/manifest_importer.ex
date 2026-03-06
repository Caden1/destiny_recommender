defmodule DestinyRecommender.Recommendations.ManifestImporter do
  @moduledoc false

  alias DestinyRecommender.Repo
  alias DestinyRecommender.Recommendations.CatalogItem

  def import_inventory_items!(items_map, manifest_version) when is_map(items_map) do
    items_map
    |> Enum.map(fn {hash, item} -> to_catalog_attrs(hash, item, manifest_version) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.each(&upsert_item!/1)
  end

  defp to_catalog_attrs(hash, item, manifest_version) do
    tier_name = get_in(item, ["inventory", "tierTypeName"])
    equippable = item["equippable"] == true

    slot =
      case item["itemType"] do
        3 -> "weapon"
        2 -> "armor"
        _ -> nil
      end

    class =
      case item["classType"] do
        0 -> "Titan"
        1 -> "Hunter"
        2 -> "Warlock"
        3 -> "Any"
        _ -> "Any"
      end

    cond do
      not equippable ->
        nil

      tier_name != "Exotic" ->
        nil

      is_nil(slot) ->
        nil

      true ->
        name = get_in(item, ["displayProperties", "name"]) || "unknown_item"

        %{
          slug: slugify(name),
          bungie_hash: String.to_integer(hash),
          name: name,
          slot: slot,
          class: class,
          item_type_display_name: item["itemTypeDisplayName"],
          tier_name: tier_name,
          source: "manifest",
          review_state: "needs_review",
          manifest_version: manifest_version,
          raw: item
        }
    end
  end

  defp upsert_item!(attrs) do
    now = DateTime.utc_now()

    Repo.insert!(
      %CatalogItem{
        slug: attrs.slug,
        bungie_hash: attrs.bungie_hash,
        name: attrs.name,
        slot: attrs.slot,
        class: attrs.class,
        item_type_display_name: attrs.item_type_display_name,
        tier_name: attrs.tier_name,
        source: attrs.source,
        review_state: attrs.review_state,
        manifest_version: attrs.manifest_version,
        raw: attrs.raw,
        inserted_at: now,
        updated_at: now
      },
      on_conflict: [
        set: [
          name: attrs.name,
          slot: attrs.slot,
          class: attrs.class,
          item_type_display_name: attrs.item_type_display_name,
          tier_name: attrs.tier_name,
          manifest_version: attrs.manifest_version,
          raw: attrs.raw,
          updated_at: now
        ]
      ],
      conflict_target: :bungie_hash
    )
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "_")
    |> String.trim("_")
  end
end
