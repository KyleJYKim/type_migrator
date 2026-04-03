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
    "lib/ex2.ex" |> process

  """

  import Migrator.Translator.Utils

  def process(path) when is_binary(path) do
    quoted = path
      |> File.read!
      |> Code.string_to_quoted!

    quoted
      |> extract_spec()
      |> mark_type_variable()
      |> parse_spec()
      |> translate_spec()
  end

  defp extract_spec(ast) do
    # Note: Patterns are matched only when tried with elixir codes written on files (not from prompt).
    extractor = fn {ast, module_name_acc, acc}, extractor_fun ->
      extractor_fun = &extractor_fun.(&1, extractor_fun)
      case ast do
        {:defmodule, _, [{:__aliases__, _, module_name}, [do: module_ast]]} ->
          module_name_new = module_name |> Enum.reduce("", fn name, acc -> if acc == "", do: Atom.to_string(name), else: acc <> "." <> Atom.to_string(name) end)
          module_name_acc = if module_name_acc == "", do: module_name_new, else: module_name_acc <> "." <> module_name_new
          {module_ast, module_name_acc, acc} |> extractor_fun.()

        {:__block__, _, block} ->
          block |> Enum.reduce(acc, fn block_ast, acc -> {block_ast, module_name_acc, acc} |> extractor_fun.() end)

        {:@, [line: line_num], [{:spec, _, [{:"::", _, [{fun_name, _, inputs}, output]}]}]} ->
          acc ++ [{line_num, {"#{module_name_acc}", "#{fun_name}"}, inputs, output, nil}]

        {:@, [line: line_num], [{:spec, _, [{:when, _, [{:"::", _, [{fun_name, _, inputs}, output]}, guards]}]}]} ->
          acc ++ [{line_num, {"#{module_name_acc}", "#{fun_name}"}, inputs, output, guards}]

        _ -> acc
      end
    end

    {ast, "", []} |> extractor.(extractor)
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

    total_parser = fn {line_num, {module_name, fun_name}, inputs, output, guards} -> (

      inputs = inputs |> Enum.map(fn type -> type |> parse(module_name) end)
      output = output |> parse(module_name)
      guards = if guards == nil, do: nil, else: guards |> Enum.map(fn {k, v} -> {k, v |> parse(module_name)} end)

      {line_num, {module_name, fun_name}, inputs, output, guards}
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
