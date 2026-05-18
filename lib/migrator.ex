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
                              <mode>              <spec_path>     [type_paths] (optional)
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
  require Logger

  @root_path "lib/test/"
  @path_direct @root_path <> "direct/"
  @path_replacement @root_path <> "replace/"
  @path_descr @root_path <> "descr/"
  @path_descr_assert @root_path <> "descr_assert/"

  @descr_prefix "@assert_type_form"

  @doc """
    Example:
      Migrator.main([:descr_assert, "test/descr_test.exs", "../elixir/lib/elixir/lib"])
  """
  def main(args) do
    case args do
      [mode, spec_path, type_paths] ->
        save_path = Regex.replace(~r"\w+(?*(?i))\.ex", spec_path, "") |> dbg
        run(mode, spec_path, save_path, type_paths)

      [mode, spec_path, save_path | type_paths] ->
        run(mode, spec_path, save_path, type_paths)

      [mode, spec_path | type_paths] ->
        save_path = Regex.replace(~r"\w+(?*(?i))\.ex", spec_path, "")
        run(mode, spec_path, save_path, type_paths)

      _ ->
        IO.puts("Error: wrong arguments")
    end
  end

  defp run(mode, spec_path, save_path, type_paths) do
    mode =
      case mode do
        m when is_atom(m) -> m
        m when is_binary(m) -> String.to_atom(m)
      end

    # Expand directories in type_paths to file paths before proceeding
    type_paths =
      case type_paths do
        [] -> [spec_path]
        _ -> Enum.flat_map(type_paths, &expand_path/1) |> Enum.concat([spec_path]) |> Enum.uniq()
      end

    case mode do
      :direct ->
        elixir_types = convert(:stringify_direct, spec_path)
        create_new_file_with_insertion(spec_path, save_path, elixir_types, "# $" <> " ")

      :replace ->
        elixir_types = convert(:stringify_replace, spec_path, type_paths)
        create_new_file_with_insertion(spec_path, save_path, elixir_types, "# $" <> " ")

      :descr ->
        elixir_types = convert(:descrize_annotation, spec_path, type_paths)
        create_new_file_with_insertion(spec_path, save_path, elixir_types, "# $" <> " ")

      :descr_assert ->
        elixir_types = convert(:descrize_assert, spec_path, type_paths)
        create_new_file_with_insertion(spec_path, save_path, elixir_types, @descr_prefix <> " ")

        elixir_types

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

      {_time_stringification, stringified_elixir_types} =
        :timer.tc(&TypeConstr.process/2, [:stringify_direct, translated_spec])

      # handle_output(stringified_annotations, time)
      # IO.puts("Translation Time Elapsed: #{time_translation}")
      # IO.puts("Stringification Time Elapsed: #{time_stringification}")

      IO.puts("Translation without User-defined Type Replacement")

      stringified_elixir_types
      |> Enum.map(fn {line_nums, {module_name, fun_name}, full_expression} ->
        lines =
          line_nums
          |> Enum.reduce("", fn num, acc ->
            if acc == "",
              do: num |> Integer.to_string(),
              else: "#{acc}, #{num |> Integer.to_string()}"
          end)

        name = "#{module_name}.#{fun_name}"
        ("Line Number: " <> lines) |> IO.puts()
        ("Function Name: " <> name) |> IO.puts()
        full_expression |> IO.puts()
      end)

      stringified_elixir_types
    catch
      {:CompileError, msg} ->
        # CDuceRepl.close(pid)

        IO.puts("CompileError:\n#{msg}")
    end
  end

  defp convert(:stringify_replace, spec_path, type_paths)
       when is_binary(spec_path) and is_list(type_paths) do
    try do
      {_time_type_translation, translated_types} = :timer.tc(&TypeTr.process/1, [type_paths])

      {_time_spec_translations, translated_spec} = :timer.tc(&SpecTr.process/1, [spec_path])

      {_time_stringification, stringified_elixir_types} =
        :timer.tc(&TypeConstr.process/3, [:stringify_replace, translated_spec, translated_types])

      # handle_output(stringified_annotations, time)
      # IO.puts("Translation Time Elapsed: #{time_translation}")
      # IO.puts("Stringification Time Elapsed: #{time_stringification}")

      IO.puts("Translation with User-defined Type Replacement")

      stringified_elixir_types
      |> Enum.map(fn {line_nums, {module_name, fun_name}, full_expression} ->
        lines =
          line_nums
          |> Enum.reduce("", fn num, acc ->
            if acc == "",
              do: num |> Integer.to_string(),
              else: "#{acc}, #{num |> Integer.to_string()}"
          end)

        name = "#{module_name}.#{fun_name}"
        ("Line Number: " <> lines) |> IO.puts()
        ("Function Name: " <> name) |> IO.puts()
        full_expression |> IO.puts()
      end)

      stringified_elixir_types
    catch
      {:CompileError, msg} ->
        # CDuceRepl.close(pid)

        IO.puts("CompileError:\n#{msg}")
    end
  end

  defp convert(:descrize_annotation, spec_path, type_paths)
       when is_binary(spec_path) and is_list(type_paths) do
    try do
      {_time_type_translation, translated_types} = :timer.tc(&TypeTr.process/1, [type_paths])

      {_time_spec_translations, translated_spec} = :timer.tc(&SpecTr.process/1, [spec_path])

      {_time_stringification_type_replacing, descrized_elixir_types} =
        :timer.tc(&TypeConstr.process/3, [:descrize_annotation, translated_spec, translated_types])

      # handle_output(stringified_annotations, time)
      # IO.puts("Translation Time Elapsed: #{time_translation}")
      # IO.puts("Stringification Time Elapsed: #{time_stringification}")

      IO.puts("Translation in Descr")

      descrized_elixir_types
      |> Enum.map(fn {line_nums, {module_name, fun_name}, full_expression} ->
        lines =
          line_nums
          |> Enum.reduce("", fn num, acc ->
            if acc == "",
              do: num |> Integer.to_string(),
              else: "#{acc}, #{num |> Integer.to_string()}"
          end)

        name = "#{module_name}.#{fun_name}"
        ("Line Number: " <> lines) |> IO.puts()
        ("Function Name: " <> name) |> IO.puts()
        full_expression |> Descr.to_quoted_string() |> IO.puts()
      end)

      # return after converting Descr to string for insertion.
      descrized_elixir_types
      |> Enum.map(fn {line_nums, {module_name, fun_name}, full_expression} ->
        {line_nums, {module_name, fun_name}, full_expression |> Descr.to_quoted_string()}
      end)
    catch
      {:CompileError, msg} ->
        # CDuceRepl.close(pid)

        IO.puts("CompileError:\n#{msg}")
    end
  end

  defp convert(:descrize_assert, spec_path, type_paths)
       when is_binary(spec_path) and is_list(type_paths) do
    try do
      {_time_type_translation, translated_types} = :timer.tc(&TypeTr.process/1, [type_paths])

      {_time_spec_translations, translated_spec} = :timer.tc(&SpecTr.process/1, [spec_path])

      {_time_stringification_type_replacing, descrized_elixir_types} =
        :timer.tc(&TypeConstr.process/3, [:descrize_assert, translated_spec, translated_types])

      # handle_output(stringified_annotations, time)
      # IO.puts("Translation Time Elapsed: #{time_translation}")
      # IO.puts("Stringification Time Elapsed: #{time_stringification}")

      IO.puts("Translation in Descr functions")

      # descrized_elixir_types |> Enum.map(fn {line_nums, {module_name, fun_name}, full_expression} ->
      #   lines = line_nums |> Enum.reduce("", fn num, acc -> if acc == "", do: num |> Integer.to_string(), else: "#{acc}, #{num |> Integer.to_string()}" end)
      #   name = "#{module_name}.#{fun_name}"
      #   "Line Number: " <> lines |> IO.puts()
      #   "Function Name: " <> name |> IO.puts()
      #   full_expression |> IO.puts()
      # end)

      descrized_elixir_types
    catch
      {:CompileError, msg} ->
        # CDuceRepl.close(pid)

        IO.puts("CompileError:\n#{msg}")
    end
  end

  # New public entry point that accepts pre-computed translated_types
  def run_with_types(mode, spec_path, translated_types) do
    save_path = Regex.replace(~r/\w+\.exs?$/, spec_path, "")

    case mode do
      :descr_assert ->
        elixir_types = convert_with_types(:descrize_assert, spec_path, translated_types)
        create_new_file_with_insertion(spec_path, save_path, elixir_types, @descr_prefix <> " ")
        elixir_types

      :descr ->
        elixir_types = convert_with_types(:descrize_annotation, spec_path, translated_types)
        create_new_file_with_insertion(spec_path, save_path, elixir_types, "# $" <> " ")
        elixir_types

      :replace ->
        elixir_types = convert_with_types(:stringify_replace, spec_path, translated_types)
        create_new_file_with_insertion(spec_path, save_path, elixir_types, "# $" <> " ")
        elixir_types

      _ ->
        Logger.error("Unknown mode: #{mode}")
        []
    end
  end

  # Mirrors convert/3 but receives translated_types directly — no TypeTr.process call
  defp convert_with_types(:descrize_assert, spec_path, translated_types) do
    try do
      {_t, translated_spec} = :timer.tc(&SpecTr.process/1, [spec_path])
      {_t, descrized} = :timer.tc(&TypeConstr.process/3, [:descrize_assert, translated_spec, translated_types])
      descrized
    catch
      {:CompileError, msg} -> Logger.error("CompileError:\n#{msg}"); []
    end
  end

  defp convert_with_types(:descrize_annotation, spec_path, translated_types) do
    try do
      {_t, translated_spec} = :timer.tc(&SpecTr.process/1, [spec_path])
      {_t, descrized} = :timer.tc(&TypeConstr.process/3, [:descrize_annotation, translated_spec, translated_types])
      descrized
      |> Enum.map(fn {line_nums, {m, f}, expr} ->
        {line_nums, {m, f}, Descr.to_quoted_string(expr)}
      end)
    catch
      {:CompileError, msg} -> Logger.error("CompileError:\n#{msg}"); []
    end
  end

  defp convert_with_types(:stringify_replace, spec_path, translated_types) do
    try do
      {_t, translated_spec} = :timer.tc(&SpecTr.process/1, [spec_path])
      {_t, stringified} = :timer.tc(&TypeConstr.process/3, [:stringify_replace, translated_spec, translated_types])
      stringified
    catch
      {:CompileError, msg} -> Logger.error("CompileError:\n#{msg}"); []
    end
  end


  defp create_new_file_with_insertion(spec_path, _save_path, elixir_types, prefix) do
    # spec_path_list = spec_path
    #   |> String.split(".")
    #   |> Enum.reverse()
    #   |> tl()
    # output_name = spec_path_list
    #   |> List.replace_at(0, hd(spec_path_list) <> "_test.exs")
    #   |> Enum.reverse()
    #   |> Enum.reduce("", fn chunk, acc -> if acc == "", do: chunk, else: acc <> "." <> chunk end)
    # output_path = save_path <> (output_name |> String.split("/") |> List.last())

    # if !File.exists?(save_path) do
    #   File.mkdir_p!(save_path)
    # end

    insert_expression(spec_path, spec_path, elixir_types, prefix)
  end

  defp insert_expression(input_path, output_path, elixir_types, prefix) do
    try do
      original_lines = input_path |> File.read!() |> String.split("\n")

      # Strip annotations but track how original line numbers map to stripped ones
      {stripped_lines, original_to_stripped} =
        original_lines
        |> Enum.with_index()
        |> Enum.reduce({[], %{}, 0}, fn {line, orig_idx}, {lines_acc, mapping, stripped_idx} ->
          if String.contains?(line, prefix) do
            # Annotation line — skip, don't advance stripped_idx
            {lines_acc, mapping, stripped_idx}
          else
            {lines_acc ++ [line], Map.put(mapping, orig_idx, stripped_idx), stripped_idx + 1}
          end
        end)
        |> then(fn {lines, mapping, _} -> {lines, mapping} end)

      new_content_lines =
        elixir_types
        |> Enum.reverse()
        |> Enum.reduce(stripped_lines, fn {line_nums, {_module_name, _fun_name}, full_expression},
                                          acc ->
          orig_idx = List.first(line_nums) - 1
          # Fall back to orig_idx if not in mapping (first run, no stripping happened)
          line_idx = Map.get(original_to_stripped, orig_idx, orig_idx)

          {padding, _} =
            acc
            |> Enum.at(line_idx)
            |> String.to_charlist()
            |> Enum.reduce({"", true}, fn char, {pad, pad?} ->
              if pad? and char == 32, do: {pad <> " ", true}, else: {pad, false}
            end)

          line_content = padding <> prefix <> (full_expression |> String.replace("\n", " "))
          List.insert_at(acc, line_idx, line_content)
        end)

      File.write(output_path, Enum.join(new_content_lines, "\n"))
    catch
      {:CompileError, msg} -> IO.puts("CompileError:\n#{msg}")
    end
  end

  if function_exported?(Migrator, :main, 1) do
    Migrator.main(System.argv())
  end
end
