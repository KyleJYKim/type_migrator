defmodule Migrator.ElixirTypeConstructor do

  alias Module.Types.Descr
  import Migrator.TypeTableHandler
  import Migrator.Translator.Utils

  @std_rmt_type_cache_file "cache/std_rmt_types.cache"
  @std_rmt_type_table :std_rmt_types

  def process(:stringify_direct, {_alias_info, translated_specs}) when is_list(translated_specs) do
    translated_specs
      |> group_by_notation      #|> Enum.map(fn x -> x |> IO.inspect(label: "\n ### GROUPBY SPEC FUNCTION RESULT \n") end)
      |> rename_type_variables  #|> Enum.map(fn x -> x |> IO.inspect(label: "\n ### RENAME SPEC FUNCTION RESULT \n") end)
      |> stringify_elixir_types   #|> Enum.map(fn x -> x |> IO.inspect(label: "\n ### STRINGIFY ELIXIR TYPE FUNCTION RESULT \n") end)
  end

  def process(:stringify_replace, {alias_info, translated_specs}, user_types) when is_list(alias_info) and is_list(translated_specs) and is_map(user_types) do
    translated_specs
      |> replace_user_types(alias_info, user_types)
      |> group_by_notation      #|> Enum.map(fn x -> x |> IO.inspect(label: "\n ### GROUPBY SPEC FUNCTION RESULT \n") end)
      |> rename_type_variables  #|> Enum.map(fn x -> x |> IO.inspect(label: "\n ### RENAME SPEC FUNCTION RESULT \n") end)
      |> stringify_elixir_types   #|> Enum.map(fn x -> x |> IO.inspect(label: "\n ### STRINGIFY ELIXIR TYPE FUNCTION RESULT \n") end)
  end

  def process(:descrize_annotation, {alias_info, translated_specs}, user_types) when is_list(alias_info) and is_list(translated_specs) and is_map(user_types) do
    translated_specs
      |> replace_user_types(alias_info, user_types)
      |> group_by_notation      #|> Enum.map(fn x -> x |> IO.inspect(label: "\n ### GROUPBY SPEC FUNCTION RESULT \n") end)
      |> replace_type_variables  #|> Enum.map(fn x -> x |> IO.inspect(label: "\n ### RENAME SPEC FUNCTION RESULT \n") end)
      |> descrize_elixir_types   #|> Enum.map(fn x -> x |> IO.inspect(label: "\n ### DESCRIZE ELIXIR TYPE FUNCTION RESULT \n") end)
  end

  def process(:descrize_assert, {alias_info, translated_specs}, user_types) when is_list(alias_info) and is_list(translated_specs) and is_map(user_types) do
    translated_specs
      |> replace_user_types(alias_info, user_types)
      |> group_by_notation      #|> Enum.map(fn x -> x |> IO.inspect(label: "\n ### GROUPBY SPEC FUNCTION RESULT \n") end)
      |> replace_type_variables  #|> Enum.map(fn x -> x |> IO.inspect(label: "\n ### RENAME SPEC FUNCTION RESULT \n") end)
      |> descrize_elixir_types_in_string   #|> Enum.map(fn x -> x |> IO.inspect(label: "\n ### DESCRIZE ELIXIR TYPE FUNCTION RESULT \n") end)
  end

  defp replace_user_types(translated_spec_list, alias_info, user_type_map) do

    replacing = fn {type, current_module_name}, replacing_fun ->
      replacing_fun = &replacing_fun.({&1, current_module_name}, replacing_fun)
      case type do
        {:union, {type_left, type_right}} ->
          {:union, {type_left |> replacing_fun.(), type_right |> replacing_fun.()}}
        {:fun, {:all_arity, type_out}} ->
          {:fun, {:all_arity, type_out |> replacing_fun.()}}
        {:fun, {types_in, type_out}} ->
          {:fun, {types_in |> Enum.map(fn type -> type |> replacing_fun.() end), type_out |> replacing_fun.()}}
        {:non_empty_list, {type_content, type_termination}} ->
          {:non_empty_list, {type_content |> replacing_fun.(), type_termination |> replacing_fun.()}}
        {:tuple, types} ->
          {:tuple, types |> Enum.map(fn type -> type |> replacing_fun.() end)}
        {:struct, {strt_name, fields}} ->
          {:struct, {strt_name, fields |> Enum.map(fn {type_left, type_right} -> {type_left |> replacing_fun.(), type_right |> replacing_fun.()} end)}}
        {:closed_map, fields} ->
          {:closed_map, fields |> Enum.map(fn {type_left, type_right} -> {type_left |> replacing_fun.(), type_right |> replacing_fun.()} end)}
        {:if_set, type} -> {:if_set, type |> replacing_fun.()}
        {:dynamic, type} -> {:dynamic, type |> replacing_fun.()}
        # {:interval, {digit1, digit2}} -> "#{digit1}..#{digit2}"
        # {:atom, nil} -> "nil"
        # {:atom, true} -> "true"
        # {:atom, false} -> "false"
        # {:atom, atom} -> ":" <> "#{atom}"
        # {:guard_var, type_var} -> "#{type_var}"
        # :... -> "..."
        {:remote_type, {{modules, user_type}, elements}} when is_list(elements) ->
          module_full = modules |> Enum.reduce("", fn module, acc -> module = Atom.to_string(module)
            if acc == "", do: module, else: acc <> "." <> module end)
          case {:__search__, user_type, elements, current_module_name <> "." <> module_full} |> replacing_fun.() do
            :__not_found__ ->
              case {:__search__, user_type, elements, module_full} |> replacing_fun.() do
                :__not_found__ ->
                  alias_module_full = alias_info |> Enum.find_value(nil, fn {aliased_name, alias_module} ->
                    if aliased_name == module_full, do: alias_module, else: nil
                  end)
                  if alias_module_full != nil do
                    case {:__search__, user_type, elements, alias_module_full} |> replacing_fun.() do
                      :__not_found__ -> {:def_not_found, {modules, user_type}}
                      definition -> definition
                    end
                  else
                    {:def_not_found, {modules, user_type}}
                  end
                definition -> definition
              end
            definition -> definition
          end
        {:remote_type, {modules, user_type}} ->
          module_full = modules |> Enum.reduce("", fn x, acc -> module = Atom.to_string(x)
            if acc == "", do: module, else: acc <> "." <> module end)
          # Search module: given module, current module + given module, and aliased module
          case {:__search__, user_type, current_module_name <> "." <> module_full} |> replacing_fun.() do
            :__not_found__ ->
              case {:__search__, user_type, module_full} |> replacing_fun.() do
                :__not_found__ ->
                  alias_module_full = alias_info |> dbg |> Enum.find_value(nil, fn {aliased_name, alias_module} ->
                    if aliased_name == module_full, do: alias_module, else: nil
                  end)
                  if alias_module_full != nil do
                    case {:__search__, user_type, alias_module_full} |> replacing_fun.() |> dbg do
                      :__not_found__ -> {:def_not_found, {modules, user_type}}
                      definition -> definition
                    end
                  else
                    {:def_not_found, {modules, user_type}}
                  end
                definition -> definition
              end
            definition -> definition
          end
        {:user_type, {user_type, elements}} when is_list(elements) ->
          case {:__search__, user_type, elements, current_module_name} |> replacing_fun.() do
            :__not_found__ -> {:def_not_found, {user_type, elements}}
            definition -> definition
          end
        {:user_type, user_type} ->
          case {:__search__, user_type, current_module_name} |> replacing_fun.() do
            :__not_found__ -> {:def_not_found, user_type}
            definition -> definition
          end
        {:__search__, user_type, elements, module_name} ->
          result =
            case Map.fetch(user_type_map, module_name) do
              :error -> lookup_type(@std_rmt_type_table, module_name)
              fetched_val -> fetched_val
            end
          case result do
            {:ok, defined_types} ->
              defined_types |> Enum.find_value(:__not_found__, fn {defined_type_from_map, definition} ->
                case defined_type_from_map do
                  {:user_type, {user_type_from_map, elements_from_map}} ->
                    if user_type_from_map == user_type and length(elements) == length(elements_from_map) do
                      Enum.zip(elements_from_map, elements) |> replace_user_type_variables(definition)
                    end
                  _ -> nil
                end
              end)
            :error -> :__not_found__
          end
        {:__search__, user_type, module_name} ->
          result =
            case Map.fetch(user_type_map, module_name) do
              :error -> lookup_type(@std_rmt_type_table, module_name)
              fetched_val -> fetched_val
            end
          case result do
            {:ok, defined_types} ->
              defined_types |> Enum.find_value(:__not_found__, fn {{:user_type, user_type_from_map}, definition} ->
                if user_type_from_map == user_type, do: definition
              end)
            :error -> :__not_found__
          end
        _ -> type
      end
    end

    translated_spec_list |> Enum.map(fn {line_num, {module_name, fun_name}, inputs, output, guards} ->

      load_cache(@std_rmt_type_cache_file)

      inputs = inputs |> Enum.map(fn input -> {input, module_name} |> replacing.(replacing)end)
      output = {output, module_name} |> replacing.(replacing)
      guards = if guards == nil, do: nil, else: guards |> Enum.map(fn {k, v} -> {k, {v, module_name} |> replacing.(replacing)} end)

      :ets.delete(@std_rmt_type_table)

      {line_num, {module_name, fun_name}, inputs, output, guards}
    end)
  end

  defp replace_user_type_variables(elements_zipped, definition) do
    #[{{:user_type_var, :data}, _definition}]
    elements_zipped |> Enum.reduce(definition, fn {{:user_type_var, user_type_var}, defined_type}, acc ->
      search_type_var = fn type_node, search_fun ->
        search_fun = &search_fun.(&1, search_fun)
        case type_node do
          {:union, {type_left, type_right}} ->
            {:union, {type_left |> search_fun.(), type_right |> search_fun.()}}
          {:fun, {:all_arity, type_out}} ->
            {:fun, {:all_arity, type_out |> search_fun.()}}
          {:fun, {types_in, type_out}} ->
            {:fun, {types_in |> Enum.map(fn type -> type |> search_fun.() end), type_out |> search_fun.()}}
          {:non_empty_list, {type_content, type_termination}} ->
            {:non_empty_list, {type_content |> search_fun.(), type_termination |> search_fun.()}}
          {:tuple, types} ->
            {:tuple, types |> Enum.map(fn type -> type |> search_fun.() end)}
          {:struct, {strt_name, fields}} ->
            {:struct, {strt_name, fields |> Enum.map(fn {type_left, type_right} -> {type_left |> search_fun.(), type_right |> search_fun.()} end)}}
          {:closed_map, fields} ->
            {:closed_map, fields |> Enum.map(fn {type_left, type_right} -> {type_left |> search_fun.(), type_right |> search_fun.()} end)}
          {:if_set, type} -> {:if_set, type |> search_fun.()}
          {:dynamic, type} -> {:dynamic, type |> search_fun.()}
          {:user_type_var, type} -> if type == user_type_var, do: defined_type, else: type_node
          _ -> type_node
        end
      end
      acc |> search_type_var.(search_type_var)
    end)
  end

  defp group_by_notation(translated_spec_list) do
    translated_spec_list |> Enum.reduce([], fn spec_info, acc ->
        {_, name, inputs, _, _} = spec_info
        {prev_name, prev_arity} = case acc do
          [] -> {"", nil}
          [head | _] ->
            {_, prev_name, prev_inputs, _, _} = hd(head)
            {prev_name, length(prev_inputs)}
        end

        if prev_name == name and prev_arity == length(inputs) do
          [head | tail] = acc
          [head ++ [spec_info]] ++ tail
        else
          [[spec_info]] ++ acc
        end
      end) |> Enum.reverse()
  end

  defp rename_type_variables(grouped_translated_spec_list) do
    grouped_translated_spec_list |> Enum.map(fn group ->
        if length(group) == 1 do
          group
        else
          group |> Enum.reduce({[],%{}}, fn {line_num, name, inputs, output, guards}, {acc_notation, found_names} ->
              if guards == nil do
                {acc_notation ++ [{line_num, name, inputs, output, guards}], found_names}
              else
                {new_guards, new_found_names} = guards |> Enum.reduce({[], found_names}, fn {name, type}, {acc_guards, acc_found_guards} ->
                    {renamed_guard, new_found_names} = acc_found_guards |> Map.get_and_update(name, fn t_lst ->
                        if t_lst == nil do
                          {{name, type}, [{type, 1}]}
                        else
                          new_num = length(t_lst) + 1
                          if t_lst |> Enum.unzip() |> elem(0) |> Enum.member?(type) do
                            {:duplicate, t_lst}
                          else
                            {{String.to_atom("#{name}_#{new_num}"), type}, t_lst ++ [{type, new_num}]}
                          end
                        end
                      end)
                    if renamed_guard == :duplicate do
                      {acc_guards, new_found_names}
                    else
                      {acc_guards ++ [renamed_guard], new_found_names}
                    end
                  end)
                renamer = fn type, renamer_fun ->
                    renamer_fun = &renamer_fun.(&1, renamer_fun)
                    case type do
                      {:guard_type_var, var} ->
                        type = guards[var]
                        idx = new_found_names[var] |> Enum.unzip() |> elem(0) |> Enum.find_index(fn t -> t == type end)
                        num = new_found_names[var] |> Enum.unzip() |> elem(1) |> Enum.at(idx)
                        if num == 1 or num == nil, do: {:guard_type_var, var}, else: {:guard_type_var, String.to_atom("#{var}_#{num}")}
                      {type1, type2} -> {type1 |> renamer_fun.(), type2 |> renamer_fun.()}
                      _ -> type
                    end
                  end
                new_inputs = inputs |> Enum.map(&renamer.(&1, renamer))
                new_output = output |> renamer.(renamer)
                {acc_notation ++ [{line_num, name, new_inputs, new_output, new_guards}], new_found_names}
              end
            end) |> elem(0)
        end
      end)
  end

  defp stringify_elixir_types(renamed_grouped_translated_spec_list) do

    placing = fn type, placing_fun ->
        placing_fun = &placing_fun.(&1, placing_fun)
          case type do
            {:union, {type_left, type_right}} ->
              "#{type_left |> placing_fun.()} or #{type_right |> placing_fun.()}"
            {:fun, {:all_arity, type_out}} ->
              "(" <> "( -> #{type_out |> placing_fun.()}) or ... or (none(), ..., none() -> #{type_out |> placing_fun.()})" <> ")"
              # 0..255 |> Stream.map(&({:fun, {List.duplicate(:none, &1), type_out}})) |> Enum.reverse()
              #        |> Enum.reduce(nil, fn t, acc -> if acc == nil, do: t, else: {:union, {t, acc}} end) |> placing_fun.()
            {:fun, {types_in, type_out}} ->
              "(" <> "#{types_in |> Enum.reduce(" ", fn t, acc -> if acc == " ", do: t |> placing_fun.(), else: acc <> ", " <> (t |> placing_fun.()) end)} -> #{type_out |> placing_fun.()}" <> ")"
            {:non_empty_list, {type_content, type_termination}} ->
              "non_empty_list(" <> "#{type_content |> placing_fun.()}, #{type_termination |> placing_fun.()}" <> ")"
            {:tuple, types} ->
              types_str = types |> Enum.reduce("", fn type, acc ->
                  type_str = "#{type |> placing_fun.()}"
                  if acc == "", do: type_str, else: acc <> ", " <> type_str
                end)
              "{" <> types_str <> "}"
            {:struct, {strt_name, fields}} ->
              fields_str = fields |> Enum.reduce("", fn {type_left, type_right}, acc ->
                  field_str = "#{type_left |> placing_fun.()}" <> " => " <> "#{type_right |> placing_fun.()}"
                  if acc == "", do: field_str, else: acc <> ", " <> field_str
                end)
              "%#{strt_name}{" <> fields_str <> "}"
            {:closed_map, [{:term, {:if_set, :term}}]} -> # the one and only open map from TypeSpecs
                "%{...}"
            {:closed_map, fields} ->
              fields_str = fields |> Enum.reduce("", fn {type_left, type_right}, acc ->
                  field_str =
                    if {type_left, type_right} == {:term, {:if_set, :term}} do
                      "..."
                    else
                      "#{type_left |> placing_fun.()}" <> " => " <> "#{type_right |> placing_fun.()}"
                    end
                  if acc == "", do: field_str, else: acc <> ", " <> field_str
                end)
              "%{" <> fields_str <> "}"
            :... -> "..."
            {:if_set, type} -> "if_set(" <> "#{type |> placing_fun.()}" <> ")"
            {:interval, {digit1, digit2}} -> "#{digit1}..#{digit2}"
            {:atom, nil} -> "nil"
            {:atom, true} -> "true"
            {:atom, false} -> "false"
            {:atom, atom} -> ":" <> "#{atom}"
            {:guard_type_var, type_var} -> "#{type_var}"
            {:user_type_var, user_type_var} -> "#{user_type_var}"
            {{:user_type_var, user_type_var}, type} -> "#{user_type_var} :: #{type |> placing_fun.()}"
            {:remote_type, {{modules, user_type}, elements}} when is_list(elements) ->
              module_full = modules |> Enum.reduce("", fn module, acc -> module = Atom.to_string(module)
                if acc == "", do: module, else: acc <> "." <> module end)
              element_full = elements |> Enum.reduce("", fn elem, acc -> elem = elem |> placing_fun.()
                if acc == "", do: elem, else: acc <> ", " <> elem end)
              "#{module_full}.#{user_type |> placing_fun.()}(#{element_full})"
            {:remote_type, {modules, user_type}} ->
              module_full = modules |> Enum.reduce("", fn x, acc -> module = Atom.to_string(x)
                if acc == "", do: module, else: acc <> "." <> module end)
              "#{module_full}.#{user_type |> placing_fun.()}"
            {:user_type, {user_type, elements}} when is_list(elements) ->
              element_full = elements |> Enum.reduce("", fn elem, acc -> elem = elem |> placing_fun.()
                if acc == "", do: elem, else: acc <> ", " <> elem end)
              "#{user_type |> placing_fun.()}(#{element_full})"
            {:user_type, user_type} ->
              "#{user_type |> placing_fun.()}"
            {:dynamic, type} -> "dynamic(" <> "#{type |> placing_fun.()}" <> ")"
            :dynamic -> "dynamic()"
            {:def_not_found, _type} -> "dynamic()"
            _ -> if type in get_basic_types(), do: "#{type}()", else: "#{type}"
          end
        end

    renamed_grouped_translated_spec_list |> Enum.map(fn group ->
        {line_nums, name, body, guard} =
          group |> Enum.reduce({[], "", "", ""}, fn {line_num, name, inputs, output, guards}, {acc_line_nums, _acc_name, acc_body, acc_guard} ->
            inputs_str = inputs |> Enum.reduce(" ", fn input, acc ->
                if acc == " ", do: input |> placing.(placing), else: acc <>  ", " <> (input |> placing.(placing))
              end)
            output_str = output |> placing.(placing)
            str_body = inputs_str <> " -> " <> output_str
            str_guard = if guards == nil, do: "", else: "#{guards |> Enum.reduce("", fn {var, type}, acc -> if acc == "", do: "#{var}: #{type |> placing.(placing)}", else: acc <> ", " <> "#{var}: #{type |> placing.(placing)}" end)}"

            new_acc_line_num = acc_line_nums ++ [line_num]
            new_acc_body = if acc_body == "", do: str_body, else: "(" <> acc_body <> ") and (" <> str_body <> ")"
            new_acc_guard = if guards == nil, do: acc_guard, else: (if acc_guard == "", do: str_guard, else: acc_guard <> ", " <> str_guard)

            {new_acc_line_num, name, new_acc_body, new_acc_guard}
          end)
        full_expression = "$ " <> (if guard == "", do: body, else: body <> " when " <> guard)
        {line_nums, name, full_expression}
      end)
  end

  defp replace_type_variables(grouped_translated_spec_list) do
    grouped_translated_spec_list |> Enum.map(fn group ->
      group |> Enum.map(fn {line_num, name, inputs, output, guards} ->
        if guards == nil do
          {line_num, name, inputs, output}
        else
          replacer = fn type, replacer_fun ->
            replacer_fun = &replacer_fun.(&1, replacer_fun)
            case type do
              {:guard_type_var, var} -> guards[var]
              {type1, type2} -> {type1 |> replacer_fun.(), type2 |> replacer_fun.()}
              _ -> type
            end
          end
          new_inputs = inputs |> Enum.map(&replacer.(&1, replacer))
          new_output = output |> replacer.(replacer)
          {line_num, name, new_inputs, new_output}
        end
      end)
    end)
  end

  defp descrize_elixir_types(renamed_grouped_translated_spec_list) do

    descrizing = fn type, descrizing_fun ->
        descrizing_fun = &descrizing_fun.(&1, descrizing_fun)
          case type do
            {:union, {type_left, type_right}} ->
              Descr.union(type_left |> descrizing_fun.(), type_right |> descrizing_fun.())
            {:fun, {:all_arity, type_out}} ->
              0..255 |> Stream.map(&({:fun, {List.duplicate(:none, &1), type_out}})) |> Enum.reverse()
                     |> Enum.reduce(nil, fn t, acc -> if acc == nil, do: t, else: {:union, {t, acc}} end) |> descrizing_fun.()
            {:fun, {types_in, type_out}} ->
              Descr.fun(types_in |> Enum.map(descrizing_fun), type_out |> descrizing_fun.())
            {:non_empty_list, {type_content, type_termination}} ->
              Descr.non_empty_list(type_content |> descrizing_fun.(), type_termination |> descrizing_fun.())
            {:tuple, types} ->
              Descr.tuple(types |> Enum.map(descrizing_fun))
            {:struct, {:__struct_top__, _fields}} ->
              Descr.closed_map([{:__struct__, Descr.atom()}, {Descr.atom() |> Descr.to_domain_keys(), {:if_set, :term} |> descrizing_fun.()}])
            {:struct, {strt_name, fields}} ->
              fields_descr = fields |> Enum.map(fn {{:atom, atom}, type_right} ->
                  {atom, type_right |> descrizing_fun.()}
                end)
              Descr.closed_map([__struct__: Descr.atom([strt_name])] ++ fields_descr)
            {:closed_map, [{:term, {:if_set, :term}}]} -> # the one and only open map from TypeSpecs
              Descr.open_map()
            {:closed_map, fields} ->
              fields_descr = fields |> Enum.map(fn {type_left, type_right} ->
                case type_left do
                  {:atom, atom} -> {atom, type_right |> descrizing_fun.()}
                  _ ->  {type_left |> descrizing_fun.() |> Descr.to_domain_keys(), type_right |> descrizing_fun.()}
                end
              end)
              Descr.closed_map(fields_descr)
            :... -> "..."
            {:if_set, type} -> Descr.if_set(type |> descrizing_fun.())
            {:interval, {_digit1, _digit2}} -> Descr.dynamic(Descr.integer())
            {:atom, nil} -> Descr.atom([:nil])
            {:atom, true} -> Descr.atom([:true])
            {:atom, false} -> Descr.atom([:false])
            {:atom, atom} -> Descr.atom([atom])
            # {:guard_type_var, type_var} -> NOT DEFINED IN DESCR

            :none -> Descr.none()
            :term -> Descr.term()

            :pid -> Descr.pid()
            :port -> Descr.port()
            :reference -> Descr.reference()
            :integer -> Descr.integer()
            :float -> Descr.float()
            :atom -> Descr.atom()
            :binary -> Descr.binary()
            :bitstring -> Descr.bitstring_no_binary()
            :empty_list -> Descr.empty_list()
            :tuple -> Descr.tuple()
            :open_map -> Descr.open_map()
            :fun -> Descr.fun()
            :list -> Descr.list(:term)

            # def empty_map(), do: %{map: @map_empty}
            # def list(type), do: list_descr(type, @empty_list, true)

            {:dynamic, type} -> Descr.dynamic(type |> descrizing_fun.())
            :dynamic -> Descr.dynamic()
            {:def_not_found, _type} -> Descr.dynamic()

            _ -> Descr.dynamic()
          end
        end

    renamed_grouped_translated_spec_list |> Enum.map(fn group ->
      group |> Enum.reduce({[], nil, nil}, fn {line_num, name, inputs, output}, {acc_line_nums, _acc_name, acc_body} ->
        inputs_descr = inputs |> Enum.map(fn input -> input |> descrizing.(descrizing) end)
        output_descr = output |> descrizing.(descrizing)
        body_descr = Descr.fun(inputs_descr, output_descr)

        new_acc_line_num = acc_line_nums ++ [line_num]
        new_acc_body = if acc_body == nil, do: body_descr, else: Descr.intersection(acc_body, body_descr)

        {new_acc_line_num, name, new_acc_body}
      end)
    end)
  end


  defp descrize_elixir_types_in_string(renamed_grouped_translated_spec_list) do

    descrizing = fn type, descrizing_fun ->
        descrizing_fun = &descrizing_fun.(&1, descrizing_fun)
          case type do
            {:union, {type_left, type_right}} ->
              type_l = type_left |> descrizing_fun.()
              type_r = type_right |> descrizing_fun.()
              "#{type_l} or #{type_r}"
            {:fun, {:all_arity, type_out}} ->
              0..255 |> Stream.map(&({:fun, {List.duplicate(:none, &1), type_out}})) |> Enum.reverse()
                     |> Enum.reduce(nil, fn t, acc -> if acc == nil, do: t, else: {:union, {t, acc}} end) |> descrizing_fun.()
            {:fun, {types_in, type_out}} ->
              types_i = types_in |> Enum.reduce("", fn type_in, acc ->
                if acc == "", do: "#{type_in |> descrizing_fun.()}", else: acc <> ", " <> "#{type_in |> descrizing_fun.()}"
              end)
              type_o = type_out |> descrizing_fun.()
              "(#{types_i} -> #{type_o})"
            {:non_empty_list, {type_content, type_termination}} ->
              type_c = type_content |> descrizing_fun.()
              type_t = type_termination |> descrizing_fun.()
              "non_empty_list(#{type_c}, #{type_t})"
            {:tuple, types} ->
              types = types |> Enum.reduce("", fn type, acc ->
                if acc == "", do: "#{type |> descrizing_fun.()}", else: acc <> ", " <> "#{type |> descrizing_fun.()}"
              end)
              "{#{types}}"  #"tuple([#{types}])"
            {:struct, {:__struct_top__, _fields}} ->
              fields = "atom() => if_set(term()), :__struct__ => atom()"
              "%{#{fields}}"
            {:struct, {strt_name, fields}} ->
              fields_descr = fields |> Enum.reduce("", fn {{:atom, atom}, type_right}, acc ->
                  if acc == "", do: ":#{atom} => #{type_right |> descrizing_fun.()}", else: acc <> ", " <>  ":#{atom} => #{type_right |> descrizing_fun.()}"
                  # if acc == "", do: "{:#{atom}, #{type_right |> descrizing_fun.()}}", else: acc <> ", " <>  "{:#{atom}, #{type_right |> descrizing_fun.()}}"
                end)
              fields = "#{fields_descr}, :__struct__ => :#{strt_name}"
              "%{#{fields}}"  # "closed_map([#{fields}])"
            {:closed_map, fields} ->
              fields = fields |> Enum.reverse() |> Enum.reduce("", fn {type_left, type_right}, acc ->
                field = case type_left do
                  {:atom, atom} -> ":#{atom} => #{type_right |> descrizing_fun.()}"
                  _ ->  "#{type_left |> descrizing_fun.()} => #{type_right |> descrizing_fun.()}"
                  # _ ->  "{to_domain_keys(#{type_left |> descrizing_fun.()}), #{type_right |> descrizing_fun.()}}"
                end
                if acc == "", do: field, else: acc <> ", " <> field
              end)
              "%{#{fields}}"  # "closed_map([#{fields}])"
            :... -> "..."
            {:if_set, type} -> "if_set(#{type |> descrizing_fun.()})"
            # {:interval, {_digit1, _digit2}} -> "dynamic(integer())"
            {:interval, {_digit1, _digit2}} -> "integer()"
            # {:atom, nil} -> "atom([:nil])"
            # {:atom, true} -> "atom([:true])"
            # {:atom, false} -> "atom([:false])"
            # {:atom, atom} -> "atom([:#{atom}])"
            {:atom, nil} -> ":nil"
            {:atom, true} -> ":true"
            {:atom, false} -> ":false"
            {:atom, atom} -> ":#{atom}"
            # {:guard_type_var, type_var} -> NOT DEFINED IN DESCR

            :none -> "none()"
            :term -> "term()"

            :pid -> "pid()"
            :port -> "port()"
            :reference -> "reference()"
            :integer -> "integer()"
            :float -> "float()"
            :atom -> "atom()"
            :binary -> "binary()"
            :bitstring -> "bitstring_no_binary()"
            :empty_list -> "empty_list()"
            :tuple -> "tuple()"
            :open_map -> "%{...}" # "open_map()"
            :fun -> "fun()"
            :list -> "list(:term)"

            # def empty_map(), do: %{map: @map_empty}
            # def list(type), do: list_descr(type, @empty_list, true)

            # {:dynamic, _type} -> "term()"
            # :dynamic -> "term()"
            # {:def_not_found, _type} -> "term()"

            # _ -> "term()"

            # Right now dynamic is not implemented for @assert_type - 20 March 2026
            {:dynamic, type} -> "dynamic(#{type |> descrizing_fun.()})"
            :dynamic -> "dynamic()"
            {:def_not_found, _type} -> "dynamic()"

            _ -> "dynamic()"
          end
        end

    renamed_grouped_translated_spec_list |> Enum.map(fn group ->
      group |> Enum.reduce({[], nil, nil}, fn {line_num, name, inputs, output}, {acc_line_nums, _acc_name, acc_body} ->
        inputs_descr = inputs |> Enum.reduce("", fn input, acc -> if acc == "", do: input |> descrizing.(descrizing), else: acc <> ", " <> descrizing.(input, descrizing) end)
        output_descr = output |> descrizing.(descrizing)
        body_descr = "(#{inputs_descr} -> #{output_descr})"

        new_acc_line_num = acc_line_nums ++ [line_num]
        new_acc_body = if acc_body == nil, do: body_descr, else: "#{acc_body} and #{body_descr}"

        {new_acc_line_num, name, new_acc_body}
      end)
    end)
  end
end
