defmodule Migrator.Translator.Utils do
  alias Migrator.Translator.Approximator, as: Approx
  require Logger

  @doc """
  Returns the branch bodies of a compile-time control-flow node
  (cond/case/if/unless), so AST walkers can descend into @spec/def
  definitions placed inside them. Returns [] for anything else.
  """
  def branch_bodies({:cond, _, [[do: clauses]]}), do: clause_bodies(clauses)
  def branch_bodies({:case, _, [_expr, [do: clauses]]}), do: clause_bodies(clauses)

  def branch_bodies({control, _, [_cond, kw]}) when control in [:if, :unless] and is_list(kw) do
    [Keyword.get(kw, :do), Keyword.get(kw, :else)] |> Enum.reject(&is_nil/1)
  end

  def branch_bodies(_), do: []

  defp clause_bodies(clauses) when is_list(clauses) do
    Enum.flat_map(clauses, fn
      {:->, _, [_head, body]} -> [body]
      _ -> []
    end)
  end

  defp clause_bodies(_), do: []

  def safe_string_to_quoted(path) do
    try do
      {:ok, path |> File.read!() |> Code.string_to_quoted!()}
    rescue
      e in SyntaxError ->
        Logger.warning("Skipping — syntax error (#{path}): #{e.description}")
        :error
      e in TokenMissingError ->
        Logger.warning("Skipping — incomplete expression (#{path}: #{e.description}")
        :error
      e in MismatchedDelimiterError ->
        Logger.warning("Skipping — mismatched delimiter (#{path}: #{e.description}")
        :error
    end
end

  def parse(type_node, current_module) do
    case type_node do
      {:"::", _, [{_user_def_type_var, _, _}, type]} ->
        type |> parse(current_module)

      {:<<>>, _, [{:"::", _, [_, _]}, {:"::", _, [_, {:*, _, [_, _]}]}]} ->
        type_node

      {:<<>>, _, [{:"::", _, [_, {:*, _, [_, _]}]}]} ->
        type_node

      {:<<>>, _, [{:"::", _, [_, _]}]} ->
        type_node

      # User-defined Type Variables (pre-described from type_translation.mark_type_variable/1)
      {_, _, :__user_type_variable__} ->
        type_node

      # Type Variables
      {_, _, :__guard_type_variable__} ->
        type_node

      # __MODULE__.type(...) — the module is the current module itself
      {{:., _, [{:__MODULE__, _, nil}, type]}, _, elements} when is_list(elements) ->
        modules = current_module |> String.split(".") |> Enum.map(&String.to_atom/1)
        {{:., [], [{:__aliases__, [], modules}, type]}, [], elements}

      # Erlang remote type:  :mod.type(...)  where the module is a bare atom.
      # Treat the erlang module as a single-segment remote so it resolves via the
      # std/remote-type cache (keyed by the erlang module name, e.g. "ets").
      {{:., _, [m, type]}, _, elements} when is_atom(m) and is_atom(type) and is_list(elements) ->
        {{:., [], [{:__aliases__, [], [m]}, type]}, [], elements}

      {{:., _, [{:__aliases__, _, modules}, type]}, _, elements}
      when is_list(elements) and elements != [] ->
        modules =
          modules
          |> Enum.map(fn module ->
            case module do
              {:__MODULE__, _, nil} -> current_module |> String.to_atom()
              other -> other
            end
          end)

        elements = elements |> Enum.map(&parse(&1, current_module))

        {{:., [], [{:__aliases__, [], modules}, type]}, [], elements}

      {{:., _, [{:__aliases__, _, modules}, type]}, _, _} ->
        modules =
          modules
          |> Enum.map(fn module ->
            case module do
              {:__MODULE__, _, nil} -> current_module |> String.to_atom()
              other -> other
            end
          end)

        {{:., [], [{:__aliases__, [], modules}, type]}, [], []}

      {:|, _, [type1, type2]} ->
        {:|, [], [type1, type2] |> Enum.map(fn type -> type |> parse(current_module) end)}

      {:term, _, param} when param == [] or param == nil ->
        {:any, [], []}

      {:arity, _, param} when param == [] or param == nil ->
        {:.., [], [0, 255]}

      {:as_boolean, _, [type]} ->
        type |> parse(current_module)

      {:binary, _, param} when param == [] or param == nil ->
        {:<<>>, [], [{:"::", [], [{:_, [], Elixir}, {:*, [], [{:_, [], Elixir}, 8]}]}]}

      {:nonempty_binary, _, param} when param == [] or param == nil ->
        {:<<>>, [], [{:"::", [], [{:_, [], Elixir}, 8]}]}

      {:bitstring, _, param} when param == [] or param == nil ->
        {:<<>>, [], [{:"::", [], [{:_, [], Elixir}, {:*, [], [{:_, [], Elixir}, 1]}]}]}

      {:nonempty_bitstring, _, param} when param == [] or param == nil ->
        {:<<>>, [],
         [
           {:"::", [], [{:_, [], Elixir}, 1]},
           {:"::", [], [{:_, [], Elixir}, {:*, [], [{:_, [], Elixir}, 1]}]}
         ]}

      {:boolean, _, param} when param == [] or param == nil ->
        {:|, [], [true, false]}

      {:byte, _, param} when param == [] or param == nil ->
        {:.., [], [0, 255]}

      {:list, _, [type]} ->
        {:|, [], [[], {:nonempty_maybe_improper_list, [], [type |> parse(current_module), []]}]}

      {:list, _, param} when param == [] or param == nil ->
        {:|, [], [[], {:nonempty_maybe_improper_list, [], [{:any, [], []}, []]}]}

      {:nonempty_list, _, [type]} ->
        {:nonempty_maybe_improper_list, [], [type |> parse(current_module), []]}

      {:nonempty_list, _, param} when param == [] or param == nil ->
        {:nonempty_maybe_improper_list, [], [{:any, [], []}, []]}

      {:nonempty_improper_list, _, [type1, type2]} ->
        {:nonempty_maybe_improper_list, [],
         [type1, type2] |> Enum.map(fn type -> type |> parse(current_module) end)}

      {:maybe_improper_list, _, [type1, type2]} ->
        {:|, [],
         [
           [],
           {:nonempty_maybe_improper_list, [],
            [type1 |> parse(current_module), type2 |> parse(current_module)]}
         ]}

      {:maybe_improper_list, _, param} when param == [] or param == nil ->
        {:|, [], [[], {:nonempty_maybe_improper_list, [], [{:any, [], []}, {:any, [], []}]}]}

      {:nonempty_maybe_improper_list, _, [type1, type2]} ->
        {:nonempty_maybe_improper_list, [],
         [type1, type2] |> Enum.map(fn type -> type |> parse(current_module) end)}

      {:nonempty_maybe_improper_list, _, param} when param == [] or param == nil ->
        {:nonempty_maybe_improper_list, [], [{:any, [], []}, {:any, [], []}]}

      {:char, _, param} when param == [] or param == nil ->
        {:.., [], [0, 1_114_111]}

      {:charlist, _, param} when param == [] or param == nil ->
        {:list, [], [{:char, [], []}]} |> parse(current_module)

      {:nonempty_charlist, _, param} when param == [] or param == nil ->
        {:nonempty_list, [], [{:char, [], []}]} |> parse(current_module)

      {:fun, _, param} when param == [] or param == nil ->
        {:->, [], [[{:..., [], []}], {:any, [], []}]}

      {:function, _, param} when param == [] or param == nil ->
        {:fun, [], []} |> parse(current_module)

      {:identifier, _, param} when param == [] or param == nil ->
        {:|, [], [{:pid, [], []}, {:|, [], [{:port, [], []}, {:reference, [], []}]}]}

      # iolist will not expand more than once since translation is to only display..., or not even once is necessary.
      {:iodata, _, param} when param == [] or param == nil ->
        {:|, [], [{:iolist, [], []}, {:binary, [], []}]}

      {:iolist, _, param} when param == [] or param == nil ->
        {:maybe_improper_list, [],
         [
           {:|, [], [{:byte, [], []}, {:|, [], [{:binary, [], []}, {:__last_iolist__, [], []}]}]},
           {:|, [], [{:binary, [], []}, []]}
         ]}
        |> parse(current_module)

      # only to mark the final recursive iolist type
      {:__last_iolist__, _, param} when param == [] or param == nil ->
        {:iolist, [], []}

      {:keyword, _, [type]} ->
        {:|, [], [[], {:nonempty_maybe_improper_list, [], [{{:atom, [], []}, type |> parse(current_module)}, []]}]}
        # [{{:atom, [], []}, }] |> parse(current_module)

      {:keyword, _, param} when param == [] or param == nil ->
        {:|, [], [[], {:nonempty_maybe_improper_list, [], [{{:atom, [], []}, {:any, [], []}}, []]}]}
        # [{{:atom, [], []}, {:any, [], []}}] |> parse(current_module)

      {:mfa, _, param} when param == [] or param == nil ->
        {:{}, [], [{:atom, [], []}, {:atom, [], []}, {:.., [], [0, 255]}]}

      {:module, _, param} when param == [] or param == nil ->
        {:atom, [], []}

      {:no_return, _, param} when param == [] or param == nil ->
        {:none, [], []}

      {:node, _, param} when param == [] or param == nil ->
        {:atom, [], []}

      {:number, _, param} when param == [] or param == nil ->
        {:|, [], [{:integer, [], []}, {:float, [], []}]}

      {:struct, _, param} when param == [] or param == nil ->
        {:%, [],
         [
           {:struct, [], [:__struct_top__]},
           {:%{}, [],
            [{:__struct__, {:atom, [], []}}, {{:optional, [], [{:atom, [], []}]}, {:any, [], []}}]}
         ]}
        |> parse(current_module)

      {:timeout, _, param} when param == [] or param == nil ->
        {:|, [], [:infinity, {:non_neg_integer, [], []}]}

      # true -> :true
      # false -> :false
      # nil -> :nil

      [{:->, _, [types_in, type_out]}] ->
        {:->, [],
         [
           types_in |> Enum.map(fn type -> type |> parse(current_module) end),
           type_out |> parse(current_module)
         ]}

      [type, {:..., _, _}] ->
        {:nonempty_list, [], [type]} |> parse(current_module)

      # keyword-list type: [k1: t1, k2: t2, ...] ≡ a (possibly empty) list whose
      # elements are the union of {:k, value} tuples. Reconstruct that union of
      # tuples and reuse the list machinery so each value is parsed/replaced.
      kw = [{first_key, _} | _] when is_atom(first_key) ->
        if Enum.all?(kw, fn
             {k, _v} -> is_atom(k)
             _ -> false
           end) do
          union_ast =
            kw
            |> Enum.reverse()
            |> Enum.reduce(nil, fn pair, acc ->
              if acc == nil, do: pair, else: {:|, [], [pair, acc]}
            end)

          {:list, [], [union_ast]} |> parse(current_module)
        else
          kw
        end

      [type] ->
        {:list, [], [type]} |> parse(current_module)

      {:map, _, param} when param == [] or param == nil ->
        {:%{}, [], [{{:optional, [], [{:any, [], []}]}, {:any, [], []}}]}

      {:%{}, _, fields} ->
        fields =
          fields
          |> Enum.map(fn field ->
            case field do
              {left, right} ->
                right = right |> parse(current_module)

                case left do
                  {:required, _, [type]} ->
                    {{:required, [], [type |> parse(current_module)]}, right}

                  {:optional, _, [type]} ->
                    {{:optional, [], [type |> parse(current_module)]}, right}

                  type ->
                    if is_atom(type),
                      do: {{:required, [], [type]}, right},
                      else: {{:optional, [], [type |> parse(current_module)]}, right}
                end

              # could be a macro like: {:unquote_splicing, _, [{:something, _, nil}]}
              _ ->
                {{:optional, [], [:dynamic]}, :dynamic}
            end
          end)

        {:%{}, [], fields}

      {:%, _, [{_, _, modules}, {:%{}, _, fields}]} ->
        strt_name =
          if modules == nil do
            current_module |> String.to_atom()
          else
            modules
            |> Enum.reduce("", fn m, acc ->
              # `%__MODULE__.Sub{}` — __MODULE__ is the enclosing module (unresolved at
              # AST level); map it to current_module rather than interpolating the tuple.
              segment =
                case m do
                  {:__MODULE__, _, _} -> current_module
                  _ -> "#{m}"
                end

              if acc == "", do: segment, else: "#{acc}.#{segment}"
            end)
            |> String.to_atom()
          end

        {:%{}, [], fields} = {:%{}, [], fields} |> parse(current_module)
        {:%{}, [], [__struct__: strt_name] ++ fields}

      {:{}, _, types} when is_list(types) ->
        {:{}, [], types |> Enum.map(fn type -> type |> parse(current_module) end)}

      {type1, type2} ->
        {type1 |> parse(current_module), type2 |> parse(current_module)}

      {type, _, elements} when is_list(elements) ->
        {type, [], elements |> Enum.map(fn type -> type |> parse(current_module) end)}

      other ->
        other
    end
  end

  def translate(type_node, type_vars \\ []) do
    translate_fun = &translate(&1, type_vars)

    case type_node do
      # Type | Type
      {:|, _, [left, right]} ->
        {:union, {left |> translate_fun.(), right |> translate_fun.()}}

      # {Type} (Tuple)
      # {:{}, _, elements} when is_list(elements) -> {:tuple, elements |> Enum.reduce([], fn elem, acc -> acc ++ [elem |> translate_fun.()] end)}
      {:{}, _, elements} when is_list(elements) ->
        {:tuple, elements |> Enum.map(translate_fun)}

      # {Tuple} (two-elements}
      # {elem1, elem2} -> {:tuple, [elem1, elem2] |> Enum.reduce([], fn elem, acc -> acc ++ [elem |> translate_fun.()] end)}
      {elem1, elem2} ->
        {:tuple, [elem1, elem2] |> Enum.map(translate_fun)}

      # %{...} (Map - open)
      {:%{}, _, [{{:optional, _, [{:any, _, _}]}, {:any, _, _}}]} ->
        :open_map

      # %{F_seq} (Map - closed)
      {:%{}, _, fields} when is_list(fields) ->
        flatten = fn type, flatten_fun ->
          flatten_fun = &flatten_fun.(&1, flatten_fun)

          case type do
            {:|, _, [type_l, type_r]} ->
              ([type_l |> flatten_fun.()] ++ [type_r |> flatten_fun.()])
              |> Enum.flat_map(fn x -> x end)

            _ ->
              [type |> translate_fun.()]
          end
        end

        field_translator = fn {{req_or_opt, _, [left]}, right} ->
          # [Union of F_i] to [F_1, ..., F_n]
          if req_or_opt == :required and is_atom(left) do
            [{{:atom_req, left}, right |> flatten.(flatten)}]
          else
            left
            |> flatten.(flatten)
            |> Enum.map(fn l ->
              case l do
                {:atom, singleton} -> {{:atom_opt, singleton}, right |> flatten.(flatten)}
                _ -> {l, right |> flatten.(flatten)}
              end
            end)
          end
        end

        case fields do
          [{:__struct__, strt_name} | fields] ->
            new_fields =
              fields
              |> Enum.reduce([], fn field, acc_fields ->
                acc_fields ++ (field |> field_translator.() |> Approx.promote())
              end)
              |> Approx.map()

            {:struct, {strt_name, new_fields}}

          _ ->
            new_fields =
              fields
              |> Enum.reduce([], fn field, acc_fields ->
                acc_fields ++ (field |> field_translator.() |> Approx.promote())
              end)
              |> Approx.map()

            {:closed_map, new_fields}
        end

      # [] (empty list)
      [] ->
        :empty_list

      # [type] or [type, ...] (non-empty list)
      # {:nonempty_maybe_improper_list, _, [type, []]} -> {:non_empty_list, {type |> translate_fun.(), :empty_list}}
      # [type1 | type2] (non-empty list)
      {:nonempty_maybe_improper_list, _, [type1, type2]} ->
        {:non_empty_list, {type1 |> translate_fun.(), type2 |> translate_fun.()}}

      # <<_::n, _::_*n>>
      {:<<>>, _, [{:"::", _, [_, digit1]}, {:"::", _, [_, {:*, _, [_, digit2]}]}]} ->
        if Integer.mod(digit1, 8) == 0 and Integer.mod(digit2, 8) == 0,
          do: :binary,
          else: :bitstring

      # <<_::_*n>>
      {:<<>>, _, [{:"::", _, [_, {:*, _, [_, digit]}]}]} ->
        if Integer.mod(digit, 8) == 0, do: :binary, else: :bitstring

      # <<_::n>>
      {:<<>>, _, [{:"::", _, [_, digit]}]} ->
        if Integer.mod(digit, 8) == 0, do: :binary, else: :bitstring

      # <<>>
      {:<<>>, _, _} ->
        :bitstring

      # (... -> Type)
      {:->, [], [[{:..., _, []}], type_out]} ->
        # Approx.: {:dynamic, :fun}
        if type_out |> translate_fun.() == :term do
          :fun
        else
          # 0..255 |> Range.to_list()
          #   |> Enum.reduce([], fn n, acc -> [{:fun, {List.duplicate(:none, n), type_out |> translate_fun.()}} | acc] end)
          #   |> Enum.reduce(nil, fn t, acc -> if acc == nil, do: t, else: {:union, {t, acc}} end)
          {:fun, {:all_arity, type_out |> translate_fun.()}}

          # 0..255 |> Stream.map(&({:fun, {List.duplicate(:none, &1), type_out |> translate_fun.()}}))
        end

      # (Type_seq} -> Type)
      {:->, _, [types_in, type_out]} ->
        {:fun, {types_in |> Enum.map(translate_fun), type_out |> translate_fun.()}}

      # n..n'
      {:.., _, [{:-, _, [digit_l]}, {:-, _, [digit_r]}]} ->
        {:interval, {-digit_l, -digit_r}}

      # {:.., _, [digit_l, {:-, _, [digit_r]}]} -> {:interval, {digit_l, -digit_r}}
      {:.., _, [{:-, _, [digit_l]}, digit_r]} ->
        {:interval, {-digit_l, digit_r}}

      {:.., _, [digit_l, digit_r]} ->
        {:interval, {digit_l, digit_r}}

      # n (integer singleton types)
      digit when is_integer(digit) ->
        {:interval, {digit, digit}}

      # :k (atom singleton types)
      atom when is_atom(atom) ->
        {:atom, atom}

      # Type variable from guard
      # {type, _, :__type_variable__} -> if type_vars[type], do: {:guard_var, type}, else: {type, [], []} |> translate_fun.()  #|> IO.inspect(label: "TYPE VARIABLE")
      {type, _, :__guard_type_variable__} ->
        {:guard_type_var, type}

      # User-defined Type variable
      {type, _, :__user_type_variable__} ->
        {:user_type_var, type}

      # var
      {:var, _, _} ->
        :dynamic

      # basic types (any(), none(), atom(), pid(), port(), reference(), float(), integer(), tuple())
      {:any, _, _} ->
        :term

      {:none, _, _} ->
        :none

      {:atom, _, _} ->
        :atom

      {:pid, _, _} ->
        :pid

      {:port, _, _} ->
        :port

      {:reference, _, _} ->
        :reference

      {:float, _, _} ->
        :float

      {:integer, _, _} ->
        :integer

      {:tuple, _, _} ->
        :tuple

      # neg_integer(), non_neg_integer(), pos_integer()
      {:neg_integer, _, _} ->
        {:interval, {:infty, -1}}

      {:non_neg_integer, _, _} ->
        {:interval, {0, :infty}}

      {:pos_integer, _, _} ->
        {:interval, {1, :infty}}

      # A named-type label (e.g. `x :: term()`) is cosmetic: only the type
      # matters. `parse/2` drops the label at the top level, but remote/user-type
      # elements reach `translate` unparsed, so we drop it here too for
      # consistency. Keeping it produced a malformed {name, type} pair that the
      # stringifier could not render.
      {:"::", _, [_named_label, type]} ->
        type |> translate_fun.()

      # Remote module type (e.g., String.t())
      {{:., _, [{:__aliases__, _, modules}, type]}, _, elements}
      when is_list(elements) and elements != [] ->
        {:remote_type,
         {{modules, type}, elements |> Enum.map(fn elem -> elem |> translate_fun.() end)}}

      {{:., _, [{:__aliases__, _, modules}, type]}, _, _} ->
        {:remote_type, {modules, type}}

      # User-defined type
      {user_type, _, elements} when is_list(elements) and elements != [] ->
        {:user_type, {user_type, elements |> Enum.map(fn elem -> elem |> translate_fun.() end)}}

      {user_type, _, _} ->
        {:user_type, user_type}

      other ->
        other
    end
  end

  def get_basic_types() do
    [
      :term,
      :none,
      :empty_list,
      :atom,
      :pid,
      :port,
      :reference,
      :float,
      :integer,
      :bitstring,
      :binary,
      :tuple,
      :open_map,
      :fun,
      :list
    ]
  end

  def flatten_from_union_to_list(type) when is_tuple(type) or is_atom(type) do
    case type do
      # Enum.flat_map(fn x -> x end)
      {:union, {type_l, type_r}} ->
        ([type_l |> flatten_from_union_to_list()] ++ [type_r |> flatten_from_union_to_list()])
        |> List.flatten()

      _ ->
        [type]
    end
  end

  def unflatten_from_list_to_union(types) when is_list(types) do
    case types do
      [type_hd | []] -> type_hd
      [type_hd | rest] -> {:union, {type_hd, rest |> unflatten_from_list_to_union()}}
    end
  end
end
