defmodule DestinyRecommenderWeb.RecommenderLive do
  use DestinyRecommenderWeb, :live_view

  alias DestinyRecommender.Recommendations
  alias DestinyRecommender.Recommendations.Catalog

  @impl true
  def mount(_params, _session, socket) do
    defaults = %{"class" => "Warlock", "activity" => "Crucible"}

    {:ok,
     socket
     |> assign(:page_title, "Destiny 2 Solo Exotic Recommender")
     |> assign(:classes, Catalog.classes())
     |> assign(:activities, Catalog.activities())
     |> assign(:form, to_form(defaults, as: :prefs))
     |> assign(:result, nil)
     |> assign(:error, nil)
     |> assign(:loading, false)}
  end

  @impl true
  def handle_event("recommend", %{"prefs" => prefs}, socket) do
    class = prefs["class"]
    activity = prefs["activity"]

    {:noreply,
     socket
     |> assign(:form, to_form(prefs, as: :prefs))
     |> assign(:result, nil)
     |> assign(:error, nil)
     |> assign(:loading, true)
     |> start_async(
       :recommendation,
       fn -> Recommendations.recommend(class, activity) end,
       supervisor: DestinyRecommender.TaskSupervisor
     )}
  end

  @impl true
  def handle_async(:recommendation, {:ok, {:ok, result}}, socket) do
    {:noreply, assign(socket, result: result, error: nil, loading: false)}
  end

  def handle_async(:recommendation, {:ok, {:error, :missing_openai_api_key}}, socket) do
    {:noreply,
     assign(socket,
       result: nil,
       loading: false,
       error: "Missing OPENAI_API_KEY. Export it in your shell and restart the server."
     )}
  end

  def handle_async(:recommendation, {:ok, {:error, other}}, socket) do
    {:noreply, assign(socket, result: nil, loading: false, error: inspect(other))}
  end

  def handle_async(:recommendation, {:exit, reason}, socket) do
    {:noreply,
     assign(socket,
       result: nil,
       loading: false,
       error: "The recommendation task crashed: #{inspect(reason)}"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-2xl space-y-8">
        <.header>
          Destiny 2 Solo Exotic Recommender
          <:subtitle>
            Pick your class and activity. The app recommends exactly one exotic weapon and one exotic armor for solo play.
          </:subtitle>
        </.header>

        <div class="rounded-xl border p-5 shadow-sm space-y-3">
          <p class="text-sm text-zinc-700">
            This UI is intentionally narrow in scope: it does not ask the model to remember all of Destiny 2. Instead,
            the server assembles a small candidate set and the model chooses from that list.
          </p>

          <.form for={@form} phx-submit="recommend" class="space-y-4">
            <.input field={@form[:class]} type="select" label="Class" options={@classes} />
            <.input field={@form[:activity]} type="select" label="Activity" options={@activities} />

            <div>
              <.button phx-disable-with="Recommending..." disabled={@loading}>
                Recommend
              </.button>
            </div>
          </.form>
        </div>

        <%= if @loading do %>
          <div class="rounded-xl border p-5 shadow-sm">
            <p class="font-semibold">Thinking...</p>
            <p class="text-sm text-zinc-600">
              Building a candidate-first context pack and asking the model to choose from it.
            </p>
          </div>
        <% end %>

        <%= if @error do %>
          <div class="rounded-xl border p-5 shadow-sm">
            <p class="font-semibold">Error</p>
            <p>{@error}</p>
          </div>
        <% end %>

        <%= if @result do %>
          <div class="rounded-xl border p-6 shadow-sm space-y-4">
            <.header>Recommendation</.header>

            <p><span class="font-semibold">Weapon:</span> {@result.weapon.name}</p>
            <p><span class="font-semibold">Armor:</span> {@result.armor.name}</p>
            <p><span class="font-semibold">Why:</span> {@result.why}</p>

            <div>
              <p class="font-semibold">Tips</p>
              <ul class="list-disc pl-6">
                <%= for tip <- @result.tips do %>
                  <li>{tip}</li>
                <% end %>
              </ul>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
