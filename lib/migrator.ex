defmodule Migrator do
  @moduledoc """
    1. Take a file with TypesSpec and parse it into AST.
    2. Translate the AST to Elixir Type.
    3. Rewrite the input file and produce a new file with Elixir Type.
  """
  alias Migrator.SpecTranslator, as: SpecTr
  alias Migrator.TypeTranslator, as: TypeTr
  alias Migrator.ElixirTypeStringifier, as: ElixirTypeStr

  def main(args) do
    args
    |> List.first()
    |> convert_typespecs()
  end

  def convert_typespecs(paths) when is_list(paths) do

    try do

      {time_type_translation, translated_types} = :timer.tc(&TypeTr.process/1, [paths])

      {time_spec_translations, translated_specs} = paths
        |> Enum.map(fn path -> :timer.tc(&SpecTr.process/1, [path]) end)
        |> Enum.unzip()

      {time_stringification, stringified_elixir_types} = translated_specs
        |> Enum.map(fn translated_spec -> :timer.tc(&ElixirTypeStr.process/1, [translated_spec]) end)
        |> Enum.unzip()

      {time_stringification_type_replacing, stringified_elixir_types_type_replacing} = translated_specs
        |> Enum.map(fn translated_spec -> :timer.tc(&ElixirTypeStr.process/2, [translated_spec, translated_types]) end)
        |> Enum.unzip()

      #handle_output(stringified_annotations, time)
      # IO.puts("Translation Time Elapsed: #{time_translation}")
      # IO.puts("Stringification Time Elapsed: #{time_stringification}")

      IO.puts("Translation without User-defined Type Replacement")
      stringified_elixir_types |> Enum.map(fn specs -> specs |>
        Enum.map(fn {line_nums, {module_name, fun_name}, full_expression} ->
          lines = line_nums |> Enum.reduce("", fn num, acc -> if acc == "", do: num |> Integer.to_string(), else: "#{acc}, #{num |> Integer.to_string()}" end)
          name = "#{module_name}.#{fun_name}"
          "Line Number: " <> lines |> IO.puts()
          "Function Name: " <> name |> IO.puts()
          full_expression |> IO.puts()
        end)
      end)

      IO.puts("Translation with User-defined Type Replacement")
      stringified_elixir_types_type_replacing |> Enum.map(fn specs -> specs |>
        Enum.map(fn {line_nums, {module_name, fun_name}, full_expression} ->
          lines = line_nums |> Enum.reduce("", fn num, acc -> if acc == "", do: num |> Integer.to_string(), else: "#{acc}, #{num |> Integer.to_string()}" end)
          name = "#{module_name}.#{fun_name}"
          "Line Number: " <> lines |> IO.puts()
          "Function Name: " <> name |> IO.puts()
          full_expression |> IO.puts()
        end)
      end)

    catch
      {:CompileError, msg} ->
        #CDuceRepl.close(pid)

        IO.puts("CompileError:\n#{msg}")
    end
  end
end
