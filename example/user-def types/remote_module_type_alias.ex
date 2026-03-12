defmodule Some do
  alias TypeArityOne, as: TAO

  @spec id(TAO.one_arity(term())) :: TAO.one_arity(x :: term())
  def id(x), do: x
end
