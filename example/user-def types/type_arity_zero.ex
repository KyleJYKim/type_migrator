defmodule TypeArityZero do
  @type zero_arity :: term()

  @spec id(zero_arity) :: zero_arity
  def id(x), do: x
end
