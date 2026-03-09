defmodule DestinyRecommenderWeb.RecommenderLiveTest do
  use DestinyRecommenderWeb.ConnCase

  import Phoenix.LiveViewTest

  setup do
    Application.put_env(:destiny_recommender, :openai_client, DestinyRecommender.TestSupport.FakeOpenAI)

    Application.put_env(:destiny_recommender, :fake_openai_response, %{
      "weapon_id" => "ace_of_spades",
      "armor_id" => "ophidian_aspect",
      "why" => "Reliable neutral game for solo Crucible.",
      "playstyle_tips" => ["Take favorable duels.", "Reposition after each fight."]
    })

    on_exit(fn ->
      Application.delete_env(:destiny_recommender, :openai_client)
      Application.delete_env(:destiny_recommender, :fake_openai_response)
    end)

    :ok
  end

  test "submits the form and renders a recommendation", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    view
    |> form("form", prefs: %{class: "Warlock", activity: "Crucible"})
    |> render_submit()

    html = render_async(view)

    assert html =~ "Ace of Spades"
    assert html =~ "Ophidian Aspect"
    assert html =~ "Reliable neutral game for solo Crucible."
  end
end
