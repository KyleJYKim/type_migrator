defmodule Migrator.Translator do
  @moduledoc """
  Input: a file path of elixir code with TypeSpecs
  Output: a list of Elixir Types (in strings, to be decided)

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
  alias Migrator.Approximator, as: Approx
  import Module.Types.Descr

  #def process(path, %{quoted: print_quoted?, translated: print_translated?, assembled: print_assembled?}\\ {true, true, true}) do
  def process(path) do
    quoted = path
      |> File.read!
      |> Code.string_to_quoted!

    IO.puts("QUOTED: \n")
    quoted |> IO.inspect()

    translated = quoted
      |> extract_spec()         #|> IO.inspect(label: "### EXTRACT SPEC FUNCTION RESULT \n")
      |> parse_spec()           |> Enum.map(fn x -> x |> IO.inspect(label: "\n ### PARSE SPEC FUNCTION RESULT \n") end)
      |> translate_spec()       #|> Enum.map(fn x -> x |> IO.inspect(label: "\n ### TRANSLATE SPEC FUNCTION RESULT \n") end)

    IO.puts("TRANSLATED: \n")
    translated |> Enum.map(fn x -> x |> IO.inspect() end)

    assembled = translated
      |> group_by_notation
      |> rename_type_variables
      |> assemble_elixir_type() #|> Enum.map(fn x -> x |> IO.inspect(label: "\n ### ASSEMBLE SPEC FUNCTION RESULT \n") end)

    IO.puts("ASSEMBLED: \n")
    assembled |> Enum.map(fn x -> x |> IO.inspect() end)  # document it.
  end


  defp extract_spec(ast) do
  # Note: Patterns are matched only when tried with elixir codes written on files (not from prompt).
    spec_extractor = fn ast, name, acc, extractor ->
      case ast do
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

    parser = fn type_node, parser_fun ->
      parser_fun = &parser_fun.(&1, parser_fun)
      case type_node do
        {_, _, nil} -> type_node # Type Variables
        {:|, _, [type1, type2]} -> {:|, [], [type1, type2] |> Enum.map(parser_fun)}
        {:term, _, _} -> {:any, [], []}
        {:arity, _, _} -> {:.., [], [0, 255]}
        # {:as_boolean, [], [type]} -> type
        {:binary, _, _} -> {:<<>>, [], [{:"::", [], [{:_, [], Elixir}, {:*, [], [{:_, [], Elixir}, 8]}]}]}
        {:nonempty_binary, _, _} -> {:<<>>, [], [{:"::", [], [{:_, [], Elixir}, 8]}]}
        {:bitstring, _, _} -> {:<<>>, [], [{:"::", [], [{:_, [], Elixir}, {:*, [], [{:_, [], Elixir}, 1]}]}]}
        {:nonempty_bitstring, _, _} -> {:<<>>, [], [{:"::", [], [{:_, [], Elixir}, 1]}, {:"::", [], [{:_, [], Elixir}, {:*, [], [{:_, [], Elixir}, 1]}]}]}
        {:boolean, _, _} -> {:|, [], [true, false]}
        {:byte, _, _} -> {:.., [], [0, 255]}
        {:list, _, []} -> {:|, [], [[], {:nonempty_maybe_improper_list, [], [{:any, [], []}, []]}]}
        {:list, _, [type]} -> {:|, [], [[], {:nonempty_maybe_improper_list, [], [type |> parser_fun.(), []]}]}
        {:nonempty_list, _, []} -> {:nonempty_maybe_improper_list, [], [{:any, [], []}, []]}
        {:nonempty_list, _, [type]} -> {:nonempty_maybe_improper_list, [], [type |> parser_fun.(), []]}
        # {:nonempty_improper_list, [], [type1, type2]} -> {:nonempty_maybe_improper_list, [], [type1, type2]}
        {:maybe_improper_list, _, []} -> {:|, [], [[], {:nonempty_maybe_improper_list, [], [{:any, [], []}, {:any, [], []}]}]}
        {:maybe_improper_list, _, [type1, type2]} -> {:|, [], [[], {:nonempty_maybe_improper_list, [], [{:|, [], [type1, type2] |> Enum.map(parser_fun)}]}]}
        {:nonempty_maybe_improper_list, _, []} -> {:nonempty_maybe_improper_list, [], [{:any, [], []}, {:any, [], []}]}
        {:nonempty_maybe_improper_list, _, [type1, type2]} -> {:nonempty_maybe_improper_list, [], [type1, type2] |> Enum.map(parser_fun)}
        {:char, _, _} -> {:.., [], [0, 1114111]}
        {:charlist, _, _} -> {:list, [], [{:char, [], []}]} |> parser_fun.()
        {:nonempty_charlist, _, _} -> {:nonempty_list, [], [{:char, [], []}]} |> parser_fun.()
        {:fun, _, _} -> {:->, [], [[{:..., [], []}], {:any, [], []}]} |> IO.inspect(label: "Optional Value")
        {:function, _, _} -> {:fun, [], []} |> parser_fun.()
        {:identifier, _, _} -> {:|, [], [{:pid, [], []}, {:|, [], [{:port, [], []}, {:reference, [], []}]}]}

        # iolist will not expand more than once since translation is to only display..., or not even once is necessary.
        {:iodata, _, _} -> {:|, [], [{:iolist, [], []}, {:binary, [], []}]}
        {:iolist, _, _} -> {:maybe_improper_list, [], [{:|, [], [{:byte, [], []}, {:|, [], [{:binary, [], []}, {:last_iolist, [], []}]}]}, {:|, [], [{:binary, [], []}, []]}]} |> parser_fun.()
        # only to mark the final recursive iolist type
        {:last_iolist, _, _} -> {:iolist, [], []}

        {:keyword, _, [type]} -> [{{:atom, [], []}, type |> parser_fun.()}] |> parser_fun.()
        {:keyword, _, _} -> [{{:atom, [], []}, {:any, [], []}}] |> parser_fun.()
        {:mfa, _, _} -> {:{}, [], [{:atom, [], []}, {:atom, [], []}, {:arity, [], []}]}
        {:module, _, _} -> {:atom, [], []}
        {:no_return, _, _} -> {:none, [], []}
        {:node, _, _} -> {:atom, [], []}
        {:number, _, _} -> {:|, [], [{:integer, [], []}, {:float, [], []}]}
        {:struct, _, _} -> {:%, [], [{:struct, [], [:__struct_top__]}, {:%{}, [], [{:__struct__, {:atom, [], []}}, {{:optional, [], [{:atom, [], []}]}, {:any, [], []}}]}]} |> parser_fun.()
        {:timeout, _, _} -> {:|, [], [:infinity, {:non_neg_integer, [], []}]}
        # true -> :true
        # false -> :false
        # nil -> :nil

        [{:->, _, [types_in, type_out]}] -> {:->, [], [types_in |> Enum.map(parser_fun), type_out |> parser_fun.()]}
        [type, {:..., _, _}] -> {:nonempty_list, [], [type]} |> parser_fun.()
        [type] -> {:list, [], [type]} |> parser_fun.()

        {:map, _, _} -> {:%{}, [], [{{:optional, [], [{:any, [], []}]}, {:any, [], []}}]}
        {:%{}, _, fields} -> (
          fields = fields |> Enum.map(fn {left, right} ->
            right = right |> parser_fun.()
            case left do
              {:required, _, [type]} -> {{:required, [], [type |> parser_fun.()]}, right}
              {:optional, _, [type]} -> {{:optional, [], [type |> parser_fun.()]}, right}
              type -> if is_atom(type), do: {{:required, [], [type]}, right}, else: {{:optional, [], [type |> parser_fun.()]}, right}
            end
          end)
          {:%{}, [], fields}
        )
        {:%, _, [{_, _, modules}, {:%{}, _, fields}]} -> (
          strt_name = modules |> Enum.reduce("", fn m, acc -> if acc == "", do: "#{m}", else: "#{acc}.#{m}" end) |> String.to_atom()
          {:%{}, [], fields} = {:%{}, [], fields} |> parser_fun.()
          {:%{}, [], [__struct__: strt_name] ++ fields}
        )

        {type1, type2} -> {type1 |> parser_fun.(), type2 |> parser_fun.()}

        {type, _, [type | rest]} -> {type, [], [type | rest] |> Enum.map(parser_fun)} |> IO.inspect(label: "UNKNOWN TYPE IN PARSE FUNCTION: U GOTTA LOOK IT UP")
        other -> other |> IO.inspect(label: "OTHER IN PARSE FUNCTION")
      end
    end

    total_parser = fn {line_num, name, inputs, output, guards} -> (

      # walker = &parser_walker.(&1, parser_walker)
      # macro_walker = &Macro.prewalk(&1, walker)
      parsing = &parser.(&1, parser)
      inputs = inputs |> Enum.map(parsing)
      output = output |> parsing.()
      guards = if guards == nil, do: nil, else: guards |> Enum.map(fn {k, v} -> {k, v |> parsing.()} end)

      {line_num, name, inputs, output, guards}
    )end

    spec_tree |> Enum.map(total_parser)
  end

  defp translate_spec(parsed_spec_tree) do

    translator = fn {type_node, guards}, translator_fun -> (
      translator_fun = &translator_fun.({&1, guards}, translator_fun)
      case type_node |> IO.inspect(label: "Type_node in Translation") do
        # Remote module type (e.g., String.t())
        {{:., _, [{_, _, modules}, type]}, _, _} -> (
          module = modules |> Enum.reduce("", fn x, acc -> module = Atom.to_string(x)
            if acc == "", do: module, else: acc <> "." <> module end)
          :"#{module}.#{type |> translator_fun.()}()"
        )

        # Type | Type
        {:|, _, [left, right]} -> {:union, {left |> translator_fun.(), right |> translator_fun.()}}

        # {Type} (Tuple)
        {:{}, _, elements} -> {:tuple, elements |> Enum.reduce([], fn elem, acc -> acc ++ [elem |> translator_fun.()] end)} |> IO.inspect(label: "TUPLE INSPECT1")

        # {Tuple} (two-elements}
        {elem1, elem2} -> {:tuple, [elem1, elem2] |> Enum.reduce([], fn elem, acc -> acc ++ [elem |> translator_fun.()|> IO.inspect(label: "TUPLE ELEM INSPECT2")] end)} |> IO.inspect(label: "TUPLE INSPECT2")

        # %{..., F_seq} (Map)
        {:%{}, _, fields} -> (
          flatten = fn type, flatten_fun ->
              flatten_fun = &flatten_fun.(&1, flatten_fun)
              case type do
                {:|, _, [type_l, type_r]} -> ([type_l |> flatten_fun.()] ++ [type_r |> flatten_fun.()]) |> Enum.flat_map(fn x -> x end)
                _ -> [type |> translator_fun.()]
              end
            end
          field_translator = fn {{req_or_opt, _, [left]}, right} ->
              # [Union of F_i] to [F_1, ..., F_n]
              if req_or_opt == :required and is_atom(left) do
                [{{:atom_req, left}, right |> flatten.(flatten)}]
              else
                left |> flatten.(flatten) |> Enum.map(fn l ->
                    case l do
                      {:atom, singleton} -> {{:atom_opt, singleton}, right |> flatten.(flatten)}
                      _ -> {l, right |> flatten.(flatten)}
                    end
                  end)
              end
            end
          case fields do
            [{:__struct__, strt_name} | fields] ->
              new_fields = fields |> IO.inspect(label: "STRUCT FIELDS") |> Enum.reduce([], fn field, acc_fields ->
                acc_fields ++ (field |> field_translator.() |> Approx.promote()) end) |> Approx.map()
              {:struct, {strt_name, new_fields}}
            _ ->
              new_fields = fields |> Enum.reduce([], fn field, acc_fields ->
                  acc_fields ++ (field |> field_translator.() |> Approx.promote()) end) |> Approx.map()
              {:open_map, new_fields}
          end
        )

        # [] (empty list)
        [] -> :empty_list
        # [type] or [type, ...] (non-empty list)
        # {:nonempty_maybe_improper_list, _, [type, []]} -> {:non_empty_list, {type |> translator_fun.(), :empty_list}}
        # [type1 | type2] (non-empty list)
        {:nonempty_maybe_improper_list, _, [type1, type2]} -> {:non_empty_list, {type1 |> translator_fun.(), type2 |> translator_fun.()}}

        # <<_::n, _::_*n>>
        {:<<>>, _, [{:"::", _, [_, digit1]}, {:"::", _, [_, {:*, _, [_, digit2]}]}]} ->
          if Integer.mod(digit1, 8) == 0 and Integer.mod(digit2, 8) == 0, do: :binary, else: :bitstring

        # <<_::_*n>>
        {:<<>>, _, [{:"::", _, [_, {:*, _, [_, digit]}]}]} ->
          if Integer.mod(digit, 8) == 0, do: :binary, else: :bitstring

        # <<_::n>>
        {:<<>>, _, [{:"::", _, [_, digit]}]} ->
          if Integer.mod(digit, 8) == 0, do: :binary, else: :bitstring

        # <<>>
        {:<<>>, _, _} -> :bitstring

        # (... -> Type)
        {:->, [], [[{:..., _, []}], type_out]} ->
          if (type_out |> translator_fun.()) == :term do
            :fun
          else # Approx.: {:gradual, :fun}
            # 0..255 |> Range.to_list()
            #   |> Enum.reduce([], fn n, acc -> [{:fun, {List.duplicate(:none, n), type_out |> translator_fun.()}} | acc] end)
            #   |> Enum.reduce(nil, fn t, acc -> if acc == nil, do: t, else: {:union, {t, acc}} end)
            {:fun, {:all_arity, type_out |> translator_fun.()}}
            # 0..255 |> Stream.map(&({:fun, {List.duplicate(:none, &1), type_out |> translator_fun.()}}))
          end
        # (Type_seq} -> Type)
        {:->, _, [types_in, type_out]} -> {:fun, {types_in |> Enum.map(translator_fun), type_out |> translator_fun.()}}

        # n..n'
        {:.., _, [{:-, _, [digit_l]}, {:-, _, [digit_r]}]} -> {:interval, {-digit_l, -digit_r}}
        # {:.., _, [digit_l, {:-, _, [digit_r]}]} -> {:interval, {digit_l, -digit_r}}
        {:.., _, [{:-, _, [digit_l]}, digit_r]} -> {:interval, {-digit_l, digit_r}}
        {:.., _, [digit_l, digit_r]} -> {:interval, {digit_l, digit_r}}

        # n (integer singleton types)
        digit when is_integer(digit) -> {:interval, {digit, digit}}

        # :k (atom singleton types)
        atom when is_atom(atom) -> {:atom, atom}

        # Simple form of basic types (any(), none(), atom(), pid(), port(), reference(), float(), integer(), neg_integer(), non_neg_integer(), pos_integer(), tuple())
        {type, _, []} ->
          case type do
            :any -> :term
            :neg_integer -> {:interval, {:infty, -1}}
            :non_neg_integer -> {:interval, {0, :infty}}
            :pos_integer -> {:interval, {1, :infty}}
            _ -> type
          end

        # Types without "()" at the end: type variables or basic types without "()".
        {type, _, nil} -> if guards[type], do: {:var, type}, else: {type, [], []} |> translator_fun.()  #|> IO.inspect(label: "TYPE VARIABLE")
        #{type, _, info} -> {type, info}
      end)
    end

    total_translator = fn {line_num, name, inputs, output, guards} -> (
      translation = &translator.(&1, translator)
      inputs = inputs |> Enum.map(fn input -> {input, guards} |> translation.() end)
      output = {output, guards} |> translation.()
      guards = if guards == nil, do: nil, else: guards |> Enum.map(fn {var, type} -> {var, {type, guards} |> translation.()} end)

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
                    # {renamed_guard, new_found_names} = acc_found_guards |> Map.get_and_update({name, type}, fn cnt -> if cnt == nil, do: {{name, type}, 1}, else: {{String.to_atom("#{name}_#{cnt+1}"), type}, cnt+1} end)
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
                      {acc_guards, new_found_names} |> IO.inspect(label: "BEFORE RENAME")
                    else
                      {acc_guards ++ [renamed_guard], new_found_names} |> IO.inspect(label: "BEFORE RENAME")
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
            _ -> "#{type}()"
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
