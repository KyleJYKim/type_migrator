defmodule Mix.Tasks.RunTranslation do
  use Mix.Task

  @shortdoc "Run TypeSpec translation across all .ex files in a directory"

  require Logger

  @log_file ~c"logs/translation.log"

  def run([root_dir]) do
    File.mkdir_p!("logs")
    :logger.add_handler(:file_log, :logger_std_h, %{
      config: %{type: :file, file: @log_file, modes: [:append]},
      level: :debug,
      formatter: Logger.Formatter.new(format: "$date $time [$level] $message\n", metadata: [:module])
    })
    TranslationRunner.main([root_dir])
    Logger.flush()
    :logger_std_h.filesync(:file_log)
  end

  def run(_) do
    Mix.raise("Usage: mix run_translation /path/to/repos")
  end
end
