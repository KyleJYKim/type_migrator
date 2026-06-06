defmodule Migrator.TypeTableHandler do
  alias Migrator.TypeTranslator, as: TypeTr

  @spec build_cache(binary(), binary(), atom()) :: :ok
  def build_cache(path, cache_file, table_name)
      when is_binary(path) and is_binary(cache_file) and is_atom(table_name) do
    ensure_types_table(table_name)

    paths =
      cond do
        File.regular?(path) ->
          [path]

        File.dir?(path) ->
          path
          |> Path.join("**/*.{ex,exs}")
          |> Path.wildcard()

        true ->
          []
      end

    paths
    |> TypeTr.process()
    |> Enum.each(fn {key, value} ->
      :ets.insert(table_name, {key, value})
    end)

    :ets.tab2file(table_name, String.to_charlist(cache_file))

    IO.puts("Cache built and saved at #{cache_file}")
  end

  defp ensure_types_table(table_name) when is_atom(table_name) do
    case :ets.whereis(table_name) do
      :undefined ->
        :ets.new(table_name, [:set, :named_table, :protected])

      _ ->
        table_name
    end
  end

  @spec lookup_type(atom(), binary()) :: {:ok, value} | :error when value: atom() | tuple()
  def lookup_type(table_name, key) when is_atom(table_name) and is_binary(key) do
    # The table may not exist (e.g. a standalone `mix run lib/migrator.ex` that
    # never loaded the std/remote-type cache, or a concurrent task that deleted
    # it). Treat a missing table as "not found" rather than raising.
    case :ets.whereis(table_name) do
      :undefined ->
        :error

      _ ->
        case :ets.lookup(table_name, key) do
          [{^key, value}] -> {:ok, value}
          [] -> :error
        end
    end
  end

  @spec load_cache(binary()) :: :ok | :error
  def load_cache(cache_file) when is_binary(cache_file) do
    case File.exists?(cache_file) do
      true ->
        :ets.file2tab(String.to_charlist(cache_file))

      # IO.puts("Loaded cache at #{cache_file}")

      false ->
        IO.puts("No cache found")
        :error
    end
  end
end
