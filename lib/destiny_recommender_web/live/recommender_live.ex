defmodule DestinyRecommenderWeb.RecommenderLive do
  use DestinyRecommenderWeb, :live_view

  alias DestinyRecommender.Recommendations
  alias DestinyRecommender.Recommendations.Catalog

  @impl true
  def mount(_params, _session, socket) do
    defaults = %{"class" => "Warlock", "activity" => "Crucible"}

    {:ok,
     socket
     |> assign(:classes, Catalog.classes())
     |> assign(:activities, Catalog.activities())
     |> assign(:form, to_form(defaults, as: :prefs))
     |> assign(:result, nil)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("recommend", %{"prefs" => prefs}, socket) do
    class = prefs["class"]
    activity = prefs["activity"]

    socket = assign(socket, :form, to_form(prefs, as: :prefs))

    case Recommendations.recommend(class, activity) do
      {:ok, result} ->
        {:noreply, assign(socket, result: result, error: nil)}

      {:error, :missing_openai_api_key} ->
        {:noreply,
         assign(socket,
           result: nil,
           error: "Missing OPENAI_API_KEY. Export it in your shell and restart the server."
         )}

      {:error, other} ->
        {:noreply, assign(socket, result: nil, error: inspect(other))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl p-6">
      <.header>
        Destiny 2 Solo Exotic Recommender
        <:subtitle>Pick your class + activity. Get 1 exotic weapon + 1 exotic armor.</:subtitle>
      </.header>

      <.form for={@form} phx-submit="recommend" class="space-y-4">
        <.input field={@form[:class]} type="select" label="Class" options={@classes} />
        <.input field={@form[:activity]} type="select" label="Activity" options={@activities} />

        <div>
          <.button phx-disable-with="Recommending...">Recommend</.button>
        </div>
      </.form>

      <%= if @error do %>
        <div class="mt-6 rounded border p-4">
          <p class="font-semibold">Error</p>
          <p>{@error}</p>
        </div>
      <% end %>

      <%= if @result do %>
        <div class="mt-8 space-y-4 rounded border p-6">
          <.header>Recommendation</.header>

          <p><span class="font-semibold">Weapon:</span> {@result.weapon.name}</p>
          <p><span class="font-semibold">Armor:</span> {@result.armor.name}</p>

          <p class="mt-4"><span class="font-semibold">Why:</span> {@result.why}</p>

          <div class="mt-4">
            <p class="font-semibold">Tips:</p>
            <ul class="list-disc pl-6">
              <%= for tip <- @result.tips do %>
                <li>{tip}</li>
              <% end %>
            </ul>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
