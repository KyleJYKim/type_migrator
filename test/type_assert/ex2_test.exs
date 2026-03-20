defmodule Ex2 do
  import Module.Types.Descr

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

#   @spec id(Types.t()) :: Types.t_in_t
#   @assert_type fun([term()], term())
#   def id(x), do: x

#   @spec record_keytype_user_type(%{String.t() => String.t()}) :: any()
#   @assert_type fun([open_map([{to_domain_keys(term()), if_set(term())}])], term())
#   def record_keytype_user_type(x), do: x

#   @spec record_keytype_map(%{map() => :a}) :: map()
#   @assert_type fun([open_map([{to_domain_keys(open_map()), if_set(atom([:a]))}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_map(x), do: x

#   @spec record_keytype_structs3(%{struct() => integer(), %Types{integer: integer(), float: float()} => float()}) :: map()
#   @assert_type fun([open_map([{to_domain_keys(open_map()), if_set(integer())}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_structs3(x), do: x

#   @spec record_keytype_structs2(%{%Types{integer: integer(), float: float(), binary: binary()} => integer(), %Types{integer: integer(), float: float()} => float()}) :: map()
#   @assert_type fun([open_map([{to_domain_keys(open_map()), if_set(integer())}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_structs2(x), do: x

#   @spec record_keytype_structs1(%{%Types{integer: integer(), float: float()} => number(), %Types{integer: integer(), float: float(), binary: binary()} => float()}) :: map()
#   @assert_type fun([open_map([{to_domain_keys(open_map()), if_set(union(float(), integer()))}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_structs1(x), do: x

#   @spec record_keytype_records2(%{%{integer() => integer()} => integer(), %{float() => float()} => float()}) :: map()
#   @assert_type fun([open_map([{to_domain_keys(open_map()), if_set(union(float(), integer()))}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_records2(x), do: x

#   @spec record_keytype_records1(%{%{number() => number()} => integer(), %{float() => float()} => float()}) :: map()
#   @assert_type fun([open_map([{to_domain_keys(open_map()), if_set(integer())}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_records1(x), do: x

#   @spec record_keytype_tuples1(%{{integer() | binary(), float()} => atom(), {integer(), float()} => integer()}) :: map()
#   @assert_type fun([open_map([{to_domain_keys(tuple()), if_set(atom())}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_tuples1(x), do: x

#   @spec record_keytype_functions4(%{(... -> number()) => integer(), (number() -> number()) => number()}) :: map()
#   @assert_type fun([open_map([{to_domain_keys(fun()), if_set(integer())}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_functions4(x), do: x

#   @spec record_keytype_functions3(%{fun() => any(), (number() -> number()) => number()}) :: map()
#   @assert_type fun([open_map([{to_domain_keys(fun()), if_set(term())}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_functions3(x), do: x

#   @spec record_keytype_functions2(%{(integer() -> integer()) => atom(), (number() -> integer()) => binary()}) :: map()
#   @assert_type fun([open_map([{to_domain_keys(fun()), if_set(atom())}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_functions2(x), do: x

#   @spec record_keytype_functions1(%{(number() -> integer()) => atom(), (integer() -> integer()) => binary()}) :: map()
#   @assert_type fun([open_map([{to_domain_keys(fun()), if_set(union(binary(), atom()))}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_functions1(x), do: x

#   @spec record_keytype_lists1(%{list(integer() | atom() | float() | binary()) => atom(), list(identifier()) => integer()}) :: map()
#   @assert_type fun([open_map([{to_domain_keys(list(:term)), if_set(union(integer(), atom()))}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_lists1(x), do: x

#   @spec record_keytype_atom_others1(%{required(:some) => any(), optional(:a | :b | :c) => atom | any(), binary() => binary(), binary() => atom()}) :: map()
#   @assert_type fun([open_map([{:some, term()}, {:a, if_set(term())}, {:b, if_set(term())}, {:c, if_set(term())}, {to_domain_keys(binary()), if_set(binary())}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_atom_others1(x), do: x

#   @spec record_keytype_atoms1(%{:a => atom, :b => atom()}) :: map()
#   @assert_type fun([open_map([{:a, atom()}, {:b, atom()}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_atoms1(x), do: x

#   @spec record_keytype_integers3(%{neg_integer() => integer() | float() | atom(), optional(-10..-1) => float}) :: map()
#   @assert_type fun([open_map([{to_domain_keys(integer()), if_set(union(atom(), union(float(), integer())))}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_integers3(x), do: x

#   @spec record_keytype_integers1(%{optional(20..22) => integer(), neg_integer() => float(), optional(1..2 | 3..4 | 5..9 | 11..13 | 11..14) => atom()}) :: map()
#   @assert_type fun([open_map([{to_domain_keys(integer()), if_set(union(atom(), union(float(), integer())))}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_integers1(x), do: x

#   @spec record_keytype_integers2(%{optional(1..10) => integer(), optional(9..10) => float()}) :: map()
#   @assert_type fun([open_map([{to_domain_keys(integer()), if_set(integer())}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_integers2(x), do: x

#   @spec record_keytype_atom_integer1(%{required(:a | integer()) => atom, 1..2 | 11..12 => integer}) :: map()
#   @assert_type fun([open_map([{:a, if_set(atom())}, {to_domain_keys(integer()), if_set(atom())}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_atom_integer1(x), do: x

#   @spec record_keytype_atoms1(%{:k => 1..2, atom() => binary(), :a => float()}) :: map()
#   @assert_type fun([open_map([{:k, integer()}, {to_domain_keys(atom()), if_set(binary())}])], open_map([{to_domain_keys(term()), if_set(term())}]))
#   def record_keytype_atoms1(x), do: x

#   @spec zero_arity() :: nil
#   @assert_type fun([], atom([:nil]))
#   def zero_arity(), do: nil

#   @spec return_true() :: true
#   @assert_type fun([], atom([:true]))
#   def return_true(), do: true

#   @spec id1(:a) :: :a
#   @assert_type fun([atom([:a])], atom([:a]))
#   def id1(x), do: x

#   @spec id2(integer()) :: list(v) when v: integer()
#   @spec id2(float()) :: list(v) when v: float()
# #   @assert_type fun([integer()], union(empty_list(), non_empty_list(integer(), empty_list())))
# # fun([float()], union(empty_list(), non_empty_list(float(), empty_list()))))
#   def id2(x), do: x

#   @spec id3(%Types{integer: integer(), float: float()}) :: struct()
#   @assert_type fun([open_map([{:__struct__, atom([Types])}, {:integer, integer()}, {:float, float()}])], open_map([{:__struct__, atom()}, {to_domain_keys(atom()), if_set(term())}]))
#   def id3(x), do: x

#   defmodule In do

#     @spec id1(<<_::8, _::_*8>>) :: <<_::_*8>>
#     @assert_type fun([binary()], binary())
#     def id1(x) when is_binary(x), do: x

#     @spec fun_t(a) :: b when a: integer(), b: binary()
#     @spec fun_t(a) :: b when a: float(), b: binary()
#     @assert_type fun([integer()], binary())
#     def fun_t(x) when is_integer(x), do: Integer.to_string(x)
#     @assert_type fun([float()], binary())
#     def fun_t(x) when is_float(x), do: Float.to_string(x)

#     @spec fun_guards(binary(), a) :: binary when a: integer(), binary: binary()
#     @spec fun_guards(binary(), a) :: binary when a: float(), binary: binary()
#     @assert_type fun([binary(), integer()], binary())
#     def fun_guards(bin, x) when is_binary(bin) and is_integer(x), do: Integer.to_string(x)
#     @assert_type fun([binary(), float()], binary())
#     def fun_guards(bin, x) when is_binary(bin) and is_float(x), do: Float.to_string(x)
#   end

  @spec fun_t(a) :: b when a: binary(), b: binary()
  @spec fun_t(a) :: b when a: integer(), b: binary()
  @spec fun_t(a) :: b when a: float(), b: binary()
  @assert_type intersection(intersection(fun([binary()], binary()), fun([integer()], binary())), fun([float()], binary()))
  def fun_t(x) when is_binary(x), do: x
  def fun_t(x) when is_integer(x), do: Integer.to_string(x)
  def fun_t(x) when is_float(x), do: Float.to_string(x)


  # @assert_type_form (integer() -> integer()) and (atom() -> atom())
  # def i(x) when is_atom(x) do
  #   case x do
  #     _ when is_integer(x) -> x
  #     _ when is_atom(x) -> x
  #   end
  # end
  #@assert_type_form (atom() -> atom())
  # def i(x), do: x


  # @spec triple_arity_guarded(a, b, c) :: atom() | tuple() when a: integer(), b: float(), c: binary()
  # @assert_type fun([integer(), float(), binary()], union(atom(), tuple()))
  # def triple_arity_guarded(x, y, z), do: (if x < 0, do: :fail, else: {x, y, z})

  # @spec triple_arity(integer(), number(), :ok | :fail) :: atom() | tuple()
  # @assert_type fun([integer(), union(integer(), float()), union(atom([:ok]), atom([:fail]))], union(atom(), tuple()))
  # def triple_arity(x, y, z), do: (if z == :fail, do: :fail, else: {x, y, z})

  # @spec list_literal_id([integer(), ...]) :: list(integer())
  # def list_literal_id(xs) when is_list(xs), do: xs

  # @spec top_fun_id((integer() -> integer())) :: (... -> integer())
  # def top_fun_id(f) when is_function(f), do: f

  # @spec fun(binary()) :: binary()
  # def fun(x) when is_binary(x), do: "#{x}"

  # @spec top_fun_id() :: (... -> integer())
  # def top_fun_id(), do: Ex2.top_fun_id(&fun/1)
end
