defmodule TypeArityOne do
  @type one_arity(x) :: x

  @spec id(one_arity(x :: term())) :: one_arity(x :: term())
  def id(x), do: x
end
