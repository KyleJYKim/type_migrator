defmodule SpectTranslationTypeReplacementTest do

  use ExUnit.Case, async: true
  doctest Migrator
  alias Migrator.SpecTranslator, as: SpecTr
  alias Migrator.TypeTranslator, as: TypeTr
  alias Migrator.ElixirTypeStringifier, as: ElixirTypeStr

  @user_def_types "example/user-def types/"

  defp translate(path) do
    path
      |> SpecTr.process
      |> ElixirTypeStr.process([path] |> TypeTr.process)
  end

  defp translate(spec_path, type_path) do
    spec_path
      |> SpecTr.process
      |> ElixirTypeStr.process([type_path] |> TypeTr.process)
  end

  describe "Translation with Replacement of User-defined types" do
    test "Types defined in the same module " do
      assert [{_, _, "$ term() -> term()"}] |> match?(translate("#{@user_def_types}type_arity_zero.ex"))
      assert [{_, _, "$ term() -> term()"}] |> match?(translate("#{@user_def_types}type_arity_one.ex"))
      assert [{_, _, "$ integer() or float() -> integer() or float()"}] |> match?(translate("#{@user_def_types}type_arity_two.ex"))
      assert [{_, _, "$ t -> t when t: {atom(), binary()} or empty_list() or non_empty_list(integer() or float(), empty_list())"}] |> match?(translate("#{@user_def_types}type_arity_three.ex"))
    end

    test "Types defined in a remote module " do
      assert [{_, _, "$ term() -> term()"}] |> match?(translate("#{@user_def_types}remote_module_type.ex", "#{@user_def_types}type_arity_one.ex"))
      assert [{_, _, "$ term() -> term()"}] |> match?(translate("#{@user_def_types}remote_module_type_alias.ex", "#{@user_def_types}type_arity_one.ex"))
    end
  end
end
