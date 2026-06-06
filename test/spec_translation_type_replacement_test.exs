defmodule SpecTranslationTypeReplacementTest do
  use ExUnit.Case, async: true
  doctest Migrator
  alias Migrator.SpecTranslator, as: SpecTr
  alias Migrator.TypeTranslator, as: TypeTr
  alias Migrator.ElixirTypeConstructor, as: TypeConstr

  @user_def_types "example/user-def types/"

  defp translate(path) do
    TypeConstr.process(:stringify_replace, SpecTr.process(path), TypeTr.process([path]))
  end

  defp translate(spec_path, type_path) do
    TypeConstr.process(:stringify_replace, SpecTr.process(spec_path), TypeTr.process([type_path]))
  end

  describe "Translation with Replacement of User-defined types" do
    test "Types defined in the same module " do
      assert [{_, _, "$ term() -> term()"}]
             |> match?(translate("#{@user_def_types}type_arity_zero.ex"))

      assert [{_, _, "$ term() -> term()"}]
             |> match?(translate("#{@user_def_types}type_arity_one.ex"))

      assert [{_, _, "$ integer() or float() -> integer() or float()"}]
             |> match?(translate("#{@user_def_types}type_arity_two.ex"))

      assert [
               {_, _,
                "$ t -> t when t: {atom(), binary()} or empty_list() or non_empty_list(integer() or float(), empty_list())"}
             ]
             |> match?(translate("#{@user_def_types}type_arity_three.ex"))
    end

    test "Types defined in a remote module " do
      assert [{_, _, "$ term() -> term()"}]
             |> match?(
               translate(
                 "#{@user_def_types}remote_module_type.ex",
                 "#{@user_def_types}type_arity_one.ex"
               )
             )

      assert [{_, _, "$ term() -> term()"}]
             |> match?(
               translate(
                 "#{@user_def_types}remote_module_type_alias.ex",
                 "#{@user_def_types}type_arity_one.ex"
               )
             )
    end

    # Guards normalize_map_fields/2: when a map field's key is replaced from a
    # user-defined type to an atom singleton, the field's declared optionality
    # must be preserved. A `required` key must stay required (no if_set wrapper);
    # the earlier normalize_map_fields/1 wrongly marked it optional because it
    # inferred optionality from the replaced value alone.
    test "a required map key sourced from a user-defined type stays required after replacement" do
      [{_, _, result}] = translate("#{@user_def_types}required_user_typed_key.ex")

      # :name comes from required(key_t()) — it must remain required.
      assert result =~ ":name => binary()"
      refute result =~ ":name => if_set"

      # :age is declared optional and must stay optional.
      assert result =~ ":age => if_set(integer())"
    end
  end
end
