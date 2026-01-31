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
  import Module.Types.Descr

  def process(path) do

    ast = path
      |> File.read!
      |> Code.string_to_quoted!

    ast
      |> extract_spec()         |> IO.inspect(label: "EXTRACT SPEC FUNCTION RESULT: \n")
      |> parse_spec()           |> IO.inspect(label: "PARSE SPEC FUNCTION RESULT: \n")
      #|> translate_spec()       |> IO.inspect(label: "TRANSLATE SPEC FUNCTION RESULT: \n")
      #|> assemble_elixir_type()
  end


  defp extract_spec(ast) do
  # Note: Patterns are matched only when tried with elixir codes written on files (not from prompt).
    spec_extractor = fn ast, name, acc, extractor ->
      case ast do
        {:defmodule, _, [{:__aliases__, _, [module_name]},[do: {:__block__, [], module_block}]]} -> (
          name = if name == "", do: "#{module_name}", else: "#{name}.#{module_name}"
          module_block |> Enum.reduce(acc, fn x, acc -> extractor.(x, name, acc, extractor) end)
        )

        {:@, [line: line_num], [{:spec, _, [{:"::", _, [{fun_name, _, inputs}, output]}]}]} -> (
          acc ++ [{line_num, "#{name}.#{fun_name}", inputs, output, nil}]
        )
        {:@, [line: line_num], [{:spec, _, [{:when, _, [{:"::", _, [{fun_name, _, inputs}, output]}, guards]}]}]} -> (
          acc ++ [{line_num, "#{name}.#{fun_name}", inputs, output, guards}]
        )

        _ -> acc
      end
    end

    ast |> spec_extractor.("", [], spec_extractor)
  end

  defp parse_spec(spec_tree) do

    parser_walker = fn type_node, walker_fun -> (
      # walker_fun/2 is used when the first level node is needed to be parsed, i.e., defined as the basic types.
      walker_fun = &walker_fun.(&1, walker_fun)
      case type_node do
        {:term, _, _} -> {:any, [], []}
        {:arity, _, _} -> {:.., [context: Elixir, imports: [{0, Kernel}, {2, Kernel}]], [0, 255]}
        # {:as_boolean, [], [type]} -> type
        {:binary, _, _} -> {:<<>>, [], [{:"::", [], [{:_, [], Elixir}, {:*, [context: Elixir, imports: [{2, Kernel}]], [{:_, [], Elixir}, 8]}]}]}
        {:nonempty_binary, _, _} -> {:<<>>, [], [{:"::", [], [{:_, [], Elixir}, 8]}, ]}
        {:bitstring, _, _} -> {:<<>>, [], [{:"::", [], [{:_, [], Elixir}, {:*, [context: Elixir, imports: [{2, Kernel}]], [{:_, [], Elixir}, 1]}]}]}
        {:nonempty_bitstring, _, _} -> {:<<>>, [], [{:"::", [], [{:_, [], Elixir}, 1]}, {:"::", [], [{:_, [], Elixir}, {:*, [context: Elixir, imports: [{2, Kernel}]], [{:_, [], Elixir}, 1]}]}]}
        {:boolean, _, _} -> {:|, [], [true, false]}
        {:byte, _, _} -> {:.., [context: Elixir, imports: [{0, Kernel}, {2, Kernel}]], [0, 255]}
        {:nonempty_list, [], [type]} -> {:nonempty_maybe_improper_list, [], [type, []]}
        {:list, [], [type]} -> {:|, [], [[], {:nonempty_list, [], [type]}]}
        {:nonempty_list, _, _} -> {:nonempty_list, [], [{:any, [], []}]} |> walker_fun.()
        # {:nonempty_improper_list, [], [type1, type2]} -> {:nonempty_maybe_improper_list, [], [type1, type2]}
        {:maybe_improper_list, [], [type1, type2]} -> {:|, [], [[], {:nonempty_maybe_improper_list, [], [{:|, [], [type1, type2]}]}]}
        {:maybe_improper_list, _, _} -> {:|, [], [[], {:nonempty_maybe_improper_list, [], [{:any, [], []}, {:any, [], []}]}]}
        {:nonempty_maybe_improper_list, _, _} -> {:nonempty_maybe_improper_list, [], [{:any, [], []}, {:any, [], []}]}
        {:char, _, _} -> {:.., [context: Elixir, imports: [{0, Kernel}, {2, Kernel}]], [0, 1114111]}
        {:charlist, _, _} -> {:list, [], [{:char, [], []}]} |> walker_fun.()
        {:nonempty_charlist, _, _} -> {:nonempty_list, [], [{:char, [], []}]} |> walker_fun.()
        {:fun, _, _} -> [{:->, [], [[{:..., [], []}], {:any, [], []}]}]
        {:function, _, _} -> [{:->, [], [[{:..., [], []}], {:any, [], []}]}]
        {:identifier, _, _} -> {:|, [], [{:pid, [context: Elixir, imports: [{1, IEx.Helpers}, {3, IEx.Helpers}]], []}, {:|, [], [{:port, [context: Elixir, imports: [{1, IEx.Helpers}, {2, IEx.Helpers}]], []}, {:reference, [], []}]}]}

        # iolist will not expand more than once since translation is to only display..., or not even once is necessary.
        {:iodata, _, _} -> {:|, [], [{:iolist, [], []}, {:binary, [], []}]}
        {:iolist, _, _} -> {:maybe_improper_list, [], [{:|, [], [{:byte, [], []}, {:|, [], [{:binary, [], []}, {:last_iolist, [], []}]}]}, {:|, [], [{:binary, [], []}, []]}]} |> walker_fun.()
        # only to mark the final recursive iolist type
        {:last_iolist, _, _} -> {:iolist, [], []}

        {:keyword, [], [type]} -> [{{:atom, [], []}, type}]
        {:keyword, _, _} -> [{{:atom, [], []}, {:any, [], []}}]
        {:mfa, _, _} -> {:{}, [], [{:module, [], []}, {:atom, [], []}, {:arity, [], []}]}
        {:module, _, _} -> {:atom, [], []}
        {:no_return, _, _} -> {:none, [], []}
        {:node, _, _} -> {:atom, [], []}
        {:number, _, _} -> {:|, [], [{:integer, [], []}, {:float, [], []}]}
        {:struct, _, _} -> {:%{}, [], [{:__struct__, {:atom, [], []}}, {{:optional, [], [{:atom, [], []}]}, {:any, [], []}}]}
        {:timeout, _, _} -> {:|, [], [:infinity, {:non_neg_integer, [], []}]}

        # true -> :true
        # false -> :false
        # nil -> :nil
        [type, {:..., [], []}] -> {:nonempty_list, [], [type |> walker_fun.()]} |> walker_fun.()
        [type] -> {:list, [], [type |> walker_fun.()]} |> walker_fun.()
        {:%{}, _, fields} -> (
          fields = fields |> Enum.map(
            fn {left, right} -> case left do
              {req_opt, _, _} when req_opt == :optional or :required -> {left, right}
              type when is_atom(type) -> {{:required, [], [left]}, right}
              _ -> {{:optional, [], [left]}, right}
            end
          end)
          {:%{}, [], fields}
        )
        {:%, _, [{_, _, module_list}, {:%{}, _, struct_list}]} -> (
          module = module_list |> Enum.reduce("", fn x, acc -> module = Atom.to_string(x)
            if acc == "", do: module, else: acc <> "." <> module end)
          {:%{}, [], [__struct__: String.to_atom(module)] ++ struct_list}
        )

        other -> other |> IO.inspect(label: "OTHER IN PARSE FUNCTION: \n")
      end)
    end

    total_parser = fn {line_num, name, inputs, output, guards} -> (

      walker = &parser_walker.(&1, parser_walker)
      macro_walker = &Macro.prewalk(&1, walker)

      inputs = inputs |> Enum.map(macro_walker)
      output = output |> macro_walker.()
      guards = if guards == nil, do: nil, else: guards |> Enum.map(fn {k, v} -> {k, v |> macro_walker.()} end)

      {line_num, name, inputs, output, guards}
    )end

    spec_tree |> Enum.map(total_parser)
  end

  defp translate_spec(parsed_spec_tree) do

    translator = fn type_node, translator_fun -> (

      translator_fun = &translator_fun.(&1, translator_fun)
      case type_node do
        # Remote module type (e.g., String.t())
        {{:., _, [{_, _, modules}, type]}, _, _} -> (
          module = modules |> Enum.reduce("", fn x, acc -> module = Atom.to_string(x)
            if acc == "", do: module, else: acc <> "." <> module end)
          :"#{module}.#{type |> translator_fun.()}()"
        )

        # Type | Type
        {:|, _, [left, right]} -> {:union, {left |> translator_fun.(), right |> translator_fun.()}}

        # {Type} (Tuple)
        {:{}, _, elements} -> {:tuple, elements |> Enum.reduce([], fn x, acc -> acc ++ (x |> translator_fun.()) end)}

        # {Tuple} (two-elements}
        {elem1, elem2} -> {:tuple, [elem1, elem2] |> Enum.reduce([], fn x, acc -> acc ++ (x |> translator_fun.()) end)}

        # %{..., F_seq} (Map)
        {:%{}, _, record_list} -> (
          record_list = record_list |> Enum.map(
            fn {left, right} -> case left do
              {:required, _, [left_type]} when is_atom(left_type) -> {left_type, right |> translator_fun.()}
              {_, _, [left_type]} -> left_type |> translator_fun.()
            end
          end)
          {:%{}, [], record_list}
        )

        {:required, _, [key_type]} -> key_type |> translator_fun.()
        {:optional, _, [key_type]} -> key_type |> translator_fun.()
        {:%{}, _, fields} -> (
          key_types = {:atom, :pid, :port, :reference, :float, :integer, :bitstring, :binary, :tuple, :open_map, :fun, :list}

          fields_merged = fields |> Enum.map(fn {k, v} ->
              key_type = k |> translator_fun.()
              val_type = v |> translator_fun.()
              evaluator = fn key_type, evaluator ->
                case key_type do
                  {:union, {left, right}} ->
                    {:union, {{left |> evaluator.(evaluator), right |> evaluator.(evaluator)}, {:if_set, val_type}}}
                  {:atom, _} ->
                    {:defined, {key_type, val_type}}
                  {type, _} ->
                    type |> evaluator.(evaluator)
                  _ ->
                    if key_type in key_types, do: {:defined, {key_type, {:if_set, val_type}}}, else: {:undefined, {key_type, {:if_set, val_type}}}
                end
              end
              key_type |> evaluator.(evaluator)
            end) |> merge_total()

          {:open_map, fields_merged}
        )

        # [] (empty list)
        [] -> :empty_list
        # [type] or [type, ...] (non-empty list)
        {:nonempty_maybe_improper_list, _, [type, []]} -> {:non_empty_list, type |> translator_fun.()}

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
        {:->, _, [:..., return]} ->
          if return |> translator_fun.() == :term, do: :fun_top, else: approximate_top_fun()

        # (Type_seq} -> Type)
        {:->, _, [arguments, return]} -> {:fun, {arguments |> translator_fun.(), return |> translator_fun.()}}

        # n..n'
        {:.., _, [digit_l, digit_r]} -> {:interval, {digit_l, digit_r}}

        # n (integer singleton types)
        digit when is_integer(digit) -> {:interval, {digit, digit}}

        # :k (atom singleton types)
        atom when is_atom(atom) -> {:atom, atom} #|> IO.inspect(label: "ATOM")

        # Simple form of basic types (any(), none(), atom(), pid(), port(), reference(), float(), integer(), neg_integer(), non_neg_integer(), pos_integer(), tuple())
        {type, _, []} -> (
          case type do
            :any -> :term
            :neg_integer -> {:interval, {:infty, -1}}
            :non_neg_integer -> {:interval, {0, :infty}}
            :pos_integer -> {:interval, {1, :infty}}
            _ -> type
          end
        )

        # Type variable
        {type, _, _} -> type

      end)
    end

    total_translator = fn {line_num, name, inputs, output, guards} -> (

      translation = &translator.(&1, translator)
      inputs = inputs |> Enum.map(translation)
      output = output |> translation.()
      guards = if guards == nil, do: nil, else: guards |> Enum.map(fn {k, v} -> Atom.to_string(k) <> ": " <> (v |> translation.()) end)

      #%TsInfo{name: name, inputs: inputs, output: output, guards: guards}
      {line_num, name, inputs, output, guards}
    )end

    parsed_spec_tree |> Enum.map(total_translator)
  end

  defp merge_total(fields) do

    # return : {:all_match, [match_list]}, {:partial_match, [match_list]}, {:no_match, []}
    comparing_types = fn {type1, type2}, comparison_fun ->
        #comparison_fun = comparison_fun.(comparison_fun)
        match_accumulator = fn comparing_list ->
          comparing_list |> Enum.reduce({:no_match, []}, fn {status, list}, {acc_status, acc_list} ->
            case {status, acc_status} do
              {:all_match, :all_match} -> {:all_match, acc_list ++ list}
              {:no_match, :no_match} -> {:no_match, []}
              _ -> {:partial_match, acc_list ++ list}
            end
          end)
        end
        case {type1, type2} do
          {{:union, left1, right1}, {:union, left2, right2}} ->
            [{left1, left2} |> comparison_fun.(), {left1, right2} |> comparison_fun.(), {right1, left2} |> comparison_fun.(), {right1, right2} |> comparison_fun.()]
              |> match_accumulator.()
          {{:union, left1, right1}, _} ->
            [{left1, type2} |> comparison_fun.(), {right1, type2} |> comparison_fun.()]
              |> match_accumulator.()
          {_, {:union, left2, right2}} ->
            [{left2, type1} |> comparison_fun.(), {right2, type1} |> comparison_fun.()]
              |> match_accumulator.()
          {:atom, {:atom, _}} -> {:partial_match, [type2]}
          {{:atom, _}, :atom} -> {:partial_match, [type1]}
          {{:supertyped, type1}, {:supertyped, type1}} -> if type1 == type2, do: {:partial_match, [type2]}, else: {:no_match, []}
          {_, {:supertyped, type1}} -> if type1 == type2, do: {:partial_match, [type2]}, else: {:no_match, []}
          {{:supertyped, type1}, _} -> if type1 == type2, do: {:partial_match, [type2]}, else: {:no_match, []}
          _ -> if type1 == type2, do: {:all_match, [type2]}, else: {:no_match, []}
        end
      end

    approximated_merging = fn {{{key_type_l1, val_type_l1}, {key_type, val_type}}, match_list} ->
        key_type = key_type |> get_lower_bound_super_key_type()
        case key_type do
          {:union, left, right} -> :not_yet
          {:supertyped, key_type} -> match_list |> Enum.reduce([], fn type -> end)
          _ -> :not_yet
        end


        # cond do
        #   key_type_l1 == key_type_super ->
        #     {{key_type_l1, val_type_l1}, :empty}
        #   key_type_l1 != key_type ->
        #     {{key_type_l1, val_type_l1}, {key_type_super, val_type}}
        #   true ->
        # end
      end

    basic_merging = fn {{key_type_l1, val_type_l1}, {key_type, val_type}} ->
        comparing_types = &comparing_types.(&1, comparing_types)
        {containment_result, match_list} = {key_type_l1, key_type} |> comparing_types.()
        case containment_result do
          :all_match -> {{key_type_l1, val_type_l1}, :empty}
          :no_match -> {{key_type_l1, val_type_l1}, {key_type, val_type}}
          :partial_match -> {{{key_type_l1, val_type_l1}, {key_type, val_type}}, match_list} |> approximated_merging.() # singleton atom and atom(), and partial unions...
        end
      end

    # Should there be a merge based on value-type?

    total_merging = fn field_with_status, L1 ->
      {L1, field_new} = L1 |> Enum.reduce({[], field_with_status}, fn field_l1, {acc_l1, {field_status, {key_type, val_type}}} ->
          # {field_l1_new, field_new} = case {key_type_l1, field_status} do
          #   {{:supertyped, _}, _} ->
          #     {key_type_l1, val_type_l1} |> approximated_merging.(field)
          #   {_, :undefined} ->
          #     {key_type_l1, val_type_l1} |> approximated_merging.(field)
          #   {_, :defined} ->
          #     {key_type_l1, val_type_l1} |> basic_merging.(field)
          #   {_, :union} ->
          #     {key_type_l1, val_type_l1} |> basic_merging.(field)
          # end


          if field_l1 == [] do
            field = {key_type |> get_lower_bound_super_key_type(), val_type}
            {[], field}
          else
            {field_l1_new, field_new} = {field_l1, {key_type, val_type}} |> basic_merging.()
            cond do
              field_l1_new == :empty ->
                {acc_l1, field_new}
              field_new == :empty ->
                {acc_l1 ++ [field_l1_new], :empty}
              true ->
                {acc_l1 ++ [field_l1_new], field_new}
            end
          end
        end)
        if field_new == :empty, do: L1, else: [field_new | L1]  # natural reverse.. but hmm..
      end

    fields |> Enum.reduce([{:empty, :empty}], fn field, L1 -> field |> total_merging.(L1) end)
  end

  defp get_lower_bound_super_key_type(type) do
    case type do
      {:union, {left, right}} -> {:union, {left |> get_lower_bound_super_key_type(), right |> get_lower_bound_super_key_type()}}
      {:tuple, _} -> {:supertyped, :tuple}
      {:open_map, _} -> {:supertyped, :open_map}
      :empty_list -> {:supertyped, :list}
      {:non_empty_list, _} -> {:supertyped, :list}
      #:bitstring -> {:supertyped, :binary}
      {:gradual, :fun_top} -> {:supertyped, :fun_top}
      {:fun, _} -> {:supertyped, :fun_top}
      {:interval, _} -> {:supertyped, :integer}
      {:atom, _} -> {:supertyped, :atom}
      _ -> type
    end
  end

  defp approximate_top_fun(), do: {:gradual, :fun_top}


  defp assemble_elixir_type(translated_spec_list) do

    type_grouping = fn type, acc ->
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
    end

    grouped_list = translated_spec_list |> Enum.reduce([], type_grouping) |> Enum.reverse()

    type_renaming = fn type_info, {prev_list, renamed} ->
      # {[...], %{}}, {} -> {{[...], %{}}, {}}
      case {type_info, prev_list, renamed} do
        {type_info, [], %{}} -> {[type_info], %{}}
        {{line_num, name, inputs, output, guards}, prev_list, renamed} -> (
          if guards == nil do
            {prev_list ++ [type_info], renamed}
          else
            {new_inputs, new_output, new_guards, new_renamed} = prev_list |> Enum.reduce({inputs, output, guards, renamed}, fn {_, _, _, _, prev_guards}, {inputs, output, guards, renamed} ->
              if guards == nil do
                {prev_list ++ [type_info], renamed}
              else
                {new_guards, {new_inputs, new_output, new_renamed}} = guards |> Enum.map_reduce({inputs, output, renamed}, fn guard, {inputs, output, renamed} ->
                  prev_guards |> Enum.reduce({guard, {inputs, output, renamed}}, fn prev_guard, {guard, {inputs, output, renamed}} ->
                    guard_list = guard|> String.split(": ")
                    prev_guard_list = prev_guard |> String.split(": ")
                    if hd(guard_list) == hd(prev_guard_list) do
                      {num, renamed} = renamed |> Map.get_and_update(hd(guard_list), fn v -> if v == nil, do: {2, 2}, else: {v+1, v+1} end)
                      new_inputs = inputs |> Enum.map(fn input -> input |> String.replace(hd(guard_list), "#{hd(guard_list)}_#{num}") end)
                      new_output = output |> String.replace(hd(guard_list), "#{hd(guard_list)}_#{num}")
                      {"#{hd(guard_list)}_#{num}: #{tl(guard_list)}", {new_inputs, new_output, renamed}}
                    else
                      {guard, {inputs, output, renamed}}
                    end
                  end)
                end)
                {new_inputs, new_output, new_guards, new_renamed}
              end
            end)
            {prev_list ++ [{line_num, name, new_inputs, new_output, new_guards}], new_renamed}
          end
        )
      end
    end
    # [[{},{}, ...], [{}, ...], ...] |> Enum.map([{}, ...] |> Enum.reduce({[...], %{}}, {} -> {{[...], %{}}, {}}))
    renamer = fn list -> elem(list |> Enum.reduce({[], %{}}, type_renaming), 0) end
    renamed_list = grouped_list |> Enum.map(renamer)

    type_assembler = fn group, acc, assembler ->
      assembler = &assembler.(&1, &2, assembler)
      case {group, acc} do
        {[], {acc_line_num, name, acc_body, acc_guard}} -> (
          full_body = if acc_guard == "", do: acc_body, else: acc_body <> " when " <> acc_guard
          {acc_line_num, name, full_body}
        )
        {[{line_num, name, inputs, output, guards} | tail], {}} -> (
          new_body = "(#{inputs |> Enum.reduce("", fn x, acc -> if acc == "", do: "#{x}", else: "#{acc}, #{x}" end)} -> #{output})"
          new_guard = if guards == nil, do: "", else: "#{guards |> Enum.reduce("", fn x, acc -> if acc == "", do: "#{x}", else: "#{acc}, #{x}" end)}"

          tail |> assembler.({[line_num], name, new_body, new_guard})
        )
        {[{line_num, name, inputs, output, guards} | tail], {acc_line_num, name, acc_body, acc_guard}} -> (
          new_body = "(#{inputs |> Enum.reduce("", fn x, acc -> if acc == "", do: "#{x}", else: "#{acc}, #{x}" end)} -> #{output})"
          new_guard = if guards == nil, do: "", else: "#{guards |> Enum.reduce("", fn x, acc -> if acc == "", do: "#{x}", else: "#{acc}, #{x}" end)}"

          new_acc_line_num = acc_line_num ++ [line_num]
          new_acc_body = acc_body <> " and " <> new_body
          new_acc_guard = if guards == nil, do: acc_guard, else: (if acc_guard == "", do: new_guard, else: acc_guard <> ", " <> new_guard)

          tail |> assembler.({new_acc_line_num, name, new_acc_body, new_acc_guard})
        )
      end
    end

    # [[{}, ...], ...] -> [{}, ...]
    assembler = &type_assembler.(&1, {}, type_assembler)
    renamed_list |> IO.inspect |> Enum.map(assembler)
  end
end



# LATER FOR STRINGIFY
# def translate_spec(parsed_spec_tree) do

#     translator = fn type_node, translator_fun -> (

#       translator_fun = &translator_fun.(&1, translator_fun)
#       case type_node do
#         # Remote module type (e.g., String.t())
#         {{:., _, [{_, _, module_list}, type]}, _, _} -> (
#           module = module_list |> Enum.reduce("", fn x, acc -> module = Atom.to_string(x)
#             if acc == "", do: module, else: acc <> "." <> module end)
#           module <> "." <> (type |> translator_fun.()) <> "()"
#         )

#         # Type | Type
#         {:|, _, [left, right]} -> (left |> translator_fun.()) <> " or " <> (right |> translator_fun.())

#         # {Type} (Tuple)
#         {:{}, _, tuple_list} -> (
#           tuple_list = tuple_list |> Enum.reduce("",
#           fn x, acc -> element = (x |> translator_fun.())
#             if acc == "", do: element, else: acc <> ", " <> element
#           end)
#           "{#{tuple_list}}"
#         )
#         # {Tuple-with-two-elements}
#         {elem1, elem2} -> (
#           tuple_list = [elem1, elem2] |> Enum.reduce("",
#           fn x, acc -> element = (x |> translator_fun.())
#             if acc == "", do: element, else: acc <> ", " <> element
#           end)
#           "{#{tuple_list}}"
#         )

#         # %{..., F_seq} (Map)
#         {:%{}, _, map_list} -> (
#           key_types = {"atom()", "pid()", "port()", "reference()", "float()", "integer()", "bitstring()", "binary()", "tuple()", "open_map()", "fun()", "list()"}

#           case map_list do
#             [{:__struct__, name} | struct_list] ->
#               struct_list = struct_list |> Enum.reduce("",
#               fn {k, v}, acc -> field = (k |> translator_fun.()) <> " => " <> (v |> translator_fun.())
#                 if acc == "", do: field, else: acc <> ", " <> field
#               end)
#               "%#{name}{#{struct_list}}"
#             _ ->
#               map_list = map_list |> Enum.map(
#               fn {k, v} ->
#                 key_type = k |> translator_fun.()
#                 val_type = v |> translator_fun.()
#                 if key_type in key_types do
#                   {:defined, key_type, val_type}
#                 else
#                   {:undefined, key_type, val_type}
#                 end
#               end)
#               map_list = approximate_spec(:field, map_list)
#               "%{#{map_list}}"
#           end
#         )
#         # APPLY translation and approximation
#         {:required, _, [type]} -> (type |> translator_fun.())
#         {:optional, _, [type]} -> (type |> translator_fun.())

#         # [] (empty list)
#         [] -> "empty_list()"
#         # [type] or [type, ...] (non-empty list)
#         {:nonempty_maybe_improper_list, _, [type, []]} -> "non_empty_list(#{type |> translator_fun.()}, empty_list())"

#         # <<_::n, _::_*n>>
#         {:<<>>, _, [{:"::", _, [_, digit1]}, {:"::", _, [_, {:*, _, [_, digit2]}]}]} -> (
#           if Integer.mod(digit1, 8) == 0 and Integer.mod(digit2, 8) == 0, do: "binary()", else: "bitstring()"
#         )
#         # <<_::_*n>>
#         {:<<>>, _, [{:"::", _, [_, {:*, _, [_, digit]}]}]} -> (
#           if Integer.mod(digit, 8) == 0, do: "binary()", else: "bitstring()"
#         )
#         # <<_::n>>
#         {:<<>>, _, [{:"::", _, [_, digit]}]} -> (
#           if Integer.mod(digit, 8) == 0, do: "binary()", else: "bitstring()"
#         )
#         # <<>>
#         {:<<>>, _, _} -> "bitstring()"

#         # (... -> Type)
#         {:->, _, [:..., right]} -> (
#           right = right |> translator_fun.()
#           if right == "term()", do: "fun()", else: approximate_spec(:top_function)
#         )
#         # (Type_seq} -> Type)
#         {:->, _, [left, right]} -> "(" <> (left |> translator_fun.()) <> " -> " <> (right |> translator_fun.()) <> ")"

#         # n..n'
#         {:.., _, [left, right]} -> left <> "--" <> right

#         # n (integer singleton types)
#         digit when is_integer(digit) -> "#{digit}--#{digit}"

#         # :k (atom singleton types)
#         atom when is_atom(atom) -> ":" <> Atom.to_string(atom) #|> IO.inspect(label: "ATOM")

#         # Simple form of basic types (any(), none(), atom(), pid(), port(), reference(), float(), integer(), neg_integer(), non_neg_integer(), pos_integer(), tuple())
#         {type, _, []} -> (
#           case type do
#             :any -> "term()"
#             :neg_integer -> "#{:infty}--#{-1}"
#             :non_neg_integer -> "#{0}--#{:infty}"
#             :pos_integer -> "#{1}--#{:infty}"
#             _ -> Atom.to_string(type) <> "()"
#           end
#         )

#         # Type variable
#         {type, _, _} -> Atom.to_string(type)

#       end)
#     end

#     total_translator = fn {line_num, name, inputs, output, guards} -> (

#       translation = &translator.(&1, translator)
#       inputs = inputs |> Enum.map(translation)
#       output = output |> translation.()
#       guards = if guards == nil, do: nil, else: guards |> Enum.map(fn {k, v} -> Atom.to_string(k) <> ": " <> (v |> translation.()) end)

#       #%TsInfo{name: name, inputs: inputs, output: output, guards: guards}
#       {line_num, name, inputs, output, guards}
#     )end

#     parsed_spec_tree |> Enum.map(total_translator)
#   end
