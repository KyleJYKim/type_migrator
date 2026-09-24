defmodule Mix.Tasks.TranslateDatasetTypes do
  @moduledoc """
  Add a `translated_type` field to a dataset: the types in scope, rewritten
  from TypeSpec syntax into Elixir Types.

      mix translate_dataset_types data/dataset.jsonl [out.jsonl]

  The input is left untouched and a new file is written (defaulting to
  `<input>.with_translated_types.jsonl`), so swapping it in is a deliberate
  step. The original `type` field is preserved alongside the new one: the
  TypeSpec track reads the former, the Descr track the latter.

  See `DatasetTypeTranslator` for what the translation can and cannot resolve.
  Requires the custom Elixir at `elixir/bin`.
  """
  use Mix.Task

  @shortdoc "Translate each entry's types in scope into Elixir Types"

  @usage "usage: mix translate_dataset_types <dataset.jsonl> [out.jsonl]"

  @impl true
  def run([in_path]), do: run_translation(in_path, nil)
  def run([in_path, out_path]), do: run_translation(in_path, out_path)
  def run(_), do: Mix.raise(@usage)

  defp run_translation(in_path, out_path) do
    unless File.exists?(in_path), do: Mix.raise("No such dataset: #{in_path}")
    Logger.configure(level: :info)
    DatasetTypeTranslator.main(in_path, out_path)
  end
end
