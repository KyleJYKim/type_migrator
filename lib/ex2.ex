defmodule Ex2 do


  defmodule Types do
    defstruct [:atom, :binary, integer: 0, float: 0.0]
    @type t :: %Types{integer: integer(), float: float(), atom: atom(), binary: binary()}
    @type t_in_t :: t
  end

  @type container :: keyword | struct | map
  @type nil_container :: nil
  @type t :: container | nil_container | any
  @type key :: any
  @type value :: any

  @type get_fun(data) ::
          (:get, data, (term -> term) -> new_data :: container)

  @type get_and_update_fun(data, current_value) ::
          (:get_and_update, data, (term -> term) ->
             {current_value, new_data :: container} | :pop)

  @type access_fun(data, current_value) ::
          get_fun(data) | get_and_update_fun(data, current_value)

  # @spec get_and_update(data, key, (value | nil -> {current_value, new_value :: value} | :pop)) ::
  #       {current_value, new_data :: data}
  #     when current_value: var, data: container
  # def get_and_update(x, y, z), do: x

  # @spec id_tuple({atom(), 1..10, binary()}) :: t when t: access_fun(data1 :: struct | map, current_value :: term)
  # def id_tuple(tpl) when is_tuple(tpl), do: tpl

  @spec id(Types.t()) :: Types.t_in_t
  def id(x), do: x

  @spec record_keytype_user_type(%{String.t() => String.t()}) :: any()
  def record_keytype_user_type(x), do: x

  @spec record_keytype_map(%{map() => :a}) :: map()
  def record_keytype_map(x), do: x

  @spec record_keytype_structs3(%{struct() => integer(), %Types{integer: integer(), float: float()} => float()}) :: map()
  def record_keytype_structs3(x), do: x

  @spec record_keytype_structs2(%{%Types{integer: integer(), float: float(), binary: binary()} => integer(), %Types{integer: integer(), float: float()} => float()}) :: map()
  def record_keytype_structs2(x), do: x

  @spec record_keytype_structs1(%{%Types{integer: integer(), float: float()} => number(), %Types{integer: integer(), float: float(), binary: binary()} => float()}) :: map()
  def record_keytype_structs1(x), do: x

  @spec record_keytype_records2(%{%{integer() => integer()} => integer(), %{float() => float()} => float()}) :: map()
  def record_keytype_records2(x), do: x

  @spec record_keytype_records1(%{%{number() => number()} => integer(), %{float() => float()} => float()}) :: map()
  def record_keytype_records1(x), do: x

  @spec record_keytype_tuples1(%{{integer() | binary(), float()} => atom(), {integer(), float()} => integer()}) :: map()
  def record_keytype_tuples1(x), do: x

  @spec record_keytype_functions4(%{(... -> number()) => integer(), (number() -> number()) => number()}) :: map()
  def record_keytype_functions4(x), do: x

  @spec record_keytype_functions3(%{fun() => any(), (number() -> number()) => number()}) :: map()
  def record_keytype_functions3(x), do: x

  @spec record_keytype_functions2(%{(integer() -> integer()) => atom(), (number() -> integer()) => binary()}) :: map()
  def record_keytype_functions2(x), do: x

  @spec record_keytype_functions1(%{(number() -> integer()) => atom(), (integer() -> integer()) => binary()}) :: map()
  def record_keytype_functions1(x), do: x

  @spec record_keytype_lists1(%{list(integer() | atom() | float() | binary()) => atom(), list(identifier()) => integer()}) :: map()
  def record_keytype_lists1(x), do: x

  @spec record_keytype_atom_others1(%{required(:some) => any(), optional(:a | :b | :c) => atom | any(), binary() => binary(), binary() => atom()}) :: map()
  def record_keytype_atom_others1(x), do: x

  @spec record_keytype_atoms1(%{:a => atom, :b => atom()}) :: map()
  def record_keytype_atoms1(x), do: x

  @spec record_keytype_integers2(%{neg_integer() => integer() | float() | atom(), optional(-10..-1) => float}) :: map()
  def record_keytype_integers2(x), do: x

  @spec record_keytype_integers1(%{optional(20..22) => integer(), neg_integer() => float(), optional(1..2 | 3..4 | 5..9 | 11..13 | 11..14) => atom()}) :: map()
  def record_keytype_integers1(x), do: x

  @spec record_keytype_integers2(%{optional(1..10) => integer(), optional(9..10) => float()}) :: map()
  def record_keytype_integers2(x), do: x

  @spec record_keytype_atom_integer1(%{required(:a | integer()) => atom, 1..2 | 11..12 => integer}) :: map()
  def record_keytype_atom_integer1(x), do: x

  @spec record_keytype_atoms1(%{:k => 1..2, atom() => binary(), :a => float()}) :: map()
  def record_keytype_atoms1(x), do: x

  @spec zero_arity() :: nil
  def zero_arity(), do: nil

  @spec return_true() :: true
  def return_true(), do: true

  @spec id1(:a) :: :a
  def id1(x), do: x

  @spec id2(integer()) :: list(v) when v: integer()
  @spec id2(float()) :: list(v) when v: float()
  def id2(x), do: x

  @spec id3(%Types{integer: integer(), float: float()}) :: struct()
  def id3(x), do: x

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

  # @spec list_literal_id([integer(), ...]) :: list(integer())
  # def list_literal_id(xs) when is_list(xs), do: xs

  # @spec top_fun_id((integer() -> integer())) :: (... -> integer())
  # def top_fun_id(f) when is_function(f), do: f

  # @spec fun(binary()) :: binary()
  # def fun(x) when is_binary(x), do: "#{x}"

  # @spec top_fun_id() :: (... -> integer())
  # def top_fun_id(), do: Ex2.top_fun_id(&fun/1)
end
