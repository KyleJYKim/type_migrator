defmodule Some do
  @spec id(TypeArityOne.one_arity(term())) :: TypeArityOne.one_arity(x :: term())
  def id(x), do: x
end
