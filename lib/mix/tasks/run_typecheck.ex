defmodule Mix.Tasks.RunTypecheck do
  use Mix.Task

  @shortdoc "Run Elixir type check across all mix projects in a directory"

  def run([root_dir]) do
    TypecheckRunner.main(root_dir)
  end

  def run([root_dir, elixir_bin]) do
    TypecheckRunner.main(root_dir, elixir_bin)
  end

  def run(_) do
    Mix.raise("Usage: mix run_typecheck /path/to/repos [/path/to/elixir/bin]")
  end
end
