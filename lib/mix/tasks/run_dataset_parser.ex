defmodule Mix.Tasks.RunDatasetParser do
  use Mix.Task
  @shortdoc "Parse dataset.jsonl and print warning statistics"

  def run([]) do
    DatasetParser.main()
  end

  def run([dataset_path]) do
    DatasetParser.main(dataset_path)
  end

  def run(_) do
    Mix.raise("Usage: mix run_dataset_parser [/path/to/dataset.jsonl]")
  end
end
