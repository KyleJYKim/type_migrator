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
    #|> parse_spec
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

    [{name, meta, input}, output] = spec_tree

    builtin_walker = fn type_node, walker_fun -> (
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

        other -> other
      end)
    end

    walker = &builtin_walker.(&1, builtin_walker)
    input = input |> Macro.prewalk(walker)
    output = output |> Macro.prewalk(walker)

    [{name, meta, input}, output]
  end

  def translate_spec(parsed_spec_tree) when parsed_spec_tree != :not_spec do

    [{name, _, input}, output] = parsed_spec_tree

    name = Atom.to_string(name)

    # depth first
    walker = fn
      # Since Input types could be multiple, they come as lists.
      # In the case (... -> T), it go through here.
      [head | tail], walker_fun
      -> (
        if Enum.empty?(tail),
          do: (head |> walker_fun.(walker_fun)),
          else: (head |> walker_fun.(walker_fun)) <> ", " <> (tail |> walker_fun.(walker_fun))
      )

      # Remote module type (e.g., String.t())
      {{:., [], [{_, _, [module]}, type]}, [], []}, walker_fun
      -> (
        type = type |> walker_fun.(walker_fun)
        Atom.to_string(module) <> "." <> type <> "()"
      )

      # T | T
      {:|, [], [left, right]}, walker_fun
      -> (
        left = left |> walker_fun.(walker_fun)
        right = right |> walker_fun.(walker_fun)
        left <> " or " <> right
      )

      # (\overline{T} -> T) AND (... -> T)
      {:->, [], [left, right]}, walker_fun
      -> (
        left = case left do
          [{:..., [], []}] -> "..."
          left -> left |> walker_fun.(walker_fun)
        end

        right = right |> walker_fun.(walker_fun)
        "(" <> left <> " -> " <> right <> ")"
      )


      # Simple form of basic types (any(), none(), atom(), pid(), port(), reference(), float(), integer(), neg_integer(), non_neg_integer(), pos_integer(), tuple())
      {type, [], []}, _
      -> Atom.to_string(type) <> "()"

      # Singleton types (:k)
      singleton, _ when is_atom(singleton)
      -> ":" <> Atom.to_string(singleton)
    end

    input = input |> walker.(walker)
    output = output |> walker.(walker)

    %TsInfo{name: name, input: input, output: output}
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
