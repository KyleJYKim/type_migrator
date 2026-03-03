defmodule Migrator.SpecTranslator do
  @moduledoc """
  Input: a file path of elixir code with TypeSpecs
  Output: a list of Elixir Types (in strings)

  1. Read a file and get AST
  2. Extract TypeSpecs
  3. Parse TypeSpecs
  4. Translate TypeSpecs to Elixir Types
  5. Assemble Elixir Types

  Example in iex:
    import Migrator.Translator
    "lib/ex2.ex" |> process

  """

  # alias Structure.TypespecInfo, as: TsInfo
  import Migrator.Translator.Utils
  #import Module.Types.Descr

  #def process(path, %{quoted: print_quoted?, translated: print_translated?, assembled: print_assembled?}\\ {true, true, true}) do
  def process(path) do
    quoted = path
      |> File.read!
      |> Code.string_to_quoted!

    IO.puts("\nQUOTED \n")
    quoted |> IO.inspect()

    translated = quoted
      |> extract_spec()         #|> IO.inspect(label: "### EXTRACT SPEC FUNCTION RESULT \n")
      |> parse_spec()           |> Enum.map(fn x -> x |> IO.inspect(label: "\n ### PARSE SPEC FUNCTION RESULT \n") end)
      |> translate_spec()       |> Enum.map(fn x -> x |> IO.inspect(label: "\n ### TRANSLATE SPEC FUNCTION RESULT \n") end)

    # IO.puts("\nTRANSLATED \n")
    # translated |> Enum.map(fn x -> x |> IO.inspect() end)

    #assembled = translated
    translated
      |> group_by_notation
      |> rename_type_variables
      |> assemble_elixir_type() #|> Enum.map(fn x -> x |> IO.inspect(label: "\n ### ASSEMBLE SPEC FUNCTION RESULT \n") end)

    # IO.puts("\nASSEMBLED \n")
    # assembled |> Enum.map(fn x -> x |> IO.inspect() end)
  end


  defp extract_spec(ast) do
  # Note: Patterns are matched only when tried with elixir codes written on files (not from prompt).
    spec_extractor = fn ast, name, acc, extractor ->
      case ast |> IO.inspect(label: AST) do
        {:defmodule, _, [{:__aliases__, _, [module_name]}, [do: module_ast]]} ->
          name = if name == "", do: "#{module_name}", else: "#{name}.#{module_name}"
          module_ast |> extractor.(name, acc, extractor)

        {:__block__, [], block} ->
          block |> Enum.reduce(acc, fn block_ast, acc -> extractor.(block_ast, name, acc, extractor) end)

        # {:defmodule, _, [{:__aliases__, _, [module_name]}, [do: {:__block__, [], module_block}]]} ->
        #   name = if name == "", do: "#{module_name}", else: "#{name}.#{module_name}"
        #   module_block |> Enum.reduce(acc, fn x, acc -> extractor.(x, name, acc, extractor) end)

        {:@, [line: line_num], [{:spec, _, [{:"::", _, [{fun_name, _, inputs}, output]}]}]} ->
          acc ++ [{line_num, "#{name}.#{fun_name}", inputs, output, nil}]

        {:@, [line: line_num], [{:spec, _, [{:when, _, [{:"::", _, [{fun_name, _, inputs}, output]}, guards]}]}]} ->
          acc ++ [{line_num, "#{name}.#{fun_name}", inputs, output, guards}]

        _ -> acc
      end
    end

    ast |> spec_extractor.("", [], spec_extractor)
  end

  defp parse_spec(spec_tree) do

    total_parser = fn {line_num, name, inputs, output, guards} -> (

      inputs = inputs |> Enum.map(&parse/1)
      output = output |> parse
      guards = if guards == nil, do: nil, else: guards |> Enum.map(fn {k, v} -> {k, v |> parse} end)

      {line_num, name, inputs, output, guards}
    )end

    spec_tree |> Enum.map(total_parser)
  end

  defp translate_spec(parsed_spec_tree) do

    total_translator = fn {line_num, name, inputs, output, guards} -> (

      translation = &translate(&1, guards)
      inputs = inputs |> Enum.map(fn input -> input |> translation.() end)
      output = output |> translation.()
      guards = if guards == nil, do: nil, else: guards |> Enum.map(fn {var, type} -> {var, type |> translation.()} end)

      {line_num, name, inputs, output, guards}
    )end

    parsed_spec_tree |> Enum.map(total_translator)
  end

  defp group_by_notation(translated_spec_list) do
    translated_spec_list |> Enum.reduce([], fn type, acc ->
        {_, name, _, _, _} = type
        prev_name = case acc do
          [] -> ""
          [head | _] -> (
            {_, name, _, _, _} = hd(head)
            name
          )
        end

        if prev_name == name do
          [head | tail] = acc
          [head ++ [type]] ++ tail
        else
          [[type]] ++ acc
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
                {acc_notation, found_names}
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
                      {:var, var} ->
                        type = guards[var]
                        idx = new_found_names[var] |> Enum.unzip() |> elem(0) |> Enum.find_index(fn t -> t == type end)
                        num = new_found_names[var] |> Enum.unzip() |> elem(1) |> Enum.at(idx)
                        if num == 1 or num == nil, do: {:var, var}, else: {:var, String.to_atom("#{var}_#{num}")}
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

  defp assemble_elixir_type(renamed_grouped_translated_spec_list) do
    basic_types = [:term, :none, :empty_list, :atom, :pid, :port, :reference, :float, :integer, :bitstring, :binary, :tuple, :open_map, :fun, :list]
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
            {:open_map, fields} ->
              fields_str = fields |> Enum.reduce("", fn {type_left, type_right}, acc ->
                  field_str = "#{type_left |> placing_fun.()}" <> " => " <> "#{type_right |> placing_fun.()}"
                  if acc == "", do: field_str, else: acc <> ", " <> field_str
                end)
              "%{" <> fields_str <> "}"
            {:if_set, type} -> "if_set(" <> "#{type |> placing_fun.()}" <> ")"
            {:gradual, type} -> "dynamic(" <> "#{type |> placing_fun.()}" <> ")"
            {:interval, {digit1, digit2}} -> "#{digit1}..#{digit2}"
            {:atom, nil} -> "nil"
            {:atom, true} -> "true"
            {:atom, false} -> "false"
            {:atom, atom} -> ":" <> "#{atom}"
            {:var, type} -> "#{type}"
            :... -> "..."
            {:unknown, type} -> "#{type}"
            _ -> if type in basic_types, do: "#{type}()", else: "#{type}"
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
end
