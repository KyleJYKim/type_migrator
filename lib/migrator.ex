defmodule Migrator do
  @moduledoc """
    1. Take a file with TypesSpec and parse it into AST.
    2. Translate the AST to Elixir Type.
    3. Rewrite the input file and produce a new file with Elixir Type.
  """
  alias Migrator.SpecTranslator, as: Translator
  alias Migrator.ElixirTypeStringifier, as: Stringifier

  def main(args) do
    args
    |> List.first()
    |> convert_typespec()
  end

  def convert_typespec(path) do
    #pid = CDuceRepl.spawn()  # ...what's it for?

    try do
      {time_translation, translated_specs} = :timer.tc(&Translator.process/1, [path])
      {time_stringification, stringified_annotations} = :timer.tc(&Stringifier.process/1, [translated_specs])

      #CDuceRepl.close(pid)

      #handle_output(stringified_annotations, time)
      IO.puts("Translation Time Elapsed: #{time_translation}")
      IO.puts("Stringification Time Elapsed: #{time_stringification}")

      stringified_annotations |> Enum.map(fn {line_nums, name, full_expression} ->
          lines = line_nums |> Enum.reduce("", fn num, acc -> if acc == "", do: num |> Integer.to_string(), else: "#{acc}, #{num |> Integer.to_string()}" end)
          "Line Number: " <> lines |> IO.puts()
          "Function Name: " <> name |> IO.puts()
          full_expression |> IO.puts()
        end)
    catch
      {:CompileError, msg} ->
        #CDuceRepl.close(pid)

        IO.puts("CompileError:\n#{msg}")
    end
  end
end
