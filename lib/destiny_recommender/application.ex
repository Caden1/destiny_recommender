defmodule DestinyRecommender.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DestinyRecommenderWeb.Telemetry,
      DestinyRecommender.Repo,
      {Oban, Application.fetch_env!(:destiny_recommender, Oban)},
      {DNSCluster,
       query: Application.get_env(:destiny_recommender, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DestinyRecommender.PubSub},
      # We keep a small in-memory cache because the online recommendation space
      # is tiny (3 classes x 2 activities) and repeated clicks are common.
      DestinyRecommender.Recommendations.RecommendationCache,
      # LiveView async tasks can optionally run under a dedicated supervisor.
      {Task.Supervisor, name: DestinyRecommender.TaskSupervisor},
      DestinyRecommenderWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: DestinyRecommender.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    DestinyRecommenderWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
