defmodule Mix.Tasks.RunTranslation do
  use Mix.Task

  @shortdoc "Run TypeSpec translation across all .ex files in a directory"

  def run([root_dir]) do
    TranslationRunner.main([root_dir])
  end

  def run(_) do
    Mix.raise("Usage: mix run_translation /path/to/repos")
  end
end
