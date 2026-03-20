defmodule Migrator do
  @moduledoc """
    Translate TypeSpecs to Elixir Types and produce it in either string form or Descr.

    Usage:
      mix run lib/migrator.ex <mode> <spec_path> [type_paths...]

    Modes:
      direct
      direct_replacement
      descr
      descr_assert

    Example:
                              <mode>              <spec_path>     [type_paths]
      mix run lib/migrator.ex direct              spec_file_path
      mix run lib/migrator.ex direct_replacement  spec_file_path  type_file_path1 type_file_path2 ...
      mix run lib/migrator.ex descr               spec_file_path  type_file_path1 type_file_path2 ...
      mix run lib/migrator.ex descr_assert        spec_file_path  type_file_path1 type_file_path2 ...

    <mode> decides essentially decides how far translation goes.
    All Translation first perform direct parsing and translation on the obtained Abstract Syntax Tree (AST) from <spec_path>.
    On the one hand, `direct` option produces this translation in the form of the Elixir Types annotation.
    On the other hand, `direct_replacement`, `descr`, and `descr_assert` options take another list of paths, i.e., [type_paths...], that contains information of user-defined types (module types),
    so that the user-defined types in spec annotations can be replaced with their definitions.
    While `direct_replacement` returns this in Elixir Types annotation, rest of them are expressed in Descr (representation of Elixir Types).
    After receiving product of Descr expressions `descr` produces it in Elixir Types annotation using `Descr.to_quoted_string/1`.
    Unlike other options, `descr_assert` creates a file named `<spec_file_path>.assert.exs` which contains `@assert_type` annotation followed by Descr functions which is the translation of the given spec annotation.
    This allows us to type-check at the compiler level.

  """
  alias Module.Types.Descr
  alias Migrator.SpecTranslator, as: SpecTr
  alias Migrator.TypeTranslator, as: TypeTr
  alias Migrator.ElixirTypeConstructor, as: TypeConstr

  @doc """
    Example:
      Migrator.main([:descr_assert, "test/descr_test.exs", "../elixir/lib/elixir/lib"])
  """
  def main(args) do
    case args do
      [mode, spec_path] ->
        run(mode, spec_path)

      [mode, spec_path | type_paths] ->
        run(mode, spec_path, type_paths)

      _ ->
        IO.puts("Error: wrong arguments")
    end
  end

  defp run(mode, spec_path, type_paths \\ []) do
    mode_atom =
      case mode do
        m when is_atom(m) -> m
        m when is_binary(m) -> String.to_atom(m)
      end

    # Expand directories in type_paths to file paths before proceeding
    type_paths = type_paths |> Enum.flat_map(&expand_path/1)

    case mode_atom do
      :direct ->
        convert_with_direct_translation(spec_path)

      :direct_replacement ->
        convert_with_direct_translation(spec_path, type_paths)

      :descr ->
        convert_in_descr(:annotation_form, spec_path, type_paths)

      :descr_assert ->
        # ../elixir/lib/elixir/lib/string.ex
        elixir_types = convert_in_descr(:function_form, spec_path, type_paths)

        spec_path_list = spec_path
          |> String.split(".")
          |> Enum.reverse()
          |> tl()
        output_path = spec_path_list
          |> List.replace_at(0, hd(spec_path_list) <> "_test.exs")
          |> Enum.reverse()
          |> Enum.reduce("", fn chunk, acc -> if acc == "", do: chunk, else: acc <> "." <> chunk end)
        output_path_in_test = "test/type_assert/" <> (output_path |> String.split("/") |> List.last())

        insert_expression(spec_path, output_path_in_test, elixir_types, "@assert_type")

      _ ->
        IO.puts("Unknown mode: #{mode}")
    end
  end

  defp expand_path(path) do
    cond do
      File.regular?(path) ->
        [path]

      File.dir?(path) ->
        path
        |> Path.join("**/*.{ex,exs}")
        |> Path.wildcard()

      true ->
        []
    end
  end

  def convert_with_direct_translation(spec_path) when is_binary(spec_path) do
    try do

      {_time_spec_translations, translated_spec} = :timer.tc(&SpecTr.process/1, [spec_path])

      {_time_stringification, stringified_elixir_types} = :timer.tc(&TypeConstr.stringify/1, [translated_spec])

      #handle_output(stringified_annotations, time)
      # IO.puts("Translation Time Elapsed: #{time_translation}")
      # IO.puts("Stringification Time Elapsed: #{time_stringification}")

      IO.puts("Translation without User-defined Type Replacement")
      stringified_elixir_types |> Enum.map(fn {line_nums, {module_name, fun_name}, full_expression} ->
        lines = line_nums |> Enum.reduce("", fn num, acc -> if acc == "", do: num |> Integer.to_string(), else: "#{acc}, #{num |> Integer.to_string()}" end)
        name = "#{module_name}.#{fun_name}"
        "Line Number: " <> lines |> IO.puts()
        "Function Name: " <> name |> IO.puts()
        full_expression |> IO.puts()
      end)

      stringified_elixir_types

    catch
      {:CompileError, msg} ->
        #CDuceRepl.close(pid)

        IO.puts("CompileError:\n#{msg}")
    end
  end

  def convert_with_direct_translation(spec_path, type_paths) when is_binary(spec_path) and is_list(type_paths) do
    try do

      {_time_type_translation, translated_types} = :timer.tc(&TypeTr.process/1, [type_paths])

      {_time_spec_translations, translated_spec} = :timer.tc(&SpecTr.process/1, [spec_path])

      {_time_stringification, stringified_elixir_types} = :timer.tc(&TypeConstr.stringify/2, [translated_spec, translated_types])

      #handle_output(stringified_annotations, time)
      # IO.puts("Translation Time Elapsed: #{time_translation}")
      # IO.puts("Stringification Time Elapsed: #{time_stringification}")

      IO.puts("Translation with User-defined Type Replacement")
      stringified_elixir_types |> Enum.map(fn {line_nums, {module_name, fun_name}, full_expression} ->
        lines = line_nums |> Enum.reduce("", fn num, acc -> if acc == "", do: num |> Integer.to_string(), else: "#{acc}, #{num |> Integer.to_string()}" end)
        name = "#{module_name}.#{fun_name}"
        "Line Number: " <> lines |> IO.puts()
        "Function Name: " <> name |> IO.puts()
        full_expression |> IO.puts()
      end)

      stringified_elixir_types

    catch
      {:CompileError, msg} ->
        #CDuceRepl.close(pid)

        IO.puts("CompileError:\n#{msg}")
    end
  end

  def convert_in_descr(:annotation_form, spec_path, type_paths) when is_binary(spec_path) and is_list(type_paths) do
    try do

      {_time_type_translation, translated_types} = :timer.tc(&TypeTr.process/1, [type_paths])

      {_time_spec_translations, translated_spec} = :timer.tc(&SpecTr.process/1, [spec_path])

      {_time_stringification_type_replacing, descrized_elixir_types} = :timer.tc(&TypeConstr.descrize/3, [:in_string, translated_spec, translated_types])

      #handle_output(stringified_annotations, time)
      # IO.puts("Translation Time Elapsed: #{time_translation}")
      # IO.puts("Stringification Time Elapsed: #{time_stringification}")

      IO.puts("Translation in Descr")
      descrized_elixir_types |> Enum.map(fn {line_nums, {module_name, fun_name}, full_expression} ->
        lines = line_nums |> Enum.reduce("", fn num, acc -> if acc == "", do: num |> Integer.to_string(), else: "#{acc}, #{num |> Integer.to_string()}" end)
        name = "#{module_name}.#{fun_name}"
        "Line Number: " <> lines |> IO.puts()
        "Function Name: " <> name |> IO.puts()
        full_expression |> Descr.to_quoted_string |> IO.puts()
      end)

      descrized_elixir_types

    catch
      {:CompileError, msg} ->
        #CDuceRepl.close(pid)

        IO.puts("CompileError:\n#{msg}")
    end
  end

  def convert_in_descr(:function_form, spec_path, type_paths) when is_binary(spec_path) and is_list(type_paths) do
    try do

      {_time_type_translation, translated_types} = :timer.tc(&TypeTr.process/1, [type_paths]) |> dbg

      {_time_spec_translations, translated_spec} = :timer.tc(&SpecTr.process/1, [spec_path])

      {_time_stringification_type_replacing, descrized_elixir_types} = :timer.tc(&TypeConstr.descrize/3, [:in_string, translated_spec, translated_types])

      #handle_output(stringified_annotations, time)
      # IO.puts("Translation Time Elapsed: #{time_translation}")
      # IO.puts("Stringification Time Elapsed: #{time_stringification}")

      IO.puts("Translation in Descr functions")
      descrized_elixir_types |> Enum.map(fn {line_nums, {module_name, fun_name}, full_expression} ->
        lines = line_nums |> Enum.reduce("", fn num, acc -> if acc == "", do: num |> Integer.to_string(), else: "#{acc}, #{num |> Integer.to_string()}" end)
        name = "#{module_name}.#{fun_name}"
        "Line Number: " <> lines |> IO.puts()
        "Function Name: " <> name |> IO.puts()
        full_expression |> IO.puts()
      end)

      descrized_elixir_types

    catch
      {:CompileError, msg} ->
        #CDuceRepl.close(pid)

        IO.puts("CompileError:\n#{msg}")
    end
  end

  # Comment it until the intersection issue is fixed - 19th March 2026
  # defp insert_expression(input_path, output_path, elixir_types, prefix \\ "") do
  #   try do
  #     content_lines = input_path |> File.read!() |> String.split("\n")

  #     new_content_lines = elixir_types
  #       # |> Enum.sort_by(fn {line, _} -> -line end)  # insert from bottom to avoid shifting
  #       |> Enum.reverse() # insert from bottom to avoid shifting
  #       |> Enum.reduce(content_lines, fn {line_nums, {_module_name, _fun_name}, full_expression}, acc ->
  #         line_num = List.last(line_nums)
  #         {padding, _} = acc |> Enum.at(line_num - 1) |> String.to_charlist() |> Enum.reduce({"", true}, fn char, {pad, pad?} -> if pad? and char == 32, do: {pad <> " ", true}, else: {pad, false} end)
  #         line_content = padding <> if prefix == "", do: full_expression, else: prefix <> " " <> full_expression
  #         acc |> List.insert_at(line_num, line_content)
  #       end)

  #     output_path |> File.write(new_content_lines |> Enum.join("\n"))
  #   catch
  #     {:CompileError, msg} -> IO.puts("CompileError:\n#{msg}")
  #   end
  # end

  defp insert_expression(input_path, output_path, elixir_types, prefix \\ "") do
    try do
      content_lines = input_path |> File.read!() |> String.split("\n")

      new_content_lines = elixir_types
        |> Enum.reverse()             # insert from bottom to avoid shifting
        |> Enum.reduce(content_lines, fn {line_nums, {_module_name, _fun_name}, full_expression}, acc ->
          line_num = List.last(line_nums)
          {padding, _} = acc |> Enum.at(line_num - 1) |> String.to_charlist() |> Enum.reduce({"", true}, fn char, {pad, pad?} -> if pad? and char == 32, do: {pad <> " ", true}, else: {pad, false} end)
          line_content = padding <> if prefix == "", do: full_expression, else: prefix <> " " <> full_expression
          acc |> List.insert_at(line_num, line_content)
        end)

      output_path |> File.write(new_content_lines |> Enum.join("\n"))
    catch
      {:CompileError, msg} -> IO.puts("CompileError:\n#{msg}")
    end
  end

  if function_exported?(Migrator, :main, 1) do
    Migrator.main(System.argv())
  end
end
