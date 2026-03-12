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

  import Migrator.Translator.Utils
  #import Module.Types.Descr

  def process(path) when is_binary(path) do
    quoted = path
      |> File.read!
      |> Code.string_to_quoted!

    quoted
      |> extract_spec()         #|> IO.inspect(label: "### EXTRACT SPEC FUNCTION RESULT \n")
      |> mark_type_variable()
      |> parse_spec()           #|> Enum.map(fn x -> x |> IO.inspect(label: "\n ### PARSE SPEC FUNCTION RESULT \n") end)
      |> translate_spec()       #|> Enum.map(fn x -> x |> IO.inspect(label: "\n ### TRANSLATE SPEC FUNCTION RESULT \n") end)
  end


  defp extract_spec(ast) do
  # Note: Patterns are matched only when tried with elixir codes written on files (not from prompt).
    spec_extractor = fn ast, module_name_acc, acc, extractor ->
      case ast do
        {:defmodule, _, [{:__aliases__, _, [module_name]}, [do: module_ast]]} ->
          module_name_acc = if module_name_acc == "", do: "#{module_name}", else: "#{module_name_acc}.#{module_name}"
          module_ast |> extractor.(module_name_acc, acc, extractor)

        {:__block__, [], block} ->
          block |> Enum.reduce(acc, fn block_ast, acc -> block_ast |> extractor.(module_name_acc, acc, extractor) end)

        # {:defmodule, _, [{:__aliases__, _, [module_name]}, [do: {:__block__, [], module_block}]]} ->
        #   name = if name == "", do: "#{module_name}", else: "#{name}.#{module_name}"
        #   module_block |> Enum.reduce(acc, fn x, acc -> extractor.(x, name, acc, extractor) end)

        {:@, [line: line_num], [{:spec, _, [{:"::", _, [{fun_name, _, inputs}, output]}]}]} ->
          acc ++ [{line_num, {"#{module_name_acc}", "#{fun_name}"}, inputs, output, nil} |> dbg]

        {:@, [line: line_num], [{:spec, _, [{:when, _, [{:"::", _, [{fun_name, _, inputs}, output]}, guards]}]}]} ->
          acc ++ [{line_num, {"#{module_name_acc}", "#{fun_name}"}, inputs, output, guards}]

        _ -> acc
      end
    end

    ast |> spec_extractor.("", [], spec_extractor)
  end

  defp mark_type_variable(spec_tree) do

    type_var_marker = fn {line_num, name, inputs, output, guards} -> (

      inputs = inputs |> Enum.map(fn input ->
        Macro.prewalk(input, fn type ->
            if guards == nil, do: type, else: guards |> Enum.reduce(type, fn {k, _v}, acc ->
              case type do
                {var_name, _, nil} -> if var_name == k, do: {var_name, [], :__guard_type_variable__}, else: acc
                _ -> acc
              end
            end)
          end)
        end)
      output = Macro.prewalk(output, fn type ->
          if guards == nil, do: type, else: guards |> Enum.reduce(type, fn {k, _v}, acc ->
            case type do
              {var_name, _, nil} -> if var_name == k, do: {var_name, [], :__guard_type_variable__}, else: acc
              _ -> acc
            end
          end)
        end)

      {line_num, name, inputs, output, guards}
    )end

    spec_tree |> Enum.map(type_var_marker)
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
end
