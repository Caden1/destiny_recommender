# Main seed entrypoint.
#
# `mix setup` runs this file automatically. The catalog seed is always safe to run
# locally because it uses the built-in fallback item list. Build note seeding is
# optional because it requires OpenAI embeddings.

Code.require_file("seeds_catalog_items.exs", __DIR__)

if System.get_env("OPENAI_API_KEY") do
  Code.require_file("seeds_build_notes.exs", __DIR__)
else
  IO.puts("Skipping build note seeding because OPENAI_API_KEY is not set.")
end
