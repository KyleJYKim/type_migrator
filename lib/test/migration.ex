defmodule Migration do
  @moduledoc false

  alias Migrator

  def main(args) do
    case args do
      [root_path | []] ->
        paths = "#{root_path}/**/*.ex" |> Path.wildcard()

        for cnt <- 1..length(paths) do
          path = paths |> Enum.at(cnt - 1)
          IO.puts("## Processing File (#{cnt}/#{length(paths)}): #{path}")

          [:descr_assert, path] |> Migrator.main()
        end

      _ ->
        IO.puts("Error: wrong arguments")
    end
  end

  if function_exported?(Migration, :main, 1) do
    Migration.main(System.argv())
  end
end
