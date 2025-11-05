# defmodule Parser.TypespecParser do
#   @moduledoc """
#   Documentation for `Parser.TypespecParser`.
#   Input: a codebase (including TypeSpec)
#   Output: a rewritten codebase (to Elixir Type System with set-theoretic types (Descr?))

#   1. Open the target file.
#   2. Detect a TypeSpec and rewrite it
#   3. Move on to the next line and repeat the second process until the EOF.
#   """

#   def main(args) do
#     args
#     |> List.first()
#     |> convert_typespec()
#   end

#   def convert_typespec(path) do
#     #pid = CDuceRepl.spawn()  # ...what's it for?

#     try do
#       {time, result} = :timer.tc(&process/1, [path])

#       #CDuceRepl.close(pid)

#       #handle_output(result, time)
#     catch
#       {:CompileError, msg} ->
#         #CDuceRepl.close(pid)

#         IO.puts("CompileError:\n#{msg}")
#     end
#   end

#   defp process(path) do
#     path
#     |> open_code_in_string     #|> Let's put check function whether it is code or not, later.
#     |> convert_to_quoted       # transform input to AST
#     |> convert_to_elixirtype   # transform AST to ETS

#     #|> compile_expr()             # transform AST to another language
#     #|> ok_or_error()
#     #|> synthesis(env_with_stdlib(), CDuceRepl.spawn())
#   end


#   defp open_code_in_string(path) do
#     File.read!(path)
#   end

#   defp convert_to_quoted(str) do
#     """
#     It returns the AST if it succeeds, raises an exception otherwise.
#     The exception is a TokenMissingError in case a token is missing
#     (usually because the expression is incomplete),
#     MismatchedDelimiterError (in case of mismatched opening and closing delimiters)
#     and SyntaxError otherwise.
#     """
#     Code.string_to_quoted!(str)
#   end


# """
# defmodule SpecFinder do
#   def find_specs(ast) do
#     Macro.prewalk(ast, [], fn
#       {:@, _, [{:spec, _, [spec]}]} = node, acc ->
#         {node, [spec | acc]}

#       node, acc ->
#         {node, acc}
#     end)
#     |> elem(1)
#     |> Enum.reverse()
#   end
# end

# {:ok, ast} = Code.string_to_quoted(File.read!("descr.ex"))
# IO.inspect(SpecFinder.find_specs(ast))
# """


#   defp convert_to_elixirtype(ast) do

#     """
#     iex> quote do: @spec weak_identity(integer()) :: integer()

#     {:@, [context: Elixir, imports: [{1, Kernel}]],
#      [
#        {:spec, [context: Elixir],
#         [
#           {:"::", [],
#            [{:weak_identity, [], [{:integer, [], []}]}, {:integer, [], []}]}
#         ]}
#       ]}

#     iex> quote do: @spec weak_identity(integer()) :: String.t()
#     {:@, [context: Elixir, imports: [{1, Kernel}]],
#     [
#       {:spec, [context: Elixir],
#         [
#           {:"::", [],
#           [
#             {:function_name, [], [{:integer, [], []}]},
#             {{:., [], [{:__aliases__, [alias: false], [:String]}, :t]}, [], []}
#           ]}
#         ]}
#       ]}
#     """

#     # 22/10/2025 Let's convert to typex-consumable type,
#     # i.e., function_name :: type() -> type()
#     {converted, changes} = Macro.prewalk(ast, [],
#       fn
#         {:@, _meta,
#         [{:spec, _meta,
#           [{:"::", _meta,
#             [{name, _meta,
#               [{input, _meta, _}, {output, _meta, _}]
#               }]
#             }]
#           }]
#         } -> "#{name} :: "
#       end)


#     # Macro.to_string/2
#     # The opposite of converting a string to its quoted form is Macro.to_string/2,
#     # which converts a quoted form to a string/binary representation.
#   end


# end
