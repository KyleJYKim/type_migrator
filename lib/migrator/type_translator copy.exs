defmodule Migrator.TypeTranslator do
  import Migrator.Translator.Utils

  def process(paths) when is_list(paths) do
    extracted_types =
      paths
      |> Enum.map(fn path ->
        case safe_string_to_quoted(path) do
          {:ok, ast} -> extract_type(ast)
          :error -> %{}
        end
      end)
      |> Enum.reduce(%{}, fn elem, acc -> Map.merge(acc, elem) end)

    translated_types =
      extracted_types
      |> mark_type_variable
      |> parse_type
      |> translate_type

    # |> Enum.reduce(%{}, fn {k, v}, acc -> v |> Enum.map(fn x -> %{k => x} |> IO.inspect(label: "\n ### TRANSLATE TYPE FUNCTION RESULT \n") end)
    #   Map.merge(acc, %{k => v}) end)

    translated_types
  end

  def extract_type(ast) do
    extractor = fn {ast, module_name_acc, acc}, extractor_fun ->
      extractor_fun = &extractor_fun.(&1, extractor_fun)

      case ast do
        {:defmodule, _, [{:__aliases__, _, module_name}, [do: module_ast]]} ->
          module_name_new =
            module_name
            |> Enum.reduce("", fn name, acc ->
              if acc == "", do: Atom.to_string(name), else: acc <> "." <> Atom.to_string(name)
            end)

          module_name_acc =
            if module_name_acc == "",
              do: "#{module_name_new}",
              else: "#{module_name_acc}.#{module_name_new}"

          {module_ast, module_name_acc, acc} |> extractor_fun.()

        {:__block__, _, block} ->
          block
          |> Enum.reduce(acc, fn block_ast, acc ->
            {block_ast, module_name_acc, acc} |> extractor_fun.()
          end)

        {:@, _, [{:type, _, [{:"::", _, [user_defined_type, defining_type]}]}]} ->
          {_, new_acc} =
            acc
            |> Map.get_and_update(module_name_acc, fn type_defs ->
              if type_defs == nil do
                {type_defs, [{user_defined_type, defining_type}]}
              else
                {type_defs, type_defs ++ [{user_defined_type, defining_type}]}
              end
            end)

          new_acc

        {:@, _, [{:opaque, _, [{:"::", _, [user_defined_type, defining_type]}]}]} ->
          {_, new_acc} =
            acc
            |> Map.get_and_update(module_name_acc, fn type_defs ->
              if type_defs == nil do
                {type_defs, [{user_defined_type, defining_type}]}
              else
                {type_defs, type_defs ++ [{user_defined_type, defining_type}]}
              end
            end)

          new_acc

        {:@, _, [{:typep, _, [{:"::", _, [user_defined_type, defining_type]}]}]} ->
          {_, new_acc} =
            acc
            |> Map.get_and_update(module_name_acc, fn type_defs ->
              if type_defs == nil do
                {type_defs, [{user_defined_type, defining_type}]}
              else
                {type_defs, type_defs ++ [{user_defined_type, defining_type}]}
              end
            end)

          new_acc

        _ ->
          acc
      end
    end

    {ast, "", %{}} |> extractor.(extractor)
  end

  defp mark_type_variable(type_tree) do
    type_tree
    |> Enum.map(fn {module, type_defs} ->
      type_defs =
        type_defs
        |> Enum.map(fn {user_defined_type, defining_type} ->
          case user_defined_type do
            {user_type, _, elements} when is_list(elements) and length(elements) > 0 ->
              user_defined_type_new =
                {user_type, [],
                 elements
                 |> Enum.map(fn {type_var, _, _} -> {type_var, [], :__user_type_variable__} end)}

              defining_type_new =
                Macro.prewalk(defining_type, fn type ->
                  case type do
                    {type_var, _, nil_or_empty_list}
                    when nil_or_empty_list == nil or nil_or_empty_list == [] ->
                      if elements
                         |> Enum.find_value(fn {elem_type_var, _, _} ->
                           elem_type_var == type_var
                         end) do
                        {type_var, [], :__user_type_variable__}
                      else
                        type
                      end

                    _ ->
                      type
                  end
                end)

              {user_defined_type_new, defining_type_new}

            {user_type, _, _} ->
              {{user_type, [], []}, defining_type}
          end
        end)

      {module, type_defs}
    end)
  end

  defp parse_type(extracted_types) do
    total_parser = fn {module, type_defs} ->
      type_defs =
        type_defs
        |> Enum.map(fn {user_defined_type, defining_type} ->
          {user_defined_type |> parse(module), defining_type |> parse(module)}
        end)

      %{module => type_defs}
    end

    extracted_types
    |> Enum.reduce(%{}, fn type_definition, acc ->
      acc |> Map.merge(type_definition |> total_parser.())
    end)
  end

  defp translate_type(parsed_types) do
    replacing_definition = fn {{root_user_defined_types, defining_type}, current_type_defs,
                               whole_type_definition},
                              replacing_fun ->
      replacing_fun = &replacing_fun.(&1, replacing_fun)

      case defining_type do
        {:union, {type1, type2}} ->
          found_type1 =
            {{root_user_defined_types, type1}, current_type_defs, whole_type_definition}
            |> replacing_fun.()

          found_type2 =
            {{root_user_defined_types, type2}, current_type_defs, whole_type_definition}
            |> replacing_fun.()

          {:union, {found_type1, found_type2}}

        {:fun, {:all_arity, type_out}} ->
          {:fun,
           {:all_arity,
            {{root_user_defined_types, type_out}, current_type_defs, whole_type_definition}
            |> replacing_fun.()}}

        {:fun, {types_in, type_out}} ->
          {:fun,
           {types_in
            |> Enum.map(fn type_in ->
              {{root_user_defined_types, type_in}, current_type_defs, whole_type_definition}
              |> replacing_fun.()
            end),
            {{root_user_defined_types, type_out}, current_type_defs, whole_type_definition}
            |> replacing_fun.()}}

        {:non_empty_list, {type_content, type_termination}} ->
          {:non_empty_list,
           {{{root_user_defined_types, type_content}, current_type_defs, whole_type_definition}
            |> replacing_fun.(),
            {{root_user_defined_types, type_termination}, current_type_defs,
             whole_type_definition}
            |> replacing_fun.()}}

        {:tuple, types} ->
          {:tuple,
           types
           |> Enum.map(fn type ->
             {{root_user_defined_types, type}, current_type_defs, whole_type_definition}
             |> replacing_fun.()
           end)}

        {:struct, {strt_name, fields}} ->
          {:struct,
           {strt_name,
            fields
            |> Enum.map(fn {type_left, type_right} ->
              {{{root_user_defined_types, type_left}, current_type_defs, whole_type_definition}
               |> replacing_fun.(),
               {{root_user_defined_types, type_right}, current_type_defs, whole_type_definition}
               |> replacing_fun.()}
            end)}}

        {:closed_map, fields} ->
          {:closed_map,
           fields
           |> Enum.map(fn {type_left, type_right} ->
             {{{root_user_defined_types, type_left}, current_type_defs, whole_type_definition}
              |> replacing_fun.(),
              {{root_user_defined_types, type_right}, current_type_defs, whole_type_definition}
              |> replacing_fun.()}
           end)}

        {:if_set, type} ->
          {:if_set,
           {{root_user_defined_types, type}, current_type_defs, whole_type_definition}
           |> replacing_fun.()}

        {:dynamic, type} ->
          {:dynamic,
           {{root_user_defined_types, type}, current_type_defs, whole_type_definition}
           |> replacing_fun.()}

        {:remote_type, {{modules, def_type}, elements}} ->
          recursive? =
            Enum.find_value(root_user_defined_types, fn
              {:user_type, {udt_type, udt_elements}} ->
                udt_type == def_type and length(udt_elements) == length(elements)
              _ -> false
            end)

          if recursive? do
            :dynamic
          else
            type_defs_to_be_searched =
              resolve_module(modules_to_string(modules), whole_type_definition)

            found_type = find_type(type_defs_to_be_searched, def_type, elements)

            if found_type == nil do
              {:def_not_found, {{modules, def_type}, elements}}
            else
              new_root = root_user_defined_types ++ [{:user_type, {{modules, def_type}, elements}}]
              {{new_root, found_type}, type_defs_to_be_searched, whole_type_definition}
              |> replacing_fun.()
            end
          end

        {:remote_type, {modules, def_type}} ->
          recursive? =
            Enum.find_value(root_user_defined_types, fn
              {:user_type, udt_type} when not is_tuple(udt_type) -> udt_type == def_type
              _ -> false
            end)

          if recursive? do
            :dynamic
          else
            type_defs_to_be_searched =
              resolve_module(modules_to_string(modules), whole_type_definition)

            found_type = find_type(type_defs_to_be_searched, def_type, [])

            if found_type == nil do
              {:def_not_found, {modules, def_type}}
            else
              new_root = root_user_defined_types ++ [{:user_type, def_type}]
              {{new_root, found_type}, type_defs_to_be_searched, whole_type_definition}
              |> replacing_fun.()
            end
          end

        {:user_type, {{modules, def_type}, elements}} ->
          recursive? =
            Enum.find_value(root_user_defined_types, fn
              {:user_type, {udt_type, udt_elements}} ->
                udt_type == def_type and length(udt_elements) == length(elements)
              _ -> false
            end)

          if recursive? do
            :dynamic
          else
            type_defs_to_be_searched =
              resolve_module(modules_to_string(modules), whole_type_definition)
              || current_type_defs

            found_type = find_type(type_defs_to_be_searched, def_type, elements)

            if found_type == nil do
              {:def_not_found, {{modules, def_type}, elements}}
            else
              new_root = root_user_defined_types ++ [{:user_type, {{modules, def_type}, elements}}]
              {{new_root, found_type}, type_defs_to_be_searched, whole_type_definition}
              |> replacing_fun.()
            end
          end

        {:user_type, def_type} ->
          recursive? =
            Enum.find_value(root_user_defined_types, fn
              {:user_type, udt_type} when not is_tuple(udt_type) -> udt_type == def_type
              _ -> false
            end)

          if recursive? do
            :dynamic
          else
            # Try current module first, then fall back to global search
            Enum.map(whole_type_definition, fn {k, v} -> if k == "Cachex.Spec", do: IO.inspect(v), else: IO.inspect(k) end)
            found_type =
              find_type(current_type_defs, def_type, []) ||
                Enum.find_value(whole_type_definition, fn {_key, type_defs} -> find_type(type_defs |> dbg, def_type |> dbg, []) end)

            if found_type == nil do
              {:def_not_found, def_type}
            else
              new_root = root_user_defined_types ++ [{:user_type, def_type}]
              {{new_root, found_type}, current_type_defs, whole_type_definition}
              |> replacing_fun.()
            end
          end

        {:def_not_found, {{modules, def_type}, elements}} ->
          type_defs_to_be_searched =
            resolve_module(modules_to_string(modules), whole_type_definition)

          found_type = find_type(type_defs_to_be_searched, def_type, elements)

          if found_type == nil do
            {:def_not_found, {{modules, def_type}, elements}}
          else
            new_root = root_user_defined_types ++ [{:user_type, {{modules, def_type}, elements}}]
            {{new_root, found_type}, type_defs_to_be_searched, whole_type_definition}
            |> replacing_fun.()
          end

        {:def_not_found, {modules, def_type}} ->
          type_defs_to_be_searched =
            resolve_module(modules_to_string(modules), whole_type_definition)

          found_type = find_type(type_defs_to_be_searched, def_type, [])

          if found_type == nil do
            {:def_not_found, {modules, def_type}}
          else
            new_root = root_user_defined_types ++ [{:user_type, def_type}]
            {{new_root, found_type}, type_defs_to_be_searched, whole_type_definition}
            |> replacing_fun.()
          end

        {:def_not_found, def_type} ->
          found_type =
            find_type(current_type_defs, def_type, []) ||
              whole_type_definition
              |> Enum.find_value(fn {_key, type_defs} ->
                find_type(type_defs, def_type, [])
              end)

          if found_type == nil do
            {:def_not_found, def_type}
          else
            new_root = root_user_defined_types ++ [{:user_type, def_type}]
            {{new_root, found_type}, current_type_defs, whole_type_definition}
            |> replacing_fun.()
          end

        _ ->
          defining_type
      end
    end

    total_translator = fn parsed_types ->
      translated_types =
        parsed_types
        |> Enum.reduce(%{}, fn {module, type_defs}, acc ->
          translated_type_defs =
            type_defs
            |> Enum.map(fn {user_defined_type, defining_type} ->
              {translate(user_defined_type), translate(defining_type)}
            end)

          acc |> Map.merge(%{module => translated_type_defs})
        end)

      # Pass the FULL translated_types as the lookup universe from the start
      saturate_replacement(translated_types, translated_types, replacing_definition)
    end

    parsed_types |> total_translator.()
  end

  # Converts modules representation to a dotted string: [:Cachex, :Spec] -> "Cachex.Spec"
  defp modules_to_string(modules) do
    cond do
      is_list(modules) ->
        Enum.reduce(modules, "", fn m, acc ->
          if acc == "", do: "#{m}", else: "#{acc}.#{m}"
        end)
      is_atom(modules) -> Atom.to_string(modules)
      true -> "#{modules}"
    end
  end

  # Finds a type by name+arity in a type_defs list, handling all udt shapes:
  #   {:user_type, :name}              — plain translated type
  #   {:user_type, {name, []}}         — zero-param parsed type
  #   {:user_type, {name, [params]}}   — parameterised parsed type
  defp find_type(nil, _def_type, _elements), do: nil
  defp find_type(type_defs, def_type, elements) do
    arity = length(elements)
    Enum.find_value(type_defs, fn {udt, dt} ->
      case udt do
        {:user_type, {udt_type, udt_elements}} when is_list(udt_elements) ->
          if udt_type == def_type and length(udt_elements) == arity, do: dt, else: nil
        {:user_type, udt_type} ->
          if udt_type == def_type and arity == 0, do: dt, else: nil
        _ ->
          nil
      end
    end)
  end

  # Tries direct key lookup first, then suffix match for unqualified names
  defp resolve_module(module_str, whole_type_definition) do
    case Map.get(whole_type_definition, module_str) do
      nil ->
        suffix = ".#{module_str}"
        Enum.find_value(whole_type_definition, fn {key, type_defs} ->
          if String.ends_with?(key, suffix), do: type_defs, else: nil
        end)
      type_defs ->
        type_defs
    end
  end

  defp saturate_replacement(current_translated_types, full_type_definition, replacing_definition) do
    # One-time diagnostic — remove after confirming
    IO.inspect(Map.keys(full_type_definition), label: "full_type_definition keys")

    next_translated_types =
      current_translated_types
      |> Enum.reduce(%{}, fn {module, type_defs}, acc ->
        replaced_type_defs =
          type_defs
          |> Enum.map(fn {user_defined_type, defining_type} ->
            user_defined_type =
              case user_defined_type do
                {:user_type, {_udt_type, _udt_elements}} -> user_defined_type
                {:user_type, _udt_type} -> user_defined_type
                no_user_type_tag -> {:user_type, no_user_type_tag}
              end

            {user_defined_type,
            {{[user_defined_type], defining_type}, type_defs, full_type_definition}
            |> replacing_definition.(replacing_definition)}
          end)

        acc |> Map.put(module, replaced_type_defs)
      end)

    if next_translated_types == current_translated_types do
      current_translated_types
    else
      # Pass full_type_definition unchanged — it's the complete lookup universe
      saturate_replacement(next_translated_types, full_type_definition, replacing_definition)
    end
  end
end
