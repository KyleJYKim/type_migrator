defmodule Ex3 do
  import Module.Types.Descr


  @type my_type :: map()
  @opaque my_opaque :: map()
  @typep my_typep :: map()

  @spec map_id1(my_type | my_opaque) :: my_typep
  @assert_type_form (%{...} or %{...} -> %{...})
  def map_id1(x) when is_map(x), do: x

  @spec map_id2(%{:a => integer(), optional(any()) => any()}) :: map()
  @assert_type_form (%{term() => if_set(term()), :a => integer()} -> %{...})
  def map_id2(x) when is_map(x), do: x

  @spec map_id3(%{optional(any()) => any(), :a => integer()}) :: map()
  @assert_type_form (%{term() => if_set(term())} -> %{...})
  def map_id3(x) when is_map(x), do: x

  @spec map_id4(%{optional(atom()) => binary(), :a => integer()}) :: map()
  @assert_type_form (%{atom() => if_set(binary())} -> dynamic(%{...}))
  def map_id4(x) when is_map(x), do: x

  defmodule Some do
    defstruct a: 0, b: 0
    @type t :: %Some{a: integer(), b: integer()}
  end
end
