defmodule Ex3 do
  import Module.Types.Descr
  @spec map_id(map()) :: map()
  @assert_type fun([open_map()], open_map())
  def map_id(x) when is_map(x), do: x
end
