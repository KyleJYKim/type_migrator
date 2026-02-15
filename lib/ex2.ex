defmodule Ex2 do

  @spec record_keytype_lists1(%{list(integer() | atom() | float() | binary()) => atom(), list(identifier()) => integer()}) :: map()
  def record_keytype_lists1(x), do: x

  @spec record_keytype_atom_others1(%{optional(:a | :b) => atom | any(), binary() => binary(), binary() => atom()}) :: map()
  def record_keytype_atom_others1(x), do: x

  @spec record_keytype_integers2(%{neg_integer() => integer() | float() | atom(), optional(-10..-1) => float}) :: map()
  def record_keytype_integers2(x), do: x

  @spec record_keytype_integers1(%{optional(20..22) => integer(), neg_integer() => integer(), optional(1..2 | 3..4 | 5..9 | 11..13 | 11..14) => integer()}) :: map()
  def record_keytype_integers1(x), do: x

  @spec record_keytype_integers2(%{optional(1..10) => integer(), optional(9..14) => float()}) :: map()
  def record_keytype_integers2(x), do: x

  @spec record_keytype_atom_integer1(%{required(:a | :b | :c) => atom, 1..2 | 11..12 => integer}) :: map()
  def record_keytype_atom_integer1(x), do: x

  @spec record_keytype_atoms1(%{:k => 1..2, atom() => binary(), :a => float()}) :: map()
  def record_keytype_atoms1(x), do: x

  @spec zero_arity() :: nil
  def zero_arity(), do: nil

  @spec return_true() :: true
  def return_true(), do: true

  @spec id1(:a) :: :a
  def id1(x), do: x

  @spec id2(atom()) :: v when v: atom()
  def id2(x), do: x

  defmodule In do

    @spec id1(<<_::8, _::_*8>>) :: <<_::_*8>>
    def id1(x) when is_binary(x), do: x

    @spec fun_t(a) :: b when a: integer(), b: binary()
    @spec fun_t(a) :: b when a: float(), b: binary()
    def fun_t(x) when is_integer(x), do: Integer.to_string(x)
    def fun_t(x) when is_float(x), do: Float.to_string(x)

    @spec fun_guards(binary(), a) :: binary when a: integer(), binary: binary()
    @spec fun_guards(binary(), a) :: binary when a: float(), binary: binary()
    def fun_guards(bin, x) when is_binary(bin) and is_integer(x), do: Integer.to_string(x)
    def fun_guards(bin, x) when is_binary(bin) and is_float(x), do: Float.to_string(x)
  end

  @spec fun_t(a) :: b when a: binary(), b: binary()
  @spec fun_t(a) :: b when a: integer(), b: binary()
  @spec fun_t(a) :: b when a: float(), b: binary()
  def fun_t(x) when is_binary(x), do: x
  def fun_t(x) when is_integer(x), do: Integer.to_string(x)
  def fun_t(x) when is_float(x), do: Float.to_string(x)

  @spec triple_arity_guarded(a, b, c) :: atom() | tuple() when a: integer(), b: float(), c: binary()
  def triple_arity_guarded(x, y, z), do: (if x < 0, do: :fail, else: {x, y, z})

  @spec triple_arity(integer(), number(), :ok | :fail) :: atom() | tuple()
  def triple_arity(x, y, z), do: (if z == :fail, do: :fail, else: {x, y, z})

  @spec list_literal_id([integer(), ...]) :: list(integer())
  def list_literal_id(xs) when is_list(xs), do: xs

  @spec top_fun_id((integer() -> integer())) :: (... -> integer())
  def top_fun_id(f) when is_function(f), do: f

  defmodule Undefined do
    @spec fun(binary()) :: binary()
    def fun(x) when is_binary(x), do: "#{x}"
    @spec top_fun_id() :: (... -> integer())
    def top_fun_id(), do: Ex2.top_fun_id(&fun/1)
  end
end
