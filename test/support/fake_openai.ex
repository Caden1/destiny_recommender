defmodule DestinyRecommender.TestSupport.FakeOpenAI do
  @moduledoc false

  def model, do: "fake-openai-model"
  def embedding_model, do: "fake-embedding-model"

  def create_response(_payload) do
    response =
      Application.get_env(
        :destiny_recommender,
        :fake_openai_response,
        %{
          "weapon_id" => "ace_of_spades",
          "armor_id" => "ophidian_aspect",
          "why" => "Reliable neutral game for solo Crucible.",
          "playstyle_tips" => ["Take favorable duels.", "Reposition after each fight."]
        }
      )

    encoded = if is_binary(response), do: response, else: Jason.encode!(response)
    {:ok, %{"output_text" => encoded}}
  end

  def create_embedding(_text) do
    {:ok, List.duplicate(0.0, 1536)}
  end

  def create_embeddings(texts) when is_list(texts) do
    {:ok, Enum.map(texts, fn _ -> List.duplicate(0.0, 1536) end)}
  end
end
