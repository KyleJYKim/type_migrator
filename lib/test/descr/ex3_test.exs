defmodule Ex3 do
  import Module.Types.Descr

  @type my_type :: map()
  @opaque my_opaque :: map()
  @typep my_typep :: map()

  @spec map_id1(my_type | my_opaque) :: my_typep
  # (map() -> map())
  def map_id1(x) when is_map(x), do: x

  @spec map_id2(%{:a => integer(), optional(any()) => any()}) :: map()
  # (%{    atom() => term(),    binary() => term(),    integer() => term(),    list() => term(),    pid() => term(),    port() => term(),    float() => term(),    map() => term(),    fun() => term(),    tuple() => term(),    reference() => term(),    a: integer()  } ->    map())
  def map_id2(x) when is_map(x), do: x

  @spec map_id3(%{optional(any()) => any(), :a => integer()}) :: map()
  # (map() -> map())
  def map_id3(x) when is_map(x), do: x

  defmodule Some do
    def id(x), do: x
  end
end
