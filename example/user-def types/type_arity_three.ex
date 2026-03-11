defmodule TypeArityThree do
  @type three_arity(x, y, z) :: {x, y} | [z]

  @spec id(t) :: t when t: three_arity(x :: atom(), y :: binary(), z :: number())
  def id(num) when is_tuple(num) or is_list(num), do: num
end
