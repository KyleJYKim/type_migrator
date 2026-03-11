defmodule TypeArityTwo do
  @type two_arity(x, y) :: x | y

  @spec id(two_arity(x :: integer(), y :: float())) :: two_arity(x :: integer(), y :: float())
  def id(num) when is_integer(num) or is_float(num), do: num
end
