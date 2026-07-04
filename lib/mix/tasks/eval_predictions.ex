defmodule Mix.Tasks.EvalPredictions do
  @moduledoc """
  Typecheck LLM predictions against the real translated projects.

      mix eval_predictions <predictions.jsonl> [prjs_translation_dir]

  `predictions.jsonl` is the eval output from the trainer (each line a dataset
  entry plus `generated_elixir_type`). Writes `<predictions>.typechecked.jsonl`
  with a `predicted_type_check` field ("pass" | "fail" | "compile_error") per
  entry. Requires the custom Elixir at `elixir/bin`.
  """
  use Mix.Task

  @shortdoc "Typecheck LLM predictions in their real project context"

  @impl true
  def run(args) do
    {eval_type, preds_path, root} =
      case args do
        [t, p] -> {String.to_atom(t), p, "../prjs_translation"}
        [t, p, r | _] -> {String.to_atom(t), p, r}
        _ -> Mix.raise("usage: mix eval_predictions <set-theoretic or by-typecheck> <predictions.jsonl> [prjs_dir]")
      end

    Logger.configure(level: :info)

    case eval_type do
      :"set-theoretic" -> SetTheoreticEvaluator.main(preds_path)
      :"by-typecheck" -> ByTypecheckEvaluator.main(preds_path, root)
    end
  end
end
