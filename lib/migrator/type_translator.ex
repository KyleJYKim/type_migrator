defmodule Migrator.TypeTranslator do

  import Migrator.Translator.Utils

  def process(paths) do
    extracted_types = paths |> Enum.map(fn path ->
      path |> File.read!
      |> Code.string_to_quoted!
      |> extract_type

      # |> Enum.reduce(%{}, fn {x, y}, acc -> # for debugging
      #   %{x => y} |> IO.inspect(label: "### EXTRACT TYPE FUNCTION RESULT \n")
      #   acc |> Map.put(x, y)
      # end)
    end)
    |> Enum.reduce(%{}, fn elem, acc -> Map.merge(acc, elem |> IO.inspect(label: "### EXTRACT TYPE FUNCTION RESULT \n")) end)

    # IO.puts("\nQUOTED \n")
    # quoted |> IO.inspect()

    translated_types = extracted_types
      |> parse_type()           |> Enum.reduce(%{}, fn {k, v}, acc -> Map.merge(acc, %{k => v} |> IO.inspect(label: "\n ### PARSE TYPE FUNCTION RESULT \n")) end)
      #|> translate_type()       |> Enum.reduce(%{}, fn {k, v}, acc -> Map.merge(acc, %{k => v} |>  IO.inspect(label: "\n ### TRANSLATE TYPE FUNCTION RESULT \n")) end)

    translated_types
  end

  defp extract_type(ast) do

    extractor = fn {ast, module, acc}, extractor_fun ->
      extractor_fun = &extractor_fun.(&1, extractor_fun)
      case ast do
        {:defmodule, _, [{:__aliases__, _, [module_name]}, [do: module_ast]]} ->
          module = if module == "", do: "#{module_name}", else: "#{module}.#{module_name}"
          {module_ast, module, acc} |> extractor_fun.()

        {:__block__, [], block} ->
          block |> Enum.reduce(acc, fn block_ast, acc -> {block_ast, module, acc} |> extractor_fun.() end)

        {:@, _, [{:type, _, [{:"::", _, [user_defined_type, defining_type]}]}]} ->
          {_, new_acc} = acc |> Map.get_and_update(module, fn type_defs ->
              if type_defs == nil do
                {type_defs, [{user_defined_type, defining_type}]}
              else
                {type_defs, type_defs ++ [{user_defined_type, defining_type}]}
              end
            end)
          new_acc

          # also the one with parentheses

        _ -> acc
      end
    end

    {ast, "", %{}} |> extractor.(extractor)
  end

  defp parse_type(extracted_types) do

    total_parser = fn {module, type_defs} -> (

      type_defs = type_defs |> Enum.map(fn {user_defined_type, defining_type} ->
          {user_defined_type |> parse, defining_type |> parse}
        end)

      %{module => type_defs}
    )end

    extracted_types |> Enum.reduce(%{}, fn type_definition, acc -> acc |> Map.merge(type_definition |> total_parser.()) end)
  end

  # defp translate_spec(parsed_type_tree) do

  #   total_translator = fn {line_num, name, inputs, output, guards} -> (

  #     # need to replace the defined types to the org types. Look in the list!
  #     # AFTER TRANSLATION
  #     #type_defs = type_defs |>
  #     inputs = inputs |> Enum.map(fn input -> input |> translation.() end)

  #     {line_num, name, inputs, output, guards}
  #   )end

  #   parsed_spec_tree |> Enum.map(total_translator)
  # end

end
