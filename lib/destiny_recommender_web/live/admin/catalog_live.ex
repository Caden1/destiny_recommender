defmodule DestinyRecommenderWeb.Admin.CatalogLive do
  use DestinyRecommenderWeb, :live_view

  import Ecto.Query

  alias Ecto.Multi
  alias DestinyRecommender.Repo

  alias DestinyRecommender.Recommendations.{
    CatalogItem,
    CatalogProposal,
    CatalogRanking
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_data(socket)}
  end

  @impl true
  def handle_event("save_item", params, socket) do
    id = parse_int(params["id"])
    tags = parse_tags(params["tags"])
    meta_notes = String.trim(params["meta_notes"] || "")

    result =
      with %CatalogItem{} = item <- Repo.get(CatalogItem, id),
           {:ok, _item} <-
             item
             |> CatalogItem.changeset(%{tags: tags, meta_notes: meta_notes})
             |> Repo.update() do
        :ok
      else
        nil -> {:error, :item_not_found}
        {:error, changeset} -> {:error, changeset}
      end

    case result do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Item updated.")
         |> load_data()}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not save item.")}
    end
  end

  @impl true
  def handle_event("mark_ready", %{"id" => id}, socket) do
    update_review_state(socket, id, "ready", "Item marked ready.")
  end

  @impl true
  def handle_event("archive_item", %{"id" => id}, socket) do
    update_review_state(socket, id, "archived", "Item archived.")
  end

  @impl true
  def handle_event("approve_proposal", %{"id" => id}, socket) do
    proposal =
      CatalogProposal
      |> Repo.get(id)

    case proposal do
      nil ->
        {:noreply, put_flash(socket, :error, "Proposal not found.")}

      %CatalogProposal{} = proposal ->
        case approve_proposal(proposal) do
          {:ok, _result} ->
            {:noreply,
             socket
             |> put_flash(:info, "Proposal approved and rankings published.")
             |> load_data()}

          {:error, _step, _reason, _changes} ->
            {:noreply, put_flash(socket, :error, "Could not approve proposal.")}
        end
    end
  end

  @impl true
  def handle_event("reject_proposal", %{"id" => id}, socket) do
    case Repo.get(CatalogProposal, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Proposal not found.")}

      %CatalogProposal{} = proposal ->
        case proposal
             |> CatalogProposal.changeset(%{
               status: "rejected",
               rejected_at: DateTime.utc_now(),
               approved_at: nil
             })
             |> Repo.update() do
          {:ok, _proposal} ->
            {:noreply,
             socket
             |> put_flash(:info, "Proposal rejected.")
             |> load_data()}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Could not reject proposal.")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl p-6 space-y-10">
      <.header>
        Catalog Admin
        <:subtitle>Review imported items and approve pending catalog proposals.</:subtitle>
      </.header>

      <section class="space-y-4">
        <div>
          <h2 class="text-xl font-semibold">Items needing review</h2>
          <p class="text-sm text-zinc-600">
            Review tags and notes, then mark items ready or archive them.
          </p>
        </div>

        <%= if @items_needing_review == [] do %>
          <div class="rounded-lg border p-4 text-sm text-zinc-600">
            No items currently need review.
          </div>
        <% else %>
          <div class="space-y-4">
            <%= for item <- @items_needing_review do %>
              <div class="rounded-xl border p-5 shadow-sm">
                <div class="mb-4 space-y-1">
                  <h3 class="text-lg font-semibold">{item.name}</h3>
                  <div class="text-sm text-zinc-600">
                    <span><strong>Slot:</strong> {item.slot}</span>
                    <span class="mx-2">•</span>
                    <span><strong>Class:</strong> {item.class}</span>
                    <span class="mx-2">•</span>
                    <span><strong>Item type:</strong> {item.item_type_display_name || "—"}</span>
                  </div>
                </div>

                <form phx-submit="save_item" class="space-y-4">
                  <input type="hidden" name="_id" value={item.id} />

                  <div>
                    <label class="mb-1 block text-sm font-medium">Current tags</label>
                    <input
                      type="text"
                      name="tags"
                      value={Enum.join(item.tags || [], ", ")}
                      class="w-full rounded-md border px-3 py-2"
                    />
                    <p class="mt-1 text-xs text-zinc-500">Comma-separated tags.</p>
                  </div>

                  <div>
                    <label class="mb-1 block text-sm font-medium">Meta notes</label>
                    <textarea
                      name="meta_notes"
                      rows="4"
                      class="w-full rounded-md border px-3 py-2"
                    ><%= item.meta_notes %></textarea>
                  </div>

                  <div class="flex flex-wrap gap-3">
                    <button
                      type="submit"
                      class="rounded-md bg-zinc-900 px-4 py-2 text-white hover:bg-zinc-700"
                    >
                      Save tags/notes
                    </button>

                    <button
                      type="button"
                      phx-click="mark_ready"
                      phx-value-id={item.id}
                      class="rounded-md border px-4 py-2 hover:bg-zinc-50"
                    >
                      Mark ready
                    </button>

                    <button
                      type="button"
                      phx-click="archive_item"
                      phx-value-id={item.id}
                      class="rounded-md border px-4 py-2 hover:bg-zinc-50"
                    >
                      Archive
                    </button>
                  </div>
                </form>
              </div>
            <% end %>
          </div>
        <% end %>
      </section>

      <section class="space-y-4">
        <div>
          <h2 class="text-xl font-semibold">Pending proposals</h2>
          <p class="text-sm text-zinc-600">
            Approving a proposal publishes its rankings for that class and activity.
          </p>
        </div>

        <%= if @pending_proposals == [] do %>
          <div class="rounded-lg border p-4 text-sm text-zinc-600">
            No pending proposals.
          </div>
        <% else %>
          <div class="space-y-4">
            <%= for proposal <- @pending_proposals do %>
              <div class="rounded-xl border p-5 shadow-sm">
                <div class="mb-4 space-y-1">
                  <h3 class="text-lg font-semibold">
                    {proposal.class} • {proposal.activity}
                  </h3>
                  <p class="text-sm text-zinc-700">{proposal.summary}</p>
                </div>

                <div class="grid gap-6 md:grid-cols-2">
                  <div>
                    <h4 class="mb-2 font-medium">Ranked weapons</h4>
                    <ol class="list-decimal space-y-1 pl-5 text-sm">
                      <%= for label <- proposal_labels(proposal.weapon_slugs, @item_name_by_slug) do %>
                        <li>{label}</li>
                      <% end %>
                    </ol>
                  </div>

                  <div>
                    <h4 class="mb-2 font-medium">Ranked armors</h4>
                    <ol class="list-decimal space-y-1 pl-5 text-sm">
                      <%= for label <- proposal_labels(proposal.armor_slugs, @item_name_by_slug) do %>
                        <li>{label}</li>
                      <% end %>
                    </ol>
                  </div>
                </div>

                <div class="mt-5 flex flex-wrap gap-3">
                  <button
                    type="button"
                    phx-click="approve_proposal"
                    phx-value-id={proposal.id}
                    class="rounded-md bg-zinc-900 px-4 py-2 text-white hover:bg-zinc-700"
                  >
                    Approve
                  </button>

                  <button
                    type="button"
                    phx-click="reject_proposal"
                    phx-value-id={proposal.id}
                    class="rounded-md border px-4 py-2 hover:bg-zinc-50"
                  >
                    Reject
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </section>
    </div>
    """
  end

  defp load_data(socket) do
    items_needing_review =
      CatalogItem
      |> where([i], i.review_state == "needs_review")
      |> order_by([i], asc: i.inserted_at, asc: i.name)
      |> Repo.all()

    pending_proposals =
      CatalogProposal
      |> where([p], p.status == "pending")
      |> order_by([p], asc: p.inserted_at)
      |> Repo.all()

    item_name_by_slug =
      pending_proposals
      |> Enum.flat_map(fn proposal -> proposal.weapon_slugs ++ proposal.armor_slugs end)
      |> Enum.uniq()
      |> then(fn slugs ->
        if slugs == [] do
          %{}
        else
          CatalogItem
          |> where([i], i.slug in ^slugs)
          |> select([i], {i.slug, i.name})
          |> Repo.all()
          |> Map.new()
        end
      end)

    assign(socket,
      items_needing_review: items_needing_review,
      pending_proposals: pending_proposals,
      item_name_by_slug: item_name_by_slug
    )
  end

  defp update_review_state(socket, id, review_state, success_message) do
    case Repo.get(CatalogItem, parse_int(id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Item not found.")}

      %CatalogItem{} = item ->
        case item
             |> CatalogItem.changeset(%{review_state: review_state})
             |> Repo.update() do
          {:ok, _item} ->
            {:noreply,
             socket
             |> put_flash(:info, success_message)
             |> load_data()}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Could not update item state.")}
        end
    end
  end

  defp approve_proposal(%CatalogProposal{} = proposal) do
    slug_to_item_id =
      CatalogItem
      |> where([i], i.slug in ^(proposal.weapon_slugs ++ proposal.armor_slugs))
      |> select([i], {i.slug, i.id})
      |> Repo.all()
      |> Map.new()

    weapon_rankings =
      build_ranking_attrs(proposal.weapon_slugs, slug_to_item_id, proposal, "weapon")

    armor_rankings =
      build_ranking_attrs(proposal.armor_slugs, slug_to_item_id, proposal, "armor")

    with {:ok, weapon_rankings} <- weapon_rankings,
         {:ok, armor_rankings} <- armor_rankings do
      now = DateTime.utc_now()

      Multi.new()
      |> Multi.delete_all(
        :delete_existing_rankings,
        from(r in CatalogRanking,
          where: r.class == ^proposal.class and r.activity == ^proposal.activity
        )
      )
      |> Multi.insert_all(
        :insert_weapon_rankings,
        CatalogRanking,
        add_timestamps(weapon_rankings, now)
      )
      |> Multi.insert_all(
        :insert_armor_rankings,
        CatalogRanking,
        add_timestamps(armor_rankings, now)
      )
      |> Multi.update(
        :approve_proposal,
        CatalogProposal.changeset(proposal, %{
          status: "approved",
          approved_at: now,
          rejected_at: nil
        })
      )
      |> Repo.transaction()
    end
  end

  defp build_ranking_attrs(slugs, slug_to_item_id, proposal, slot) do
    attrs =
      slugs
      |> Enum.with_index(1)
      |> Enum.map(fn {slug, rank} ->
        case Map.fetch(slug_to_item_id, slug) do
          {:ok, catalog_item_id} ->
            {:ok,
             %{
               class: proposal.class,
               activity: proposal.activity,
               slot: slot,
               rank: rank,
               catalog_item_id: catalog_item_id,
               proposal_id: proposal.id
             }}

          :error ->
            {:error, {:unknown_slug, slug}}
        end
      end)

    case Enum.find(attrs, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.map(attrs, fn {:ok, attr} -> attr end)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp add_timestamps(attrs, now) do
    Enum.map(attrs, &Map.merge(&1, %{inserted_at: now, updated_at: now}))
  end

  defp proposal_labels(slugs, item_name_by_slug) do
    Enum.map(slugs, fn slug -> Map.get(item_name_by_slug, slug, slug) end)
  end

  defp parse_tags(nil), do: []

  defp parse_tags(tags_string) do
    tags_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp parse_int(value) when is_integer(value), do: value
  defp parse_int(value) when is_binary(value), do: String.to_integer(value)
end
