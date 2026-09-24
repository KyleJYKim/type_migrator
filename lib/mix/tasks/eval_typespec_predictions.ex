defmodule Mix.Tasks.EvalTypespecPredictions do
  @moduledoc """
  Score TypeSpec predictions by translating them into Elixir Types first.

      mix eval_typespec_predictions <predictions.jsonl> [out.jsonl]

  `predictions.jsonl` is the output of `scripts/generate_typespec.py` (or its
  seq2seq counterpart): each line a dataset entry plus `generated_spec`. Writes
  `<predictions>.typespec_evaluated.jsonl` unless an output path is given, and
  prints the compatibility/exact rates alongside the ceiling obtained by pushing
  the reference spec through the identical route (see
  `TypespecPredictionEvaluator`).

  Requires the custom Elixir at `elixir/bin`, since scoring calls into the
  compiler's `Module.Types.Descr`.
  """
  use Mix.Task

  @shortdoc "Translate TypeSpec predictions and score them set-theoretically"

  @usage "usage: mix eval_typespec_predictions <predictions.jsonl> [out.jsonl]"

  @impl true
  def run([preds_path]), do: run_eval(preds_path, nil)
  def run([preds_path, out_path]), do: run_eval(preds_path, out_path)
  def run(_), do: Mix.raise(@usage)

  defp run_eval(preds_path, out_path) do
    unless File.exists?(preds_path), do: Mix.raise("No such predictions file: #{preds_path}")
    Logger.configure(level: :info)
    TypespecPredictionEvaluator.main(preds_path, out_path)
  end
end
