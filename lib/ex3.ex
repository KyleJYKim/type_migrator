defmodule Ex3 do
  @spec map_id(map()) :: map()
  def map_id(x) when is_map(x), do: x
end
