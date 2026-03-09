defmodule DestinyRecommender.Recommendations.RecommendationCache do
  @moduledoc """
  Tiny ETS-backed cache for recommendation results.

  The app only has six high-level input combinations, so even a small cache helps
  avoid repeated model calls during local development and manual QA.
  """

  use GenServer

  @table :destiny_recommender_recommendation_cache
  @default_ttl_ms :timer.minutes(10)
  @cleanup_interval_ms :timer.minutes(1)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Returns a cached value when it is still fresh, otherwise computes and stores it.

  Only successful recommendation results are cached. Errors are returned directly
  so operational issues still surface immediately.
  """
  def get_or_store(key, fun, ttl_ms \\ @default_ttl_ms)
      when is_binary(key) and is_function(fun, 0) do
    case get(key) do
      {:ok, value} ->
        :telemetry.execute(
          [:destiny_recommender, :recommendation, :cache],
          %{count: 1},
          %{hit: true, key: key}
        )

        {:ok, value}

      :miss ->
        :telemetry.execute(
          [:destiny_recommender, :recommendation, :cache],
          %{count: 1},
          %{hit: false, key: key}
        )

        case fun.() do
          {:ok, value} = result ->
            put(key, value, ttl_ms)
            result

          other ->
            other
        end
    end
  end

  def get(key) when is_binary(key) do
    now = System.system_time(:millisecond)

    case :ets.lookup(@table, key) do
      [{^key, value, expires_at}] when expires_at > now ->
        {:ok, value}

      [{^key, _value, _expires_at}] ->
        :ets.delete(@table, key)
        :miss

      [] ->
        :miss
    end
  end

  def put(key, value, ttl_ms \\ @default_ttl_ms) when is_binary(key) do
    expires_at = System.system_time(:millisecond) + ttl_ms
    true = :ets.insert(@table, {key, value, expires_at})
    :ok
  end

  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end

  @impl true
  def init(state) do
    ensure_table!()
    schedule_cleanup()
    {:ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.system_time(:millisecond)

    # The table is intentionally tiny, so a simple scan keeps the code easy to understand.
    for {key, _value, expires_at} <- :ets.tab2list(@table), expires_at <= now do
      :ets.delete(@table, key)
    end

    schedule_cleanup()
    {:noreply, state}
  end

  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

      _table ->
        :ok
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end
end
