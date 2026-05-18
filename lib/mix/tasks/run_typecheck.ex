defmodule Mix.Tasks.RunTypecheck do
  use Mix.Task

  @shortdoc "Run Elixir type check across all mix projects in a directory"

  require Logger

  @log_file ~c"logs/typecheck.log"

  def run([root_dir]) do
    setup_logger()
    TypecheckRunner.main(root_dir)
    Logger.flush()
    :logger_std_h.filesync(:typecheck_log)
  end

  def run([root_dir, elixir_bin]) do
    setup_logger()
    TypecheckRunner.main(root_dir, elixir_bin)
    Logger.flush()
    :logger_std_h.filesync(:typecheck_log)
  end

  def run(_) do
    Mix.raise("Usage: mix run_typecheck /path/to/repos [/path/to/elixir/bin]")
  end

  defp setup_logger do
    File.mkdir_p!("logs")
    :logger.add_handler(:typecheck_log, :logger_std_h, %{
      config: %{type: :file, file: @log_file, modes: [:append]},
      level: :debug,
      formatter: Logger.Formatter.new(format: "$date $time [$level] $message\n", metadata: [:module])
    })
  end
end
