defmodule Mix.Tasks.RunDialyzer do
  use Mix.Task

  @shortdoc "Run Dialyzer across all mix projects in a directory"

  def run([root_dir]) do
    DialyzerRunner.main(root_dir)
  end

  def run(_) do
    Mix.raise("Usage: mix run_dialyzer /path/to/repos")
  end
end
