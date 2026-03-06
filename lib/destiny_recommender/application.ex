defmodule DestinyRecommender.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
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
      # Start a worker by calling: DestinyRecommender.Worker.start_link(arg)
      # {DestinyRecommender.Worker, arg},
      # Start to serve requests, typically the last entry
      DestinyRecommenderWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DestinyRecommender.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DestinyRecommenderWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
