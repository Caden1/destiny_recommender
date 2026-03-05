defmodule DestinyRecommender.Repo do
  use Ecto.Repo,
    otp_app: :destiny_recommender,
    adapter: Ecto.Adapters.Postgres
end
