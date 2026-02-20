defmodule TypeMigratorTest do
  @moduledoc false

  use ExUnit.Case, async: true
  doctest TypeMigrator
  import Migrator.Translator

  describe "Basic Types from Typespecs to Elixir Types" do
    test "Type variables" do
      assert [{_, _, "$ a -> a when a: integer()"}] |> match?(process("example/type_variable_1.ex"))
      assert [{_, _, "$ a -> b when a: integer(), b: binary()"}] |> match?(process("example/type_variable_2.ex"))
    end

    test "[[ | ]] = or" do
      assert [{_, _, "$ integer() or float() -> integer() or float()"}] |> match?(process("example/union_type_3.ex"))
    end

    test "[[ any() ]] = term()" do
      assert [{_, _, "$ term() -> term()"}] |> match?(process("example/any_1.ex"))
    end

    test "[[ none() ]] = none()" do
      assert [{_, _, "$ none() -> none()"}] |> match?(process("example/none_1.ex"))
    end

    test "[[ atom() ]] = atom()" do
      assert [{_, _, "$ atom() -> atom()"}] |> match?(process("example/atom_1.ex"))
    end

    test "[[ :k ]] = :k" do # ':k' ranges over singleton atom types
      assert [{_, _, "$ :singleton -> :ok"}] |> match?(process("example/singleton_atom_type_1.ex"))
    end

    test "[[ pid() ]] = pid()" do
      assert [{_, _, "$ pid() -> pid()"}] |> match?(process("example/pid_1.ex"))
    end

    test "[[ port() ]] = port()" do
      assert [{_, _, "$ port() -> port()"}] |> match?(process("example/port_1.ex"))
    end

    test "[[ reference() ]] = reference()" do
      assert [{_, _, "$ reference() -> reference()"}] |> match?(process("example/reference_1.ex"))
    end

    test "[[ float() ]] = float()" do
      assert [{_, _, "$ float() -> float()"}] |> match?(process("example/float_1.ex"))
    end

    test "[[ integer() ]] = integer()" do
      assert [{_, _, "$ integer() -> integer()"}] |> match?(process("example/integer_1.ex"))
    end

    # interval types to be approximated to integer()
    test "[[ neg_integer() ]] = neg_integer()" do
      assert [{_, _, "$ infty..-1 -> infty..-1"}] |> match?(process("example/neg_integer_1.ex"))
    end
    test "[[ non_neg_integer() ]] = non_neg_integer()" do
      assert [{_, _, "$ 0..infty -> 0..infty"}] |> match?(process("example/non_neg_integer_1.ex"))
    end
    test "[[ pos_integer() ]] = pos_integer()" do
      assert [{_, _, "$ 1..infty -> 1..infty"}] |> match?(process("example/pos_integer_1.ex"))
    end

    test "[[ tuple() ]] = tuple()" do
      assert [{_, _, "$ tuple() -> tuple()"}] |> match?(process("example/tuple_1.ex"))
    end

    test "[[ %{T_seq} ]] = %{T_seq}" do
      assert [{_, _, "$ {integer(), atom(), binary()} -> {integer(), binary(), atom()}"}] |> match?(process("example/tuple_2.ex"))
    end

    test "[[ %{F_seq} ]] = %{F_seq}" do
      assert [{_, _, "$ %{atom() => if_set(binary()), pid() => if_set(integer())} -> %{atom() => if_set(binary()), pid() => if_set(integer())}"}] |> match?(process("example/map_1.ex"))
    end

    test "[[ [] ]] = []" do
      assert [{_, _, "$ empty_list() -> empty_list()"}] |> match?(process("example/empty_list_1.ex"))
    end

    test "[[ nonempty_maybe_improper_list(T, T') ]] = non_empty_list(T, T')" do
      assert [{_, _, "$ non_empty_list(integer(), empty_list()) -> non_empty_list(integer(), empty_list())"}] |> match?(process("example/nonempty_maybe_improper_list_1.ex"))
    end

    test "[[ <<>> ]] = bitstring()" do
      assert [{_, _, "$ bitstring() -> bitstring()"}] |> match?(process("example/bitstring_1.ex"))
    end
    test "[[ <<_::4>> ]] = bitstring()" do
      assert [{_, _, "$ bitstring() -> bitstring()"}] |> match?(process("example/bitstring_2.ex"))
    end
    test "[[ <<_::_*4>> ]] = bitstring()" do
      assert [{_, _, "$ bitstring() -> bitstring()"}] |> match?(process("example/bitstring_3.ex"))
    end
    test "[[ <<_::4, _::_*4>> ]] = bitstring()" do
      assert [{_, _, "$ bitstring() -> bitstring()"}] |> match?(process("example/bitstring_4.ex"))
    end

    test "[[ <<_::8>> ]] = binary()" do
      assert [{_, _, "$ binary() -> binary()"}] |> match?(process("example/binary_1.ex"))
    end

    test "[[ <<_::_*8>> ]] = binary()" do
      assert [{_, _, "$ binary() -> binary()"}] |> match?(process("example/binary_2.ex"))
    end

    test "[[ <<_::8, _::_*8>> ]] = binary()" do
      assert [{_, _, "$ binary() -> binary()"}] |> match?(process("example/binary_3.ex"))
    end

    test "[[ (T_seq -> T) ]] = (T_seq -> T)" do
      assert [{_, _, "$ (integer() -> integer()) -> (integer() -> integer())"}] |> match?(process("example/function_1.ex"))
    end

    test "[[ (... -> any()) ]] = fun()" do
      assert [{_, _, "$ fun() -> fun()"}] |> match?(process("example/function_top_1.ex"))
    end

    test "[[ (... -> integer()) ]] = ( -> integer()) or ... or (none(), ..., none()) -> integer()" do
      assert [{_, _, "$ (( -> integer()) or ... or (none(), ..., none() -> integer())) -> (( -> integer()) or ... or (none(), ..., none() -> integer()))"}] |> match?(process("example/function_top_2.ex"))
    end

    test "[[ 1 ]] = 1..1" do
      assert [{_, _, "$ 1..1 -> 1..1"}] |> match?(process("example/singleton_integer_1.ex"))
    end

    test "[[ 1..100 ]] = 1..100" do
      assert [{_, _, "$ 1..100 -> 1..100"}] |> match?(process("example/interval_integer_1.ex"))
    end
  end
end
