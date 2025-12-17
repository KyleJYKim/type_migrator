defmodule Parser.TypespecParser do
  @moduledoc """
  Input: an elixir file with TypeSpec
  Output: a list of Ts_info structure.

  1. Open the target file.
  2. Detect a TypeSpec and take the information.
  3. Append the info. in the list.
  4. Repeat 2~3 until the end of the file.
  5. Return the list.
  """
  alias Structure.TypespecInfo, as: TsInfo

  @doc """
    # TypeSpec Info. Extraction
    # - starting line number
    # - occupying line count  (in case of multiple @spec)
    # - a clause or clauses of typespec
    # => [%Typspec_info{line_number: integer(), line_count: integer(), ast: binary()}]
  """
  #@spec process(binary()) :: TsInfo.t()
  def process(path) do
    path                        # Let's put check function whether it is code or not, later.
    |> File.read!               # => String
    |> Code.string_to_quoted!   # => AST
    |> extract_spec             # => TypeSpec info
    |> parse_spec               # => Basic types
    |> translate_spec
      # 1. Parse all TS to the form of basic, i.e., all built-in types to defined and syntactic sugar to expanded.
      # 2. Translation: depth-first. (annotation is the last)

    #|> compile_expr()             # transform AST to another language
    #|> ok_or_error()
    #|> synthesis(env_with_stdlib(), CDuceRepl.spawn())
  end

  @doc """
  Hierarchy of TypeSpec AST:
    {:@, _meta,
      [{:spec, _meta,
        [{:"::", _meta,
          [
            {:function_name, _meta, [{:input, _meta, _}]},
            {:output, _meta, _}
          ]
        }]
      }]
    }
  """
  def extract_spec(ast) do
    case ast do
      {:@, _, [{:spec, _, [{:"::", _, spec}]}]} -> spec
      _ -> :not_spec
    end
  end

  def parse_spec(spec_tree) when spec_tree != :not_spec do

    [{name, meta, inputs}, output] = spec_tree

    parser_walker = fn type_node, walker_fun -> (
      # walker_fun/2 is used when the first level node is needed to be parsed, i.e., defined as the basic types.
      walker_fun = &walker_fun.(&1, walker_fun)
      case type_node do
        {:term, [], []} -> {:any, [], []}
        {:arity, [], []} -> {:.., [context: Elixir, imports: [{0, Kernel}, {2, Kernel}]], [0, 255]}
        # {:as_boolean, [], [children]} -> children
        {:binary, [], []} -> {:<<>>, [], [{:"::", [], [{:_, [], Elixir}, {:*, [context: Elixir, imports: [{2, Kernel}]], [{:_, [], Elixir}, 8]}]}]}
        {:nonempty_binary, [], []} -> {:<<>>, [], [{:"::", [], [{:_, [], Elixir}, 8]}, ]}
        {:bitstring, [], []} -> {:<<>>, [], [{:"::", [], [{:_, [], Elixir}, {:*, [context: Elixir, imports: [{2, Kernel}]], [{:_, [], Elixir}, 1]}]}]}
        {:nonempty_bitstring, [], []} -> {:<<>>, [], [{:"::", [], [{:_, [], Elixir}, 1]}, {:"::", [], [{:_, [], Elixir}, {:*, [context: Elixir, imports: [{2, Kernel}]], [{:_, [], Elixir}, 1]}]}]}
        {:boolean, [], []} -> {:|, [], [true, false]}
        {:byte, [], []} -> {:.., [context: Elixir, imports: [{0, Kernel}, {2, Kernel}]], [0, 255]}
        {:nonempty_list, [], [type]} -> {:nonempty_maybe_improper_list, [], [type, []]}
        {:list, [], [type]} -> {:|, [], [[], {:nonempty_list, [], [type]}]}
        {:nonempty_list, [], []} -> {:nonempty_list, [], [{:any, [], []}]} |> walker_fun.()
        # {:nonempty_improper_list, [], [type1, type2]} -> {:nonempty_maybe_improper_list, [], [type1, type2]}
        {:maybe_improper_list, [], [type1, type2]} -> {:|, [], [[], {:nonempty_maybe_improper_list, [], [{:|, [], [type1, type2]}]}]}
        {:maybe_improper_list, [], []} -> {:|, [], [[], {:nonempty_maybe_improper_list, [], [{:any, [], []}, {:any, [], []}]}]}
        {:nonempty_maybe_improper_list, [], []} -> {:nonempty_maybe_improper_list, [], [{:any, [], []}, {:any, [], []}]}
        {:char, [], []} -> {:.., [context: Elixir, imports: [{0, Kernel}, {2, Kernel}]], [0, 1114111]}
        {:charlist, [], []} -> {:list, [], [{:char, [], []}]} |> walker_fun.()
        {:nonempty_charlist, [], []} -> {:nonempty_list, [], [{:char, [], []}]} |> walker_fun.()
        {:fun, [], []} -> [{:->, [], [[{:..., [], []}], {:any, [], []}]}]
        {:function, [], []} -> [{:->, [], [[{:..., [], []}], {:any, [], []}]}]
        {:identifier, [], []} -> {:|, [], [{:pid, [context: Elixir, imports: [{1, IEx.Helpers}, {3, IEx.Helpers}]], []}, {:|, [], [{:port, [context: Elixir, imports: [{1, IEx.Helpers}, {2, IEx.Helpers}]], []}, {:reference, [], []}]}]}

        # iolist will not expand more than once since translation is to only display..., or not even once is necessary.
        {:iodata, [], []} -> {:|, [], [{:iolist, [], []}, {:binary, [], []}]}
        {:iolist, [], []} -> {:maybe_improper_list, [], [{:|, [], [{:byte, [], []}, {:|, [], [{:binary, [], []}, {:last_iolist, [], []}]}]}, {:|, [], [{:binary, [], []}, []]}]} |> walker_fun.()
        # only to mark the final recursive iolist type
        {:last_iolist, [], []} -> {:iolist, [], []}

        {:keyword, [], []} -> [{{:atom, [], []}, {:any, [], []}}]
        {:keyword, [], [type]} -> [{{:atom, [], []}, type}]
        {:mfa, [], []} -> {:{}, [], [{:module, [], []}, {:atom, [], []}, {:arity, [], []}]}
        {:module, [], []} -> {:atom, [], []}
        {:no_return, [], []} -> {:none, [], []}
        {:node, [], []} -> {:atom, [], []}
        {:number, [], []} -> {:|, [], [{:integer, [], []}, {:float, [], []}]}
        {:struct, [], []} -> {:%{}, [], [{:__struct__, {:atom, [], []}}, {{:optional, [], [{:atom, [], []}]}, {:any, [], []}}]}
        {:timeout, [], []} -> {:|, [], [:infinity, {:non_neg_integer, [], []}]}


        # true -> :true
        # false -> :false
        # nil -> :nil
        [type, {:..., [], []}] -> {:nonempty_list, [], [type |> walker_fun.()]} |> walker_fun.()
        [type] -> {:list, [], [type |> walker_fun.()]} |> walker_fun.()
        {:%{}, [], record_list} -> (
          record_list = record_list |> Enum.map(
            fn {k, v} -> case k do
              {:required, _, _} -> {k, v}
              {:optional, _, _} -> {k, v}
              _ -> {{:required, [], [k]}, v}
            end
          end)
          {:%{}, [], record_list}
        )
        {:%, [], [{_, _, module_list}, {:%{}, [], struct_list}]} -> (
          module = module_list |> Enum.reduce("", fn x, acc -> module = Atom.to_string(x)
            if acc == "", do: module, else: acc <> "." <> module end)
          {:%{}, [], [__strucut__: String.to_atom(module)] ++ struct_list}
        )


        other -> other
      end)
    end

    walker = &parser_walker.(&1, parser_walker)
    macro_walker = &Macro.prewalk(&1, walker)
    inputs = inputs |> Enum.map(macro_walker)
    output = output |> macro_walker.()

    [{name, meta, inputs}, output]
  end

  def translate_spec(parsed_spec_tree) when parsed_spec_tree != :not_spec do

    [{name, _, inputs}, output] = parsed_spec_tree

    name = Atom.to_string(name)

    translator_walker = fn type_node, walker_fun -> (

      walker_fun = &walker_fun.(&1, walker_fun)
      case type_node do
        # Remote module type (e.g., String.t())
        {{:., [], [{_, _, module_list}, type]}, [], []} -> (
          module = module_list |> Enum.reduce("", fn x, acc -> module = Atom.to_string(x)
            if acc == "", do: module, else: acc <> "." <> module end)
          module <> "." <> (type |> walker_fun.()) <> "()"
        )

        # Simple form of basic types (any(), none(), atom(), pid(), port(), reference(), float(), integer(), neg_integer(), non_neg_integer(), pos_integer(), tuple())
        {type, [], []} -> (
          case type do
            :... -> "..."
            :any -> "term()"
            :neg_integer -> "#{:infty}--#{-1}"
            :non_neg_integer -> "#{0}--#{:infty}"
            :pos_integer -> "#{1}--#{:infty}"
            _ -> Atom.to_string(type) <> "()"
          end
        )

        # :k (atom singleton types)
        atom when is_atom(atom) -> ":#{atom}"

        # n (integer singleton types)
        digit when is_integer(digit) -> "#{digit}--#{digit}"

        # n..n'
        {:.., [_], [left, right]} -> left <> "--" <> right

        # Type | Type
        {:|, [], [left, right]} -> (left |> walker_fun.()) <> " or " <> (right |> walker_fun.())

        # (\overline{Type} -> Type) AND (... -> Type)
        {:->, [], [left, right]} -> "(" <> (left |> walker_fun.()) <> " -> " <> (right |> walker_fun.()) <> ")"

        # Tuple
        {:{}, [], tuple_list} -> (
          tuple_list = tuple_list |> Enum.reduce("",
          fn x, acc -> element = (x |> walker_fun.())
            if acc == "", do: element, else: acc <> ", " <> element
          end)
          "{#{tuple_list}}"
        )

        # Record
        {:%{}, [], record_list} -> (
          record_list = record_list |> Enum.reduce("",
          fn {k, v}, acc -> field = (k |> walker_fun.()) <> " => " <> (v |> walker_fun.())
            if acc == "", do: field, else: acc <> ", " <> field
          end)
          "%{#{record_list}}"
        )
        # APPLY translation and approximation
        {:required, [], [type]} -> (type |> walker_fun.())
        {:optional, [], [type]} -> (type |> walker_fun.())

        [] -> "empty_list()"
        # [type] or [type, ...] (List)
        {:nonempty_maybe_improper_list, [], [type, []]} -> "non_empty_list(#{type |> walker_fun.()}, empty_list())"


        # NEXT UP: bitstring typesss



      end)
    end

    walker = &translator_walker.(&1, translator_walker)
    inputs = inputs |> Enum.map(walker)
    output = output |> walker.()

    %TsInfo{name: name, input: inputs, output: output}
  end
  """
  {:@, _, [{:spec, _, [{:"::", _, [{name, _, input}, output]}]}]} = quote do: @spec f(integer()) :: integer()
  Simple types:
    any(), term(), dynamic(), none()
    atom(), float(), integer(),
    neg_integer(), non_neg_integer(), pos_integer()
    pid(), port(), reference()


    sample:
    alias Parser.TypespecParser, as: Ps
    ast = quote do: @spec funny_fun(term()) :: atom()
    spec = ast |> Ps.extract_spec
    spec |> Ps.analyze_spec

  """

"""
defmodule SpecFinder do
  def find_specs(ast) do
    Macro.prewalk(ast, [], fn
      {:@, _, [{:spec, _, [spec]}]} = node, acc ->
        {node, [spec | acc]}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
    |> Enum.reverse()
  end
end

{:ok, ast} = Code.string_to_quoted(File.read!("descr.ex"))
IO.inspect(SpecFinder.find_specs(ast))
"""


end
