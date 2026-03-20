defmodule DescrTest do
  import Elixir.Module.Types.Descr

  @spec fun_t(a) :: b when a: binary(), b: binary()
  @spec fun_t(a) :: b when a: integer(), b: binary()
  @spec fun_t(a) :: b when a: float(), b: binary()
  #@assert_type intersection(intersection(fun([binary()], binary()), fun([integer()], binary())), fun([float()], binary()))
  def fun_t(x) when is_binary(x), do: x
  def fun_t(x) when is_integer(x), do: Integer.to_string(x)
  def fun_t(x) when is_float(x), do: Float.to_string(x)

  @spec triple_arity_guarded(a, b, c) :: atom() | tuple() when a: integer(), b: float(), c: binary()
  @assert_type fun([dynamic(integer()), float(), binary()], union(atom(), tuple()))
  def triple_arity_guarded(x, y, z), do: (if x < 0, do: :fail, else: {x, y, z})

  @spec triple_arity(integer(), number(), :ok | :fail) :: atom() | tuple()
  @assert_type fun([integer(), union(integer(), float()), union(atom([:ok]), atom([:fail]))], union(atom(), tuple()))
  def triple_arity(x, y, z), do: (if z == :fail, do: :fail, else: {x, y, z})

  @spec record_keytype_user_type(%{String.t() => String.t()}) :: any()
  @assert_type fun([open_map([{to_domain_keys(binary()), if_set(binary())}])], term())
  def record_keytype_user_type(x) when is_map(x), do: x
end
