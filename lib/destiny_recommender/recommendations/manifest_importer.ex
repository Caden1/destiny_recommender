defmodule DestinyRecommender.Recommendations.ManifestImporter do
  @moduledoc """
  Imports a filtered slice of the Bungie manifest into `catalog_items`.

  Manifest data is treated as canonical for item identity, but we preserve the
  human-authored fields that live on top of it (`tags`, `meta_notes`, review
  state, and recommended activities).
  """

  alias DestinyRecommender.Recommendations.CatalogItem
  alias DestinyRecommender.Repo

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
          manifest_version: manifest_version,
          raw: item
        }
    end
  end

  defp upsert_item!(attrs) do
    existing_item = Repo.get_by(CatalogItem, bungie_hash: attrs.bungie_hash) || Repo.get_by(CatalogItem, slug: attrs.slug)

    case existing_item do
      nil ->
        insert_new_item!(attrs)

      %CatalogItem{} = item ->
        update_existing_item!(item, attrs)
    end
  end

  defp insert_new_item!(attrs) do
    %CatalogItem{}
    |> CatalogItem.changeset(%{
      slug: attrs.slug,
      bungie_hash: attrs.bungie_hash,
      name: attrs.name,
      slot: attrs.slot,
      class: attrs.class,
      item_type_display_name: attrs.item_type_display_name,
      tier_name: attrs.tier_name,
      source: attrs.source,
      review_state: "needs_review",
      recommended_activities: [],
      manifest_version: attrs.manifest_version,
      raw: attrs.raw
    })
    |> Repo.insert!()
  end

  defp update_existing_item!(item, attrs) do
    # Human-curated data is preserved on update. The manifest refresh should not
    # erase tags, notes, review state, or activity suitability.
    item
    |> CatalogItem.changeset(%{
      slug: attrs.slug,
      bungie_hash: attrs.bungie_hash,
      name: attrs.name,
      slot: attrs.slot,
      class: attrs.class,
      item_type_display_name: attrs.item_type_display_name,
      tier_name: attrs.tier_name,
      source: "manifest",
      manifest_version: attrs.manifest_version,
      raw: attrs.raw,
      tags: item.tags,
      recommended_activities: item.recommended_activities,
      meta_notes: item.meta_notes,
      review_state: item.review_state
    })
    |> Repo.update!()
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace("'", "")
    |> String.replace(~r/[^a-z0-9]+/u, "_")
    |> String.trim("_")
  end
end
