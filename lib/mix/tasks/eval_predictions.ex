defmodule Mix.Tasks.EvalPredictions do
  @moduledoc """
  Typecheck LLM predictions against the real translated projects.

      mix eval_predictions <predictions.jsonl> [prjs_translation_dir]
      mix eval_predictions cascade <expanded.jsonl> <compact.jsonl>

  `predictions.jsonl` is the eval output from the trainer (each line a dataset
  entry plus `generated_elixir_type`). Writes `<predictions>.typechecked.jsonl`
  with a `predicted_type_check` field ("pass" | "fail" | "compile_error") per
  entry. Requires the custom Elixir at `elixir/bin`.

  `cascade` combines two ALREADY-GENERATED predictions files (from the
  EXPANDED and COMPACT adapters, run independently over the same test set,
  e.g. on the cluster) into one cascaded result: keep the expanded
  prediction where compatible, else the compact prediction, else fall back
  to dynamic(). Runs entirely locally -- no model calls. See
  CascadeEvaluator for the tier logic.
  """
  use Mix.Task

  @shortdoc "Typecheck LLM predictions in their real project context"

  @usage "usage: mix eval_predictions <set-theoretic|by-typecheck> <predictions.jsonl> [prjs_dir]" <>
           "\n    or mix eval_predictions cascade <expanded.jsonl> <compact.jsonl>"

  @error_log "logs/eval_predictions_errors.log"

  @impl true
  def run([type | rest]) do
    Logger.configure(level: :info)
    setup_error_log()

    case String.to_atom(type) do
      :"set-theoretic" ->
        case rest do
          [preds_path | _] -> SetTheoreticEvaluator.main(preds_path)
          _ -> Mix.raise(@usage)
        end

      :cascade ->
        case rest do
          [expanded_path, compact_path] -> CascadeEvaluator.main(expanded_path, compact_path)
          _ -> Mix.raise(@usage)
        end

      :"by-typecheck" ->
        case rest do
          [preds_path] -> ByTypecheckEvaluator.main(preds_path, "../prjs_translation")
          [preds_path, root | _] -> ByTypecheckEvaluator.main(preds_path, root)
          _ -> Mix.raise(@usage)
        end

      _ ->
        Mix.raise(@usage)
    end
  end

  def run(_), do: Mix.raise(@usage)

  # Per-entry eval failures (e.g. an unparseable generated type) are logged
  # at :error via Logger.error in SetTheoreticEvaluator.eval_annotation/1,
  # which every eval_type here goes through (cascade included, since it
  # calls eval_annotation/1 directly). On a large run that can be hundreds
  # of lines of noise, drowning out the tier/summary info that matters --
  # so :error is routed to a file instead of the console; :info/:warning
  # (summaries, tier breakdowns, missing-row notices) still print normally.
  defp setup_error_log do
    File.mkdir_p!(Path.dirname(@error_log))

    :logger.add_handler(:eval_error_log, :logger_std_h, %{
      config: %{type: :file, file: String.to_charlist(@error_log), modes: [:append]},
      level: :error,
      formatter: Logger.Formatter.new(format: "$date $time [$level] $message\n", metadata: [:module])
    })

    :logger.add_handler_filter(:default, :drop_eval_errors, {&drop_error/2, :ok})
  end

  defp drop_error(%{level: :error} = _event, _), do: :stop
  defp drop_error(event, _), do: event
end
