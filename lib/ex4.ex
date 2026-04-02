defmodule Ex4 do
  @spec id_tuple({atom(), term()}) :: tuple()
  def id_tuple(x) when is_tuple(x), do: x

  @spec id_string(String.t()) :: String.t()
  def id_string(x) when is_binary(x), do: x

  # @spec id_access(Access.t()) :: Access.t()
  # def id_access(x), do: x
end
