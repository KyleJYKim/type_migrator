defmodule Migrator.StdRemoteTypeCollector do
  alias Migrator.TypeTranslator, as: TypeTr

  def build_cache(dir, cache_file) do
    ensure_types_table()

    paths = dir
      |> Path.join("**/*.{ex,exs}")
      |> Path.wildcard()

    {_time, types} = :timer.tc(&TypeTr.process/1, [paths])

    # store in ETS
    Enum.each(types, fn {key, value} -> :ets.insert(:types_table, {key, value}) end)

    # persist to disk
    :ets.tab2file(:types_table, String.to_charlist(cache_file))

    IO.puts("Stdlib cache built and saved")
  end

  defp ensure_types_table() do
    case :ets.whereis(:types_table) do
      :undefined ->
        :ets.new(:types_table, [:set, :named_table, :public])
      _ ->
        :types_table
    end
  end

  def lookup_type(key) do
    case :ets.lookup(:types_table, key) do
      [{^key, value}] -> {:ok, value}
      [] -> :error
    end
  end

  def load_cache(cache_file) do
    case File.exists?(cache_file) do
      true ->
        :ets.file2tab(String.to_charlist(cache_file))
        IO.puts("Loaded module-type cache")

      false ->
        IO.puts("No cache found")
        :error
    end
  end

end
