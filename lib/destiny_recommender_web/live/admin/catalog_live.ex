defmodule DestinyRecommenderWeb.Admin.CatalogLive do
  use DestinyRecommenderWeb, :live_view

  import Ecto.Query

  alias Ecto.Multi

  alias DestinyRecommender.Recommendations.{
    Catalog,
    CatalogItem,
    CatalogProposal,
    CatalogRanking,
    Curation
  }

  alias DestinyRecommender.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Catalog Admin")
     |> assign(:activity_options, Catalog.activities())
     |> load_data()}
  end

  @impl true
  def handle_event("generate_proposals", _params, socket) do
    case Curation.enqueue_curator_proposals() do
      {:ok, %{count: count, manifest_version: manifest_version}} ->
        manifest_label = manifest_version || "local seed/manual catalog"

        {:noreply,
         socket
         |> put_flash(:info, "Enqueued #{count} curator job(s) using #{manifest_label}.")
         |> load_data()}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Could not enqueue curator jobs: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("save_item", params, socket) do
    with {:ok, id} <- parse_int(params["id"] || params["_id"]),
         %CatalogItem{} = item <- Repo.get(CatalogItem, id),
         tags <- parse_tags(params["tags"]),
         recommended_activities <- parse_activities(params["recommended_activities"]),
         meta_notes <- String.trim(params["meta_notes"] || ""),
         {:ok, _item} <-
           item
           |> CatalogItem.changeset(%{
             tags: tags,
             recommended_activities: recommended_activities,
             meta_notes: meta_notes
           })
           |> Repo.update() do
      {:noreply,
       socket
       |> put_flash(:info, "Item updated.")
       |> load_data()}
    else
      :error ->
        {:noreply, put_flash(socket, :error, "Invalid item id.")}

      nil ->
        {:noreply, put_flash(socket, :error, "Item not found.")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save item: #{inspect(changeset.errors)}")}
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
    with {:ok, proposal_id} <- parse_int(id),
         %CatalogProposal{} = proposal <- Repo.get(CatalogProposal, proposal_id) do
      case approve_proposal(proposal) do
        {:ok, _result} ->
          {:noreply,
           socket
           |> put_flash(:info, "Proposal approved and rankings published.")
           |> load_data()}

        {:error, _step, _reason, _changes} ->
          {:noreply, put_flash(socket, :error, "Could not approve proposal.")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Could not approve proposal: #{inspect(reason)}")}
      end
    else
      :error ->
        {:noreply, put_flash(socket, :error, "Invalid proposal id.")}

      nil ->
        {:noreply, put_flash(socket, :error, "Proposal not found.")}
    end
  end

  @impl true
  def handle_event("reject_proposal", %{"id" => id}, socket) do
    with {:ok, proposal_id} <- parse_int(id),
         %CatalogProposal{} = proposal <- Repo.get(CatalogProposal, proposal_id) do
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
    else
      :error ->
        {:noreply, put_flash(socket, :error, "Invalid proposal id.")}

      nil ->
        {:noreply, put_flash(socket, :error, "Proposal not found.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-7xl space-y-10">
        <.header>
          Catalog Admin
          <:subtitle>
            Review manifest items, label activity suitability, and approve curator-generated ranking proposals.
          </:subtitle>
        </.header>

        <section class="rounded-xl border p-5 shadow-sm space-y-3">
          <h2 class="text-xl font-semibold">Offline curation</h2>
          <p class="text-sm text-zinc-700">
            Latest synced manifest version:
            <span class="font-mono">{@current_manifest_version || "none yet"}</span>
          </p>
          <p class="text-sm text-zinc-600">
            Proposal generation is manual on purpose. Review items first, then enqueue curator jobs.
          </p>
          <div>
            <button
              type="button"
              phx-click="generate_proposals"
              class="rounded-md bg-zinc-900 px-4 py-2 text-white hover:bg-zinc-700"
            >
              Generate proposals from reviewed catalog
            </button>
          </div>
        </section>

        <section class="space-y-4">
          <div>
            <h2 class="text-xl font-semibold">Items needing review</h2>
            <p class="text-sm text-zinc-600">
              Add tags, write short meta notes, set the activity suitability, then mark the item ready.
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
                    <div class="text-sm text-zinc-600 flex flex-wrap gap-2">
                      <span><strong>Slot:</strong> {item.slot}</span>
                      <span>•</span>
                      <span><strong>Class:</strong> {item.class}</span>
                      <span>•</span>
                      <span><strong>Source:</strong> {item.source}</span>
                      <span>•</span>
                      <span><strong>Manifest:</strong> {item.manifest_version || "—"}</span>
                    </div>
                  </div>

                  <form
                    id={"catalog-item-form-#{item.id}"}
                    phx-submit="save_item"
                    class="space-y-4"
                  >
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
                      <label class="mb-1 block text-sm font-medium">Recommended activities</label>
                      <input
                        type="text"
                        name="recommended_activities"
                        value={Enum.join(item.recommended_activities || [], ", ")}
                        class="w-full rounded-md border px-3 py-2"
                      />
                      <p class="mt-1 text-xs text-zinc-500">
                        Comma-separated values from: {Enum.join(@activity_options, ", ")}
                      </p>
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
    </Layouts.app>
    """
  end

  defp load_data(socket) do
    items_needing_review =
      CatalogItem
      |> where([item], item.review_state == "needs_review")
      |> order_by([item], asc: item.inserted_at, asc: item.name)
      |> Repo.all()

    pending_proposals =
      CatalogProposal
      |> where([proposal], proposal.status == "pending")
      |> order_by([proposal], asc: proposal.inserted_at)
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
          |> where([item], item.slug in ^slugs)
          |> select([item], {item.slug, item.name})
          |> Repo.all()
          |> Map.new()
        end
      end)

    assign(socket,
      items_needing_review: items_needing_review,
      pending_proposals: pending_proposals,
      item_name_by_slug: item_name_by_slug,
      current_manifest_version: Curation.latest_synced_manifest_version()
    )
  end

  defp update_review_state(socket, id, review_state, success_message) do
    with {:ok, item_id} <- parse_int(id),
         %CatalogItem{} = item <- Repo.get(CatalogItem, item_id),
         {:ok, _item} <-
           item |> CatalogItem.changeset(%{review_state: review_state}) |> Repo.update() do
      {:noreply,
       socket
       |> put_flash(:info, success_message)
       |> load_data()}
    else
      :error ->
        {:noreply, put_flash(socket, :error, "Invalid item id.")}

      nil ->
        {:noreply, put_flash(socket, :error, "Item not found.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update item state.")}
    end
  end

  defp approve_proposal(%CatalogProposal{} = proposal) do
    slug_to_item_id =
      CatalogItem
      |> where([item], item.slug in ^(proposal.weapon_slugs ++ proposal.armor_slugs))
      |> select([item], {item.slug, item.id})
      |> Repo.all()
      |> Map.new()

    weapon_rankings =
      build_ranking_attrs(proposal.weapon_slugs, slug_to_item_id, proposal, "weapon")

    armor_rankings = build_ranking_attrs(proposal.armor_slugs, slug_to_item_id, proposal, "armor")

    with {:ok, weapon_rankings} <- weapon_rankings,
         {:ok, armor_rankings} <- armor_rankings do
      now = DateTime.utc_now()

      Multi.new()
      |> Multi.delete_all(
        :delete_existing_rankings,
        from(ranking in CatalogRanking,
          where: ranking.class == ^proposal.class and ranking.activity == ^proposal.activity
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

  defp parse_activities(nil), do: []

  defp parse_activities(activities_string) do
    allowed_activities = MapSet.new(Catalog.activities())

    activities_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.filter(&MapSet.member?(allowed_activities, &1))
    |> Enum.uniq()
  end

  defp parse_int(value) when is_integer(value), do: {:ok, value}

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> {:ok, integer}
      _ -> :error
    end
  end

  defp parse_int(_value), do: :error
end
