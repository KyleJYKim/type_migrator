defmodule Mix.Tasks.RunDatasetParser do
  use Mix.Task
  @shortdoc "Parse dataset.jsonl and write analysis to a file"

  def run([]), do: DatasetParser.main()
  def run([dataset_path]), do: DatasetParser.main(dataset_path)
  def run([dataset_path, output_path]), do: DatasetParser.main(dataset_path, output_path)

  def run(_) do
    Mix.raise("Usage: mix run_dataset_parser [dataset.jsonl [output.tex]]")
  end
end
