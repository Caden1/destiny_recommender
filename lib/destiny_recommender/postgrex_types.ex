Postgrex.Types.define(
  DestinyRecommender.PostgrexTypes,
  Pgvector.extensions() ++ Ecto.Adapters.Postgres.extensions(),
  []
)
