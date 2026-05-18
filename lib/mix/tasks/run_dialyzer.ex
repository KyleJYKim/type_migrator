defmodule Mix.Tasks.RunDialyzer do
  use Mix.Task

  @shortdoc "Run Dialyzer across all mix projects in a directory"

  require Logger

  @log_file ~c"logs/dialyzer.log"

  def run([root_dir]) do
    File.mkdir_p!("logs")
    :logger.add_handler(:dialyzer_log, :logger_std_h, %{
      config: %{type: :file, file: @log_file, modes: [:append]},
      level: :debug,
      formatter: Logger.Formatter.new(format: "$date $time [$level] $message\n", metadata: [:module])
    })
    DialyzerRunner.main(root_dir)
    Logger.flush()
    :logger_std_h.filesync(:dialyzer_log)
  end

  def run(_) do
    Mix.raise("Usage: mix run_dialyzer /path/to/repos")
  end
end
