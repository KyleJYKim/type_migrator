defmodule TypeMigrator do
  @moduledoc """
    1. Take a file with TypesSpec and parse it into AST.
    2. Translate the AST to Elixir Type.
    3. Rewrite the input file and produce a new file with Elixir Type.
  """
  alias Parser.TypespecParser, as: Parser

  def main(args) do
    args
    |> List.first()
    |> convert_typespec()
  end

  def convert_typespec(path) do
    #pid = CDuceRepl.spawn()  # ...what's it for?

    try do
      {time, result} = :timer.tc(&Parser.process/1, [path])

      #CDuceRepl.close(pid)

      #handle_output(result, time)
      IO.puts(time)
      IO.puts(result)
    catch
      {:CompileError, msg} ->
        #CDuceRepl.close(pid)

        IO.puts("CompileError:\n#{msg}")
    end
  end
end
