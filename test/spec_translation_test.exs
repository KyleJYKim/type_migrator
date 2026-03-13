defmodule SpecTranslationTest do
  @moduledoc false

  use ExUnit.Case, async: true
  doctest Migrator
  alias Migrator.SpecTranslator, as: SpecTr
  alias Migrator.ElixirTypeConstructor, as: TypeConstr

  @basic_types "example/basic types/"
  @field_types "example/field types/"
  @field_merge "example/field types/merge/"

  defp translate(path) do
    path
      |> SpecTr.process
      |> TypeConstr.stringify()
  end

  describe "Translation of Basic Types" do
    test "Type variables" do
      assert [{_, _, "$ a -> a when a: integer()"}] |> match?(translate("#{@basic_types}type_variable_1.ex"))
      assert [{_, _, "$ a -> b when a: integer(), b: binary()"}] |> match?(translate("#{@basic_types}type_variable_2.ex"))
    end

    test "[[ | ]] = or" do
      assert [{_, _, "$ integer() or float() -> integer() or float()"}] |> match?(translate("#{@basic_types}union_type_3.ex"))
    end

    test "[[ any() ]] = term()" do
      assert [{_, _, "$ term() -> term()"}] |> match?(translate("#{@basic_types}any_1.ex"))
    end

    test "[[ none() ]] = none()" do
      assert [{_, _, "$ none() -> none()"}] |> match?(translate("#{@basic_types}none_1.ex"))
    end

    test "[[ atom() ]] = atom()" do
      assert [{_, _, "$ atom() -> atom()"}] |> match?(translate("#{@basic_types}atom_1.ex"))
    end

    test "[[ :k ]] = :k" do # ':k' ranges over singleton atom types
      assert [{_, _, "$ :singleton -> :ok"}] |> match?(translate("#{@basic_types}singleton_atom_type_1.ex"))
    end

    test "[[ pid() ]] = pid()" do
      assert [{_, _, "$ pid() -> pid()"}] |> match?(translate("#{@basic_types}pid_1.ex"))
    end

    test "[[ port() ]] = port()" do
      assert [{_, _, "$ port() -> port()"}] |> match?(translate("#{@basic_types}port_1.ex"))
    end

    test "[[ reference() ]] = reference()" do
      assert [{_, _, "$ reference() -> reference()"}] |> match?(translate("#{@basic_types}reference_1.ex"))
    end

    test "[[ float() ]] = float()" do
      assert [{_, _, "$ float() -> float()"}] |> match?(translate("#{@basic_types}float_1.ex"))
    end

    test "[[ integer() ]] = integer()" do
      assert [{_, _, "$ integer() -> integer()"}] |> match?(translate("#{@basic_types}integer_1.ex"))
    end

    # interval types to be approximated to integer()
    test "[[ neg_integer() ]] = neg_integer()" do
      assert [{_, _, "$ infty..-1 -> infty..-1"}] |> match?(translate("#{@basic_types}neg_integer_1.ex"))
    end
    test "[[ non_neg_integer() ]] = non_neg_integer()" do
      assert [{_, _, "$ 0..infty -> 0..infty"}] |> match?(translate("#{@basic_types}non_neg_integer_1.ex"))
    end
    test "[[ pos_integer() ]] = pos_integer()" do
      assert [{_, _, "$ 1..infty -> 1..infty"}] |> match?(translate("#{@basic_types}pos_integer_1.ex"))
    end

    test "[[ tuple() ]] = tuple()" do
      assert [{_, _, "$ tuple() -> tuple()"}] |> match?(translate("#{@basic_types}tuple_1.ex"))
    end

    test "[[ %{T_seq} ]] = %{T_seq}" do
      assert [{_, _, "$ {integer(), atom(), binary()} -> {integer(), binary(), atom()}"}] |> match?(translate("#{@basic_types}tuple_2.ex"))
    end

    test "[[ %{F_seq} ]] = %{F_seq}" do
      assert [{_, _, "$ %{pid() => if_set(integer()), atom() => if_set(binary())} -> %{pid() => if_set(integer()), atom() => if_set(binary())}"}] |> match?(translate("#{@basic_types}map_1.ex"))
    end

    test "[[ [] ]] = []" do
      assert [{_, _, "$ empty_list() -> empty_list()"}] |> match?(translate("#{@basic_types}empty_list_1.ex"))
    end

    test "[[ nonempty_maybe_improper_list(T, T') ]] = non_empty_list(T, T')" do
      assert [{_, _, "$ non_empty_list(integer(), empty_list()) -> non_empty_list(integer(), empty_list())"}] |> match?(translate("#{@basic_types}nonempty_maybe_improper_list_1.ex"))
    end

    test "[[ <<>> ]] = bitstring()" do
      assert [{_, _, "$ bitstring() -> bitstring()"}] |> match?(translate("#{@basic_types}bitstring_1.ex"))
    end
    test "[[ <<_::4>> ]] = bitstring()" do
      assert [{_, _, "$ bitstring() -> bitstring()"}] |> match?(translate("#{@basic_types}bitstring_2.ex"))
    end
    test "[[ <<_::_*4>> ]] = bitstring()" do
      assert [{_, _, "$ bitstring() -> bitstring()"}] |> match?(translate("#{@basic_types}bitstring_3.ex"))
    end
    test "[[ <<_::4, _::_*4>> ]] = bitstring()" do
      assert [{_, _, "$ bitstring() -> bitstring()"}] |> match?(translate("#{@basic_types}bitstring_4.ex"))
    end

    test "[[ <<_::8>> ]] = binary()" do
      assert [{_, _, "$ binary() -> binary()"}] |> match?(translate("#{@basic_types}binary_1.ex"))
    end

    test "[[ <<_::_*8>> ]] = binary()" do
      assert [{_, _, "$ binary() -> binary()"}] |> match?(translate("#{@basic_types}binary_2.ex"))
    end

    test "[[ <<_::8, _::_*8>> ]] = binary()" do
      assert [{_, _, "$ binary() -> binary()"}] |> match?(translate("#{@basic_types}binary_3.ex"))
    end

    test "[[ (T_seq -> T) ]] = (T_seq -> T)" do
      assert [{_, _, "$ (integer() -> integer()) -> (integer() -> integer())"}] |> match?(translate("#{@basic_types}function_1.ex"))
    end

    test "[[ (... -> any()) ]] = fun()" do
      assert [{_, _, "$ fun() -> fun()"}] |> match?(translate("#{@basic_types}function_top_1.ex"))
    end

    test "[[ (... -> integer()) ]] = ( -> integer()) or ... or (none(), ..., none()) -> integer()" do
      assert [{_, _, "$ (( -> integer()) or ... or (none(), ..., none() -> integer())) -> (( -> integer()) or ... or (none(), ..., none() -> integer()))"}] |> match?(translate("#{@basic_types}function_top_2.ex"))
    end

    test "[[ 1 ]] = 1..1" do
      assert [{_, _, "$ 1..1 -> 1..1"}] |> match?(translate("#{@basic_types}singleton_integer_1.ex"))
    end

    test "[[ 1..100 ]] = 1..100" do
      assert [{_, _, "$ 1..100 -> 1..100"}] |> match?(translate("#{@basic_types}interval_integer_1.ex"))
    end
  end

  describe "Translation of Field Types" do
    test "key type without required or optional" do
      assert [{_, _, "$ %{:a => integer()} -> %{term() => if_set(term())}"}] |> match?(translate("#{@field_types}field_types_1-1.ex"))
      assert [{_, _, "$ %{atom() => if_set(integer())} -> %{term() => if_set(term())}"}] |> match?(translate("#{@field_types}field_types_1-2.ex"))
    end
    test "key type with required" do
      assert [{_, _, "$ %{:a => integer()} -> %{term() => if_set(term())}"}] |> match?(translate("#{@field_types}field_types_2-1.ex"))
      assert [{_, _, "$ %{atom() => if_set(integer())} -> %{term() => if_set(term())}"}] |> match?(translate("#{@field_types}field_types_2-2.ex"))
    end
    test "key type with optional" do
      assert [{_, _, "$ %{:a => if_set(integer())} -> %{term() => if_set(term())}"}] |> match?(translate("#{@field_types}field_types_3-1.ex"))
      assert [{_, _, "$ %{atom() => if_set(integer())} -> %{term() => if_set(term())}"}] |> match?(translate("#{@field_types}field_types_3-2.ex"))
    end

    test "field type with merging" do
      assert [{_, _, "$ %{atom() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_merge}field_merge_1.ex"))
      assert [{_, _, "$ %{atom() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_merge}field_merge_2.ex"))
      assert [{_, _, "$ %{atom() => if_set(integer()), binary() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_merge}field_merge_3.ex"))
    end
  end

  describe "Approximated Translation of Field Types" do
    test "key type as literal types" do
      assert [{_, _, "$ %{:a => integer()} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-01.ex"))
      assert [{_, _, "$ %{true => integer()} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-02.ex"))
      assert [{_, _, "$ %{false => integer()} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-03.ex"))
      assert [{_, _, "$ %{nil => integer()} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-04.ex"))

      assert [{_, _, "$ %{bitstring() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-11.ex"))
      assert [{_, _, "$ %{bitstring() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-12.ex"))
      assert [{_, _, "$ %{bitstring() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-13.ex"))
      assert [{_, _, "$ %{bitstring() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-14.ex"))
      assert [{_, _, "$ %{binary() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-15.ex"))
      assert [{_, _, "$ %{binary() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-16.ex"))
      assert [{_, _, "$ %{binary() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-17.ex"))

      assert [{_, _, "$ %{fun() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-21.ex"))
      assert [{_, _, "$ %{fun() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-22.ex"))
      assert [{_, _, "$ %{fun() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-23.ex"))

      assert [{_, _, "$ %{integer() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-31.ex"))
      assert [{_, _, "$ %{integer() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-32.ex"))

      assert [{_, _, "$ %{open_map() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-41.ex"))
      assert [{_, _, "$ %{open_map() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-42.ex"))
      assert [{_, _, "$ %{open_map() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-43.ex"))
      assert [{_, _, "$ %{open_map() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-44.ex"))
      assert [{_, _, "$ %{open_map() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-45.ex"))
      assert [{_, _, "$ %{open_map() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-46.ex"))
      assert [{_, _, "$ %{open_map() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-47.ex"))

      assert [{_, _, "$ %{tuple() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-51.ex"))
      assert [{_, _, "$ %{tuple() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_1-52.ex"))
    end

    test "key type as union of singleton atom and key type" do
      assert [{_, _, "$ %{:a => if_set(integer()), :b => if_set(integer()), binary() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_2.ex"))
      assert [{_, _, "$ %{:a => if_set(integer()), :b => if_set(integer()), binary() => if_set(integer()), atom() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_types}field_types_approx_3.ex"))
    end

    test "field type with merging" do
      assert [{_, _, "$ %{integer() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_merge}field_merge_approx_1.ex"))

      assert [{_, _, "$ %{integer() => if_set(binary() or integer())} -> term()"}] |> match?(translate("#{@field_merge}field_merge_approx_2.ex"))

      assert [{_, _, "$ %{:a => if_set(integer()), :b => integer()} -> term()"}] |> match?(translate("#{@field_merge}field_merge_approx_3.ex"))

      # @spec id(%{optional(atom()) => integer(), optional(:b) => binary()}) :: any()
      assert [{_, _, "$ %{atom() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_merge}field_merge_approx_4.ex"))
      # @spec id(%{optional(atom()) => integer(), required(:b) => binary()}) :: any()
      assert [{_, _, "$ %{atom() => if_set(integer())} -> term()"}] |> match?(translate("#{@field_merge}field_merge_approx_5.ex"))

      # @spec id(%{optional(:a) => integer(), optional(atom()) => binary()}) :: any()
      assert [{_, _, "$ %{:a => if_set(integer()), atom() => if_set(binary())} -> term()"}] |> match?(translate("#{@field_merge}field_merge_approx_6.ex"))
      # @spec id(%{required(:a) => integer(), optional(atom()) => binary()}) :: any()
      assert [{_, _, "$ %{:a => integer(), atom() => if_set(binary())} -> term()"}] |> match?(translate("#{@field_merge}field_merge_approx_7.ex"))

      # @spec id(%{optional(:a | :b) => integer(), optional(atom()) => binary()}) :: any()
      assert [{_, _, "$ %{:a => if_set(integer()), :b => if_set(integer()), atom() => if_set(binary())} -> term()"}] |> match?(translate("#{@field_merge}field_merge_approx_8.ex"))
      # @spec id(%{required(:a | :b) => integer(), optional(atom()) => binary()}) :: any()
      assert [{_, _, "$ %{:a => if_set(integer()), :b => if_set(integer()), atom() => if_set(binary())} -> term()"}] |> match?(translate("#{@field_merge}field_merge_approx_9.ex"))

      assert [{_, _, "$ %{atom() => if_set(integer()), binary() => if_set(float())} -> term()"}] |> match?(translate("#{@field_merge}field_merge_approx_10.ex"))
    end
  end
end
