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
    |> analyze_spec             # => List of TypespecInfo struct

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


  def analyze_spec(spec) when spec != :not_spec do

    [{name, _, input}, output] = spec

    name = Atom.to_string(name)

    walker = fn
      [head | []], walker_fun
      -> (
        (head |> walker_fun.(walker_fun))
      )

      [head | tail], walker_fun
      -> (
        (head |> walker_fun.(walker_fun)) <> ", " <> (tail |> walker_fun.(walker_fun))
      )

      {{:., [], [{_, _, [module]}, type]}, [], []}, walker_fun
      -> (
        type = type |> walker_fun.(walker_fun)
        Atom.to_string(module) <> "." <> type <> "()"
      )

      {:|, [], [left, right]}, walker_fun
      -> (
        left = left |> walker_fun.(walker_fun)
        right = right |> walker_fun.(walker_fun)
        left <> " or " <> right
      )

      {:->, [], [left, right]}, walker_fun
      -> (
        left = left |> walker_fun.(walker_fun)
        right = right |> walker_fun.(walker_fun)
        "(" <> left <> " -> " <> right <> ")"
      )

      {type, [], []}, _
      -> Atom.to_string(type) <> "()"

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
    ast = quote do: @spec fun(:a, (atom() -> integer())) :: atom() | integer() | binary()
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
