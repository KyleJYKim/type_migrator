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
    mode =
      case mode do
        m when is_atom(m) -> m
        m when is_binary(m) -> String.to_atom(m)
      end

    # Expand directories in type_paths to file paths before proceeding
    type_paths = type_paths |> Enum.flat_map(&expand_path/1)

    case mode do
      :direct ->
        elixir_types = convert(:stringify_direct, spec_path)
        create_new_file_with_insertion(spec_path, "test/direct/", elixir_types, "#" <> " ")

      :replacement ->
        elixir_types = convert(:stringify_with_replacement, spec_path, type_paths)
        create_new_file_with_insertion(spec_path, "test/replacement/", elixir_types, "#" <> " ")

      :descr ->
        elixir_types = convert(:descrize_for_annotation, spec_path, type_paths)
        create_new_file_with_insertion(spec_path, "test/descr/", elixir_types, "#" <> " ")

      :descr_assert ->
        elixir_types = convert(:descrize_for_assert, spec_path, type_paths)
        create_new_file_with_insertion(spec_path, "test/descr_assert/", elixir_types, "@assert_type" <> " ", true)

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

  defp convert(:stringify_direct, spec_path) when is_binary(spec_path) do
    try do

      {_time_spec_translations, translated_spec} = :timer.tc(&SpecTr.process/1, [spec_path])

      {_time_stringification, stringified_elixir_types} = :timer.tc(&TypeConstr.process/2, [:stringify_direct, translated_spec])

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

  defp convert(:stringify_with_replacement, spec_path, type_paths) when is_binary(spec_path) and is_list(type_paths) do
    try do

      {_time_type_translation, translated_types} = :timer.tc(&TypeTr.process/1, [type_paths])

      # translated_types ++ elixir_module_types

      {_time_spec_translations, translated_spec} = :timer.tc(&SpecTr.process/1, [spec_path])

      {_time_stringification, stringified_elixir_types} = :timer.tc(&TypeConstr.process/3, [:stringify_with_replacement, translated_spec, translated_types])

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

  defp convert(:descrize_for_annotation, spec_path, type_paths) when is_binary(spec_path) and is_list(type_paths) do
    try do

      {_time_type_translation, translated_types} = :timer.tc(&TypeTr.process/1, [type_paths])

      {_time_spec_translations, translated_spec} = :timer.tc(&SpecTr.process/1, [spec_path])

      {_time_stringification_type_replacing, descrized_elixir_types} = :timer.tc(&TypeConstr.process/3, [:descrize_for_annotation, translated_spec, translated_types])

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

      # return after converting Descr to string for insertion.
      descrized_elixir_types |> Enum.map(fn {line_nums, {module_name, fun_name}, full_expression} -> {line_nums, {module_name, fun_name}, full_expression |> Descr.to_quoted_string} end)

    catch
      {:CompileError, msg} ->
        #CDuceRepl.close(pid)

        IO.puts("CompileError:\n#{msg}")
    end
  end

  defp convert(:descrize_for_assert, spec_path, type_paths) when is_binary(spec_path) and is_list(type_paths) do
    try do

      {_time_type_translation, translated_types} = :timer.tc(&TypeTr.process/1, [type_paths])

      {_time_spec_translations, translated_spec} = :timer.tc(&SpecTr.process/1, [spec_path])

      {_time_stringification_type_replacing, descrized_elixir_types} = :timer.tc(&TypeConstr.process/3, [:descrize_for_assert, translated_spec, translated_types])

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

  defp create_new_file_with_insertion(spec_path, save_path, elixir_types, prefix, import_descr? \\ false) do
    spec_path_list = spec_path
      |> String.split(".")
      |> Enum.reverse()
      |> tl()
    output_name = spec_path_list
      |> List.replace_at(0, hd(spec_path_list) <> "_test.exs")
      |> Enum.reverse()
      |> Enum.reduce("", fn chunk, acc -> if acc == "", do: chunk, else: acc <> "." <> chunk end)
    output_path = save_path <> (output_name |> String.split("/") |> List.last())

    if !File.exists?(save_path) do
      File.mkdir_p!(save_path)
    end

    insert_expression(spec_path, output_path, elixir_types, prefix, import_descr?)
  end

  defp insert_expression(input_path, output_path, elixir_types, prefix, import_descr?) do
    try do
      # content_lines = input_path |> File.read!() |> String.split("\n")
      file = input_path |> File.read!

      content_ast = file |> Code.string_to_quoted!

      content_lines = file |> String.split("\n")

      new_content_lines = elixir_types
        |> Enum.reverse()             # insert from bottom to avoid shifting
        |> Enum.reduce(content_lines, fn {line_nums, {_module_name, _fun_name}, full_expression}, acc ->
          line_num = List.last(line_nums)
          {padding, _} = acc |> Enum.at(line_num - 1) |> String.to_charlist() |> Enum.reduce({"", true}, fn char, {pad, pad?} -> if pad? and char == 32, do: {pad <> " ", true}, else: {pad, false} end)
          line_content = padding <> prefix <> (full_expression |> String.replace("\n", " "))
          acc |> List.insert_at(line_num, line_content)
        end)

      if import_descr? and !is_descr_imported?(content_ast)  do
        module_start_idx = content_lines
          |> Enum.find_index(fn line -> String.contains?(line, "defmodule #{get_first_module_name(content_ast)}") end)
        new_content_lines_with_import = new_content_lines
          |> List.insert_at(module_start_idx + 1, "  import Module.Types.Descr\n")

        output_path |> File.write(new_content_lines_with_import |> Enum.join("\n"))
      else
        output_path |> File.write(new_content_lines |> Enum.join("\n"))
      end
    catch
      {:CompileError, msg} -> IO.puts("CompileError:\n#{msg}")
    end
  end

  defp is_descr_imported?(ast) do

    {:defmodule, _, [{:__aliases__, _, _}, [do: module_ast]]} = ast
    {:__block__, _, block} = module_ast
    block |> Enum.any?(
        &case &1 do
          {:import, _, [{:__aliases__, _, [:Module, :Types, :Descr]}]} -> true
          _ -> false
        end
      )
  end

  defp get_first_module_name(ast) do

    {:defmodule, _, [{:__aliases__, _, module_name}, [do: _]]} = ast
    module_name |> Enum.reduce("", fn name, acc -> if acc == "", do: Atom.to_string(name), else: acc <> "." <> Atom.to_string(name) end)
  end

  if function_exported?(Migrator, :main, 1) do
    Migrator.main(System.argv())
  end
end
