defmodule Ex3 do

  @type my_type :: map()
  @opaque my_opaque :: map()
  @typep my_typep :: map()

  @spec map_id1(my_type | my_opaque) :: my_typep
  def map_id1(x) when is_map(x), do: x

  @spec map_id2(%{:a => integer(), optional(any()) => any()}) :: map()
  def map_id2(x) when is_map(x), do: x

  @spec map_id3(%{optional(any()) => any(), :a => integer()}) :: map()
  def map_id3(x) when is_map(x), do: x

  @spec map_id4(%{optional(atom()) => binary(), :a => integer()}) :: map()
  def map_id4(x) when is_map(x), do: x

  defmodule Some do
    defstruct a: 0, b: 0
    @type t :: %Some{a: integer(), b: integer()}
  end
end
