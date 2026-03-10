defmodule Migrator.TypeTranslator do

  import Migrator.Translator.Utils

  def process(paths) when is_list(paths) do
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
      |> mark_type_variable
      |> parse_type()           |> Enum.reduce(%{}, fn {k, v}, acc -> Map.merge(acc, %{k => v} |> IO.inspect(label: "\n ### PARSE TYPE FUNCTION RESULT \n")) end)
      |> translate_type()

      |> Enum.reduce(%{}, fn {k, v}, acc -> v |> Enum.map(fn x -> %{k => x} |> IO.inspect(label: "\n ### TRANSLATE TYPE FUNCTION RESULT \n") end)
        Map.merge(acc, %{k => v}) end)

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

          # also the one with parentheses?

        _ -> acc
      end
    end

    {ast, "", %{}} |> extractor.(extractor)
  end

  defp mark_type_variable(type_tree) do

    type_var_marker = fn {module, type_defs} -> (

      type_defs = type_defs |> Enum.map(fn {user_defined_type, defining_type} ->
        # user_defined_type_new = case user_defined_type do
        #   {user_type, _, nil} -> {user_type, [arity: 0], :__user_type_variable__}
        #   {user_type, _, elements} when is_list(elements) -> {user_type, [arity: length(elements)], :__user_type_variable__}
        #   _ -> {user_defined_type, defining_type}
        # end
        case user_defined_type do
          {user_type, _, elements} when is_list(elements) and length(elements) > 0 ->
            user_defined_type_new = {user_type, [], elements |> Enum.map(fn {type_var, _,  _} -> {type_var, [],  :__user_type_variable__} end)}
            defining_type_new = Macro.prewalk(defining_type, fn type ->
              case type do
                {type_var, _,  nil_or_empty_list} when nil_or_empty_list == nil or nil_or_empty_list == [] ->
                  if elements |> Enum.find_value(fn {elem_type_var, _, _} -> elem_type_var == type_var end) do
                    {type_var, [],  :__user_type_variable__}
                  else
                    type
                  end
                _ -> type
              end
            end)
            {user_defined_type_new, defining_type_new}
          {user_type, _, _} -> {{user_type, [], []}, defining_type}
        end
      end)

      {module, type_defs}
    )end

    type_tree |> Enum.map(type_var_marker)
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

  defp translate_type(parsed_types) do

    replacing_definition = fn {defining_type, current_type_defs, whole_type_definition}, replacing_fun ->
        replacing_fun = &replacing_fun.(&1, replacing_fun)
        case defining_type do
          {:union, {type1, type2}} ->
            found_type1 = {type1, current_type_defs, whole_type_definition} |> replacing_fun.()
            found_type2 = {type2, current_type_defs, whole_type_definition} |> replacing_fun.()
            {:union, {found_type1, found_type2}}

          {:fun, {:all_arity, type_out}} ->
            {:fun, {:all_arity, {type_out, current_type_defs, whole_type_definition} |> replacing_fun.()}}
          {:fun, {types_in, type_out}} ->
            {:fun, {types_in |> Enum.map(fn type_in -> {type_in, current_type_defs, whole_type_definition} |> replacing_fun.() end), {type_out, current_type_defs, whole_type_definition} |> replacing_fun.()}}
          {:non_empty_list, {type_content, type_termination}} ->
            {:non_empty_list, {{type_content, current_type_defs, whole_type_definition} |> replacing_fun.(), {type_termination, current_type_defs, whole_type_definition} |> replacing_fun.()}}
          {:tuple, types} ->
            {:tuple, types |> Enum.map(fn type -> {type, current_type_defs, whole_type_definition} |> replacing_fun.() end)}
          {:struct, {strt_name, fields}} ->
            {:struct, {strt_name, fields |> Enum.map(fn {type_left, type_right} -> {{type_left, current_type_defs, whole_type_definition} |> replacing_fun.(), {type_right, current_type_defs, whole_type_definition} |> replacing_fun.()} end)}}
          {:open_map, fields} ->
            {:open_map, fields |> Enum.map(fn {type_left, type_right} -> {{type_left, current_type_defs, whole_type_definition} |> replacing_fun.(), {type_right, current_type_defs, whole_type_definition} |> replacing_fun.()} end)}
          {:if_set, type} -> {:if_set, {type, current_type_defs, whole_type_definition} |> replacing_fun.()}
          {:gradual, type} -> {:gradual, {type, current_type_defs, whole_type_definition} |> replacing_fun.()}

          {:remote_type, {modules, def_type}} ->
            module_to_find = modules |> Enum.reduce("", fn m, acc -> if acc == "", do: "#{m}", else: "#{acc}.#{m}" end)
            type_defs_to_be_searched = whole_type_definition |> Map.get(module_to_find)
            found_type =
              if type_defs_to_be_searched do
                type_defs_to_be_searched |> Enum.find_value(fn {udt, dt} -> if udt == {:user_type, def_type}, do: dt, else: nil end)
              else
                nil
              end

            if found_type == nil do
              {:def_not_found, {modules, def_type}}
            else
              {found_type, type_defs_to_be_searched, whole_type_definition} |> replacing_fun.()
            end

          {:user_type, def_type} ->
            found_type = current_type_defs |> Enum.find_value(fn {udt, dt} -> if udt == {:user_type, def_type}, do: dt, else: nil end)

            if found_type == nil do
              {:def_not_found, def_type}
            else
              {found_type, current_type_defs, whole_type_definition} |> replacing_fun.()
            end

          _ -> defining_type
        end
      end

    total_translator = fn parsed_types ->
      translated_types = parsed_types
        |> Enum.reduce(%{}, fn {module, type_defs}, acc ->
          translated_type_defs = type_defs
            |> Enum.map(fn {user_defined_type, defining_type} ->
              {user_defined_type |> translate(), defining_type |> translate}
            end)

          acc |> Map.merge(%{module => translated_type_defs})
        end)

      translated_types
        |> Enum.reduce(%{}, fn {module, type_defs}, acc ->
          replaced_type_defs = type_defs
            |> Enum.map(fn {user_defined_type, defining_type} ->
              {user_defined_type, {defining_type, type_defs, translated_types} |> replacing_definition.(replacing_definition)}
            end)

          acc |> Map.merge(%{module => replaced_type_defs})
        end)
    end

    parsed_types |> total_translator.()
  end

end
